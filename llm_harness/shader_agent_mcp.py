#!/usr/bin/env python3
"""A deliberately narrow MCP tool server for agentic shader iteration.

The server owns exactly one shader workspace. It can write the complete shader,
render the current revision with the benchmark binary, record bounded visual
studies, and freeze a rendered revision as the final submission. Paths and
budgets come from the parent harness through environment variables;
model-supplied paths are never accepted.
"""

from __future__ import annotations

import copy
import hashlib
import itertools
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP, Image
from mcp.types import CallToolResult, TextContent
from PIL import Image as PILImage
from PIL import ImageChops, ImageDraw, ImageStat

from study_dag import AdaptiveStudyDAG, StudyDAGError


MAX_SHADER_BYTES = 512_000
STUDY_DIVERSITY_MEAN_MAE_MIN = 1.0
STUDY_DIVERSITY_MAX_MAE_MIN = 1.75
STUDY_CROSS_PASS_MAE_MIN = 1.0
STUDY_CROSS_TOPIC_MAE_MIN = 0.5
ARTIFACT_MARKER_RE = re.compile(
    r"(?ms)^// @shaderbench-artifact-begin "
    r"id=(study_(\d+)_([A-F])) entry=([A-Za-z_][A-Za-z0-9_]*)[ \t]*\n"
    r"(.*?)"
    r"^// @shaderbench-artifact-end id=\1[ \t]*(?:\n|$)"
)
ARTIFACT_BEGIN_RE = re.compile(
    r"(?m)^// @shaderbench-artifact-begin[^\n]*$"
)
ARTIFACT_END_RE = re.compile(
    r"(?m)^// @shaderbench-artifact-end[^\n]*$"
)
ARTIFACT_INJECT_RE = re.compile(
    r"(?m)^// @shaderbench-inject id=(study_\d+_[A-F])[ \t]*(?:\n|$)"
)
VARIANTS = ("A", "B", "C", "D", "E", "F")


def _wgsl_lexical_code(source: str) -> tuple[str, list[bool]]:
    """Blank WGSL comments while preserving offsets and mark block comments."""
    code = list(source)
    block_mask = [False] * len(source)
    cursor = 0
    block_depth = 0
    line_comment = False
    while cursor < len(source):
        pair = source[cursor : cursor + 2]
        if line_comment:
            if source[cursor] == "\n":
                line_comment = False
            else:
                code[cursor] = " "
            cursor += 1
            continue
        if block_depth:
            block_mask[cursor] = True
            if source[cursor] != "\n":
                code[cursor] = " "
            if pair == "/*":
                if cursor + 1 < len(source):
                    block_mask[cursor + 1] = True
                    code[cursor + 1] = " "
                block_depth += 1
                cursor += 2
            elif pair == "*/":
                if cursor + 1 < len(source):
                    block_mask[cursor + 1] = True
                    code[cursor + 1] = " "
                block_depth -= 1
                cursor += 2
            else:
                cursor += 1
            continue
        if pair == "//":
            code[cursor] = " "
            if cursor + 1 < len(source):
                code[cursor + 1] = " "
            line_comment = True
            cursor += 2
            continue
        if pair == "/*":
            block_mask[cursor] = True
            code[cursor] = " "
            if cursor + 1 < len(source):
                block_mask[cursor + 1] = True
                code[cursor + 1] = " "
            block_depth = 1
            cursor += 2
            continue
        cursor += 1
    return "".join(code), block_mask


def _blank_static_false_blocks(code: str) -> str:
    """Simplify literal WGSL branches while preserving all source offsets."""
    blanked = list(code)
    if_pattern = re.compile(
        r"\bif\s*(?:\(\s*)?(true|false)(?:\s*\))?\s*\{"
    )

    def block_end(body_start: int) -> int | None:
        depth = 0
        for index in range(body_start, len(blanked)):
            if blanked[index] == "{":
                depth += 1
            elif blanked[index] == "}":
                depth -= 1
                if depth == 0:
                    return index
        return None

    def erase(start: int, end: int) -> None:
        for index in range(start, end):
            if blanked[index] != "\n":
                blanked[index] = " "

    # Re-scan after each rewrite so nested literal branches are also reduced.
    while True:
        current = "".join(blanked)
        match = if_pattern.search(current)
        if match is None:
            break
        then_start = match.end() - 1
        then_end = block_end(then_start)
        if then_end is None:
            break
        else_match = re.match(r"\s*else\s*\{", current[then_end + 1 :])
        else_header_start = then_end + 1
        else_start = None
        else_end = None
        if else_match is not None:
            else_start = else_header_start + else_match.end() - 1
            else_end = block_end(else_start)
        if match.group(1) == "true":
            # Keep the taken body but flatten its braces; erase an untaken else.
            erase(match.start(), then_start + 1)
            erase(then_end, then_end + 1)
            if else_end is not None:
                erase(else_header_start, else_end + 1)
        else:
            erase(match.start(), then_end + 1)
            if else_start is not None and else_end is not None:
                # A false-if's else body is unconditional.
                erase(else_header_start, else_start + 1)
                erase(else_end, else_end + 1)

    while_pattern = re.compile(
        r"\bwhile\s*(?:\(\s*)?false(?:\s*\))?\s*\{"
    )
    search_from = 0
    while True:
        match = while_pattern.search("".join(blanked), search_from)
        if match is None:
            break
        body_start = match.end() - 1
        body_end = block_end(body_start)
        if body_end is None:
            break
        erase(match.start(), body_end + 1)
        search_from = body_end + 1
    return "".join(blanked)


WGSLValueRef = tuple[str, tuple[tuple[str, str], ...]]


def _wgsl_access_path(accessor: str) -> tuple[tuple[str, str], ...]:
    """Normalize a WGSL field/swizzle/index chain for dependency matching."""
    path: list[tuple[str, str]] = []
    for match in re.finditer(
        r"\.([A-Za-z_][A-Za-z0-9_]*)|\[([^\]]+)\]",
        accessor,
    ):
        if match.group(1) is not None:
            path.append(("field", match.group(1)))
            continue
        index = re.sub(r"\s+", "", match.group(2) or "")
        path.append(("index", index))
    return tuple(path)


def _wgsl_expression_refs(expression: str) -> set[WGSLValueRef]:
    """Extract base identifiers with any directly attached access path."""
    refs: set[WGSLValueRef] = set()
    reference_pattern = re.compile(
        r"\b([A-Za-z_][A-Za-z0-9_]*)"
        r"((?:\s*(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]]+\]))*)"
    )
    for match in reference_pattern.finditer(expression):
        # Do not treat a member name following a complex expression, such as
        # ``make_value().x``, as an independent variable named ``x``.
        if match.start() > 0 and expression[match.start() - 1] == ".":
            continue
        accessor = match.group(2)
        refs.add((match.group(1), _wgsl_access_path(accessor)))
        # An index expression also controls which value is read.
        for index_match in re.finditer(r"\[([^\]]+)\]", accessor):
            refs.update(_wgsl_expression_refs(index_match.group(1)))
    return refs


def _wgsl_split_arguments(arguments: str) -> list[str]:
    """Split a compact WGSL call/constructor argument list at top-level commas."""
    parts: list[str] = []
    start = 0
    stack: list[str] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for index, character in enumerate(arguments):
        if character in "([{":
            stack.append(character)
        elif character in pairs and stack and stack[-1] == pairs[character]:
            stack.pop()
        elif character == "," and not stack:
            parts.append(arguments[start:index].strip())
            start = index + 1
    parts.append(arguments[start:].strip())
    return [part for part in parts if part]


def _wgsl_matching_paren(expression: str, open_index: int) -> int | None:
    depth = 0
    for index in range(open_index, len(expression)):
        if expression[index] == "(":
            depth += 1
        elif expression[index] == ")":
            depth -= 1
            if depth == 0:
                return index
    return None


def _wgsl_projected_expression_refs(
    expression: str,
    requested_path: tuple[tuple[str, str], ...] = (),
) -> set[WGSLValueRef]:
    """Follow simple aliases and scalar lanes through vector/array constructors."""
    expression = expression.strip()
    if not expression:
        return set()

    # Parenthesized aggregate projection: ``(vec2(a, b)).x``.
    if expression.startswith("("):
        close = _wgsl_matching_paren(expression, 0)
        if close is not None:
            suffix = expression[close + 1 :].strip()
            if close == len(expression) - 1:
                return _wgsl_projected_expression_refs(
                    expression[1:close],
                    requested_path,
                )
            if re.fullmatch(
                r"(?:\s*(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]]+\]))+",
                suffix,
            ):
                return _wgsl_projected_expression_refs(
                    expression[1:close],
                    _wgsl_access_path(suffix) + requested_path,
                )

    simple_reference = re.fullmatch(
        r"([A-Za-z_][A-Za-z0-9_]*)"
        r"((?:\s*(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]]+\]))*)",
        expression,
    )
    if simple_reference is not None:
        return {
            (
                simple_reference.group(1),
                _wgsl_access_path(simple_reference.group(2)) + requested_path,
            )
        }

    constructor = re.match(
        r"(vec([234])|array)\s*(?:<[^>]+>)?\s*\(",
        expression,
    )
    if constructor is not None:
        open_index = constructor.end() - 1
        close = _wgsl_matching_paren(expression, open_index)
        if close is not None:
            suffix = expression[close + 1 :].strip()
            if not suffix or re.fullmatch(
                r"(?:\s*(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]]+\]))+",
                suffix,
            ):
                projection = _wgsl_access_path(suffix) + requested_path
                arguments = _wgsl_split_arguments(
                    expression[open_index + 1 : close]
                )
                lane_count = (
                    int(constructor.group(2))
                    if constructor.group(2) is not None
                    else len(arguments)
                )
                # Lane mapping is unambiguous only for scalar-per-lane forms.
                if projection and len(arguments) == lane_count:
                    kind, value = projection[0]
                    selected: list[int] = []
                    if kind == "field":
                        aliases = {
                            "x": 0,
                            "r": 0,
                            "y": 1,
                            "g": 1,
                            "z": 2,
                            "b": 2,
                            "w": 3,
                            "a": 3,
                        }
                        if value and all(char in aliases for char in value):
                            selected = [aliases[char] for char in value]
                    else:
                        index_match = re.fullmatch(r"(\d+)[iu]?", value)
                        if index_match is not None:
                            selected = [int(index_match.group(1))]
                    if selected and all(index < len(arguments) for index in selected):
                        refs: set[WGSLValueRef] = set()
                        for index in selected:
                            refs.update(
                                _wgsl_projected_expression_refs(
                                    arguments[index],
                                    projection[1:],
                                )
                            )
                        return refs
                if not projection:
                    refs: set[WGSLValueRef] = set()
                    for argument in arguments:
                        refs.update(_wgsl_projected_expression_refs(argument))
                    return refs

    # For arbitrary arithmetic/calls, every referenced operand may contribute.
    return _wgsl_expression_refs(expression)


def _wgsl_swizzle_components(field: str) -> set[str] | None:
    """Return canonical vector components, or None for a struct field."""
    aliases = {
        "x": "x",
        "y": "y",
        "z": "z",
        "w": "w",
        "r": "x",
        "g": "y",
        "b": "z",
        "a": "w",
    }
    if not field or any(character not in aliases for character in field):
        return None
    return {aliases[character] for character in field}


def _wgsl_path_tokens_overlap(
    left: tuple[str, str],
    right: tuple[str, str],
) -> bool:
    if left[0] != right[0]:
        return False
    if left[0] == "index":
        left_static = re.fullmatch(r"\d+[iu]?", left[1])
        right_static = re.fullmatch(r"\d+[iu]?", right[1])
        return not (left_static and right_static) or left[1] == right[1]
    left_components = _wgsl_swizzle_components(left[1])
    right_components = _wgsl_swizzle_components(right[1])
    if left_components is None or right_components is None:
        return left[1] == right[1]
    return bool(left_components & right_components)


def _wgsl_paths_overlap(
    left: tuple[tuple[str, str], ...],
    right: tuple[tuple[str, str], ...],
) -> bool:
    """Whether two aggregate access paths may address shared data."""
    for left_token, right_token in zip(left, right):
        if not _wgsl_path_tokens_overlap(left_token, right_token):
            return False
    # A whole aggregate and any of its descendants overlap.
    return True


def _wgsl_path_covers(
    assigned: tuple[tuple[str, str], ...],
    read: tuple[tuple[str, str], ...],
) -> bool:
    """Whether a plain assignment replaces every component of a read path."""
    if len(assigned) > len(read):
        return False
    for assigned_token, read_token in zip(assigned, read):
        if assigned_token[0] != read_token[0]:
            return False
        if assigned_token[0] == "index":
            if assigned_token[1] != read_token[1]:
                return False
            continue
        assigned_components = _wgsl_swizzle_components(assigned_token[1])
        read_components = _wgsl_swizzle_components(read_token[1])
        if assigned_components is None or read_components is None:
            if assigned_token[1] != read_token[1]:
                return False
        elif not read_components <= assigned_components:
            return False
    return True


def _wgsl_return_dependencies(body: str) -> set[str]:
    """Trace return dataflow with ordered, conservative reaching definitions.

    A simple union of every assignment lets dead values masquerade as live
    dependencies: ``d = artifact(p); d = 1.0; return d`` must not credit the
    artifact.  Walk definitions backwards from each return instead.  A plain
    assignment kills an earlier value when it is in the return's lexical block
    or an ancestor block.  Assignments in sibling/conditional blocks are
    conservatively additive because that path may not execute.
    """
    body = _blank_static_false_blocks(body)

    # Record the containing brace stack at every source offset.  Comparing
    # stacks is more accurate than comparing depth: a definition in an
    # ancestor block definitely reaches a nested return, while a definition in
    # a completed sibling block may not.
    block_paths: list[tuple[int, ...]] = [()] * (len(body) + 1)
    block_stack: list[int] = []
    for offset, character in enumerate(body):
        block_paths[offset] = tuple(block_stack)
        if character == "{":
            block_stack.append(offset)
        elif character == "}" and block_stack:
            block_stack.pop()
    block_paths[len(body)] = tuple(block_stack)

    assignments: list[dict[str, Any]] = []
    declaration_pattern = re.compile(
        r"\b(?:let|var(?:\s*<[^>;]+>)?)\s+"
        r"([A-Za-z_][A-Za-z0-9_]*)"
        r"(?:\s*:\s*[^=;]+)?\s*=\s*([^;]+);",
        re.DOTALL,
    )
    for match in declaration_pattern.finditer(body):
        assignments.append(
            {
                "start": match.start(1),
                "target": match.group(1),
                "access_path": (),
                "expression": match.group(2),
                "kills_previous": True,
                "path": block_paths[match.start(1)],
            }
        )
    assignment_pattern = re.compile(
        r"(?m)(?:^|(?<=[;{}]))\s*"
        r"([A-Za-z_][A-Za-z0-9_]*)"
        r"((?:\s*(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]]+\]))*)\s*"
        r"(<<=|>>=|\+=|-=|\*=|/=|%=|&=|\|=|\^=|=(?!=))\s*"
        r"([^;]+);",
        re.DOTALL,
    )
    for match in assignment_pattern.finditer(body):
        accessor = match.group(2).strip()
        operator = match.group(3)
        assignments.append(
            {
                "start": match.start(1),
                "target": match.group(1),
                "access_path": _wgsl_access_path(accessor),
                "expression": match.group(4),
                # A plain component write replaces that component, while the
                # path-coverage check below preserves untouched aggregate data.
                # Compound assignments still depend on the prior lvalue.
                "kills_previous": operator == "=",
                "path": block_paths[match.start(1)],
            }
        )
    assignments.sort(key=lambda assignment: int(assignment["start"]))

    dependencies: set[WGSLValueRef] = set()
    return_pattern = re.compile(r"\breturn\s+([^;]+);", re.DOTALL)
    for return_match in return_pattern.finditer(body):
        return_dependencies = _wgsl_projected_expression_refs(
            return_match.group(1)
        )
        return_path = block_paths[return_match.start()]
        for assignment in reversed(assignments):
            if int(assignment["start"]) >= return_match.start():
                continue
            target = str(assignment["target"])
            access_path = tuple(assignment["access_path"])
            affected = {
                dependency
                for dependency in return_dependencies
                if dependency[0] == target
                and _wgsl_paths_overlap(access_path, dependency[1])
            }
            if not affected:
                continue
            lexical_path = tuple(assignment["path"])
            is_ancestor_path = (
                len(lexical_path) <= len(return_path)
                and return_path[: len(lexical_path)] == lexical_path
            )
            if bool(assignment["kills_previous"]) and is_ancestor_path:
                for dependency in affected:
                    if _wgsl_path_covers(access_path, dependency[1]):
                        return_dependencies.discard(dependency)
            rhs_requested_paths: set[tuple[tuple[str, str], ...]] = set()
            for dependency in affected:
                if _wgsl_path_covers(access_path, dependency[1]):
                    rhs_requested_paths.add(dependency[1][len(access_path) :])
                else:
                    rhs_requested_paths.add(())
            for requested_path in rhs_requested_paths:
                return_dependencies.update(
                    _wgsl_projected_expression_refs(
                        str(assignment["expression"]),
                        requested_path,
                    )
                )
        dependencies.update(return_dependencies)
    return {base for base, _ in dependencies}


def _wgsl_functions(source: str) -> dict[str, dict[str, Any]]:
    """Extract live function bodies and call tokens with a bounded lexer."""
    code, _ = _wgsl_lexical_code(source)
    functions: dict[str, dict[str, Any]] = {}
    for match in re.finditer(r"\bfn\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", code):
        name = match.group(1)
        body_start = code.find("{", match.end())
        if body_start < 0:
            continue
        depth = 0
        body_end = None
        for index in range(body_start, len(code)):
            if code[index] == "{":
                depth += 1
            elif code[index] == "}":
                depth -= 1
                if depth == 0:
                    body_end = index
                    break
        if body_end is None:
            continue
        body = _blank_static_false_blocks(code[body_start + 1 : body_end])
        functions[name] = {
            "body": body,
            "calls": set(
                re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", body)
            ),
            "span": (match.start(), body_end + 1),
        }
    user_names = set(functions)
    for record in functions.values():
        dependencies = _wgsl_return_dependencies(str(record["body"]))
        record["return_dependencies"] = dependencies
        record["contributing_calls"] = dependencies & user_names
    return functions


def _reachable_wgsl_functions(
    functions: dict[str, dict[str, Any]],
    root: str,
) -> set[str]:
    """Return user-defined functions reachable from one live entry point."""
    if root not in functions:
        return set()
    reachable: set[str] = set()
    pending = [root]
    while pending:
        name = pending.pop()
        if name in reachable or name not in functions:
            continue
        reachable.add(name)
        pending.extend(functions[name]["contributing_calls"] & functions.keys())
    return reachable


def _wgsl_module_symbols(source: str) -> set[str]:
    """Collect user-defined module values/types that an artifact could capture."""
    code, _ = _wgsl_lexical_code(source)
    symbols = set(
        re.findall(
            r"\b(?:const|override|alias|var(?:\s*<[^>]*>)?)\s+"
            r"([A-Za-z_][A-Za-z0-9_]*)",
            code,
        )
    )
    symbols.update(
        re.findall(r"\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)", code)
    )
    return symbols


def _artifact_dependency_errors(
    shader_source: str,
    block: dict[str, Any],
    *,
    allowed_external_entries: set[str] | None = None,
    required_parent_entries: set[str] | None = None,
    enforce_self_contained: bool = True,
) -> list[str]:
    """Require a live, self-contained artifact linked to declared parents."""
    allowed = set(allowed_external_entries or ())
    required = set(required_parent_entries or ())
    entry_symbol = str(block["entry_symbol"])
    all_functions = _wgsl_functions(shader_source)
    block_functions = _wgsl_functions(str(block["source"]))
    errors: list[str] = []
    if entry_symbol not in block_functions:
        return [
            f"{block['artifact_id']} entry {entry_symbol} has no live definition"
        ]
    reachable_from_entry = _reachable_wgsl_functions(all_functions, entry_symbol)
    live_from_fragment = _reachable_wgsl_functions(all_functions, "fs_main")
    if entry_symbol not in live_from_fragment:
        errors.append(
            f"{block['artifact_id']} entry {entry_symbol} is not reachable from fs_main"
        )

    internal_names = set(block_functions)
    relevant_internal = _reachable_wgsl_functions(block_functions, entry_symbol)
    external_calls: set[str] = set()
    for name in relevant_internal:
        external_calls.update(
            block_functions[name]["calls"] & (all_functions.keys() - internal_names)
        )
    unexpected_calls = external_calls - allowed
    if enforce_self_contained and unexpected_calls:
        errors.append(
            f"{block['artifact_id']} calls mutable helpers outside its block: "
            + ", ".join(sorted(unexpected_calls))
        )

    missing_parents = required - reachable_from_entry
    if missing_parents:
        errors.append(
            f"{block['artifact_id']} does not call required parent artifacts: "
            + ", ".join(sorted(missing_parents))
        )

    if enforce_self_contained:
        external_symbols = _wgsl_module_symbols(
            shader_source
        ) - _wgsl_module_symbols(str(block["source"]))
        block_code, _ = _wgsl_lexical_code(str(block["source"]))
        captured = {
            symbol
            for symbol in external_symbols
            if re.search(rf"\b{re.escape(symbol)}\b", block_code)
        }
        if captured:
            errors.append(
                f"{block['artifact_id']} captures mutable module symbols outside "
                "its block: " + ", ".join(sorted(captured))
            )
    return errors


def _extract_artifact_blocks(shader_source: str) -> dict[str, dict[str, Any]]:
    """Extract exact, server-addressable study candidate blocks."""
    blocks: dict[str, dict[str, Any]] = {}
    _, block_mask = _wgsl_lexical_code(shader_source)
    for match in ARTIFACT_MARKER_RE.finditer(shader_source):
        end_offset = match.group(0).rfind("// @shaderbench-artifact-end")
        if block_mask[match.start()] or block_mask[match.start() + end_offset]:
            continue
        artifact_id = match.group(1)
        if artifact_id in blocks:
            raise ValueError(f"duplicate artifact block: {artifact_id}")
        exact_source = match.group(0)
        blocks[artifact_id] = {
            "artifact_id": artifact_id,
            "study_index": int(match.group(2)),
            "variant": match.group(3),
            "entry_symbol": match.group(4),
            "source": exact_source,
            "sha256": hashlib.sha256(exact_source.encode("utf-8")).hexdigest(),
        }
    return blocks


def _artifact_entry_input_errors(block: dict[str, Any]) -> list[str]:
    """Reject marker tokens that do not lock input-dependent implementation."""
    source, _ = _wgsl_lexical_code(str(block["source"]))
    entry_symbol = str(block["entry_symbol"])
    signature = re.search(
        rf"\bfn\s+{re.escape(entry_symbol)}\s*\((.*?)\)"
        rf"\s*(?:->[^{{]+)?\{{",
        source,
        re.DOTALL,
    )
    if signature is None:
        return [f"{block['artifact_id']} entry function is not defined in its block"]
    parameter_text = signature.group(1).strip()
    if not parameter_text:
        return [
            f"{block['artifact_id']} entry must accept scene coordinates or "
            "another typed parent input; constant parameter tokens are not artifacts"
        ]
    parameter_names = re.findall(
        r"(?:^|,)\s*(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?\s*)*"
        r"([A-Za-z_][A-Za-z0-9_]*)\s*:",
        parameter_text,
    )
    if not parameter_names:
        return [f"{block['artifact_id']} entry parameters could not be validated"]
    body_start = signature.end() - 1
    depth = 0
    body_end = None
    for index in range(body_start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                body_end = index
                break
    if body_end is None:
        return [f"{block['artifact_id']} entry function body is malformed"]
    executable_body = source[body_start + 1 : body_end]
    return_dependencies = _wgsl_return_dependencies(executable_body)
    if not any(name in return_dependencies for name in parameter_names):
        return [
            f"{block['artifact_id']} entry output does not consume any declared input; "
            "lock the candidate implementation, not only constants"
        ]
    return []


def _artifact_manifest_errors(
    shader_source: str,
    study_index: int,
    *,
    allowed_external_entries: set[str] | None = None,
    required_parent_entries: set[str] | None = None,
    enforce_self_contained: bool = True,
) -> list[str]:
    """Require one uniquely marked, callable implementation for every A-F cell."""
    errors: list[str] = []
    try:
        blocks = _extract_artifact_blocks(shader_source)
    except ValueError as error:
        return [str(error)]
    _, block_mask = _wgsl_lexical_code(shader_source)
    begin_count = sum(
        not block_mask[match.start()]
        for match in ARTIFACT_BEGIN_RE.finditer(shader_source)
    )
    end_count = sum(
        not block_mask[match.start()]
        for match in ARTIFACT_END_RE.finditer(shader_source)
    )
    if begin_count != end_count or begin_count != len(blocks):
        errors.append(
            "artifact markers are malformed, nested, duplicated, or unmatched"
        )
    expected = {f"study_{study_index}_{variant}" for variant in VARIANTS}
    present = {
        artifact_id
        for artifact_id, block in blocks.items()
        if block["study_index"] == study_index
    }
    for artifact_id in sorted(expected - present):
        errors.append(f"{artifact_id} missing")
    for artifact_id in sorted(present - expected):
        errors.append(f"unexpected current-study artifact {artifact_id}")
    entries = [
        blocks[artifact_id]["entry_symbol"]
        for artifact_id in sorted(expected & present)
    ]
    if len(entries) != len(set(entries)):
        errors.append("A-F entry symbols must be unique")
    for artifact_id in sorted(expected & present):
        block = blocks[artifact_id]
        errors.extend(_artifact_entry_input_errors(block))
        errors.extend(
            _artifact_dependency_errors(
                shader_source,
                block,
                allowed_external_entries=allowed_external_entries,
                required_parent_entries=required_parent_entries,
                enforce_self_contained=enforce_self_contained,
            )
        )
    return errors


def _crop_atlas_cell(path: Path, variant: str) -> PILImage.Image:
    """Crop an A-F cell from the canonical three-column, two-row atlas."""
    index = VARIANTS.index(variant)
    image = PILImage.open(path).convert("RGB")
    width, height = image.size
    column = index % 3
    row = index // 3
    return image.crop(
        (
            column * width // 3,
            row * height // 2,
            (column + 1) * width // 3,
            (row + 1) * height // 2,
        )
    )


def _parse_selector_output(raw: str) -> dict[str, Any]:
    """Parse the selector's strict JSON response without accepting prose fallback."""
    candidate = raw.strip()
    if candidate.startswith("```"):
        lines = candidate.splitlines()
        if len(lines) >= 3 and lines[-1].strip() == "```":
            candidate = "\n".join(lines[1:-1])
            if candidate.lstrip().startswith("json"):
                candidate = candidate.lstrip()[4:].lstrip()
    if not candidate.startswith("{"):
        start = candidate.find("{")
        end = candidate.rfind("}")
        if start >= 0 and end > start:
            candidate = candidate[start : end + 1]
    parsed = json.loads(candidate)
    if not isinstance(parsed, dict):
        raise ValueError("selector response must be a JSON object")
    return parsed


def _structural_manifest_errors(manifest: str) -> list[str]:
    """Validate auditable A-F representation-family declarations."""
    upper = manifest.upper()
    labels = ("A:", "B:", "C:", "D:", "E:", "F:")
    errors: list[str] = []
    for index, label in enumerate(labels):
        start = upper.find(label)
        if start < 0:
            errors.append(f"{label} missing")
            continue
        end = (
            upper.find(labels[index + 1], start + len(label))
            if index + 1 < len(labels)
            else len(upper)
        )
        section = upper[start:end]
        for field_name in (
            "FAMILY=",
            "CONSTRUCTION=",
            "STRUCTURAL_DIFFERENCE=",
        ):
            if field_name not in section:
                errors.append(f"{label} missing {field_name.lower()}")
    if len(manifest.strip()) < 480:
        errors.append("manifest shorter than 480 characters")
    return errors


def _atlas_diversity_metrics(path: Path) -> dict[str, Any]:
    """Measure visible A-F cell separation in a fixed 3x2 study atlas."""
    image = PILImage.open(path).convert("RGB")
    width, height = image.size
    cells: list[PILImage.Image] = []
    for row in range(2):
        for column in range(3):
            left = column * width // 3
            right = (column + 1) * width // 3
            top = row * height // 2
            bottom = (row + 1) * height // 2
            inset_x = max(1, (right - left) // 50)
            inset_y = max(1, (bottom - top) // 50)
            cell = image.crop(
                (
                    left + inset_x,
                    top + inset_y,
                    right - inset_x,
                    bottom - inset_y,
                )
            )
            cells.append(cell.resize((96, 96)))

    pairwise_mae: list[float] = []
    for first, second in itertools.combinations(cells, 2):
        difference = ImageChops.difference(first, second)
        channel_means = ImageStat.Stat(difference).mean
        pairwise_mae.append(
            sum(channel_means) / (len(channel_means) * 255.0) * 100.0
        )
    mean_mae = sum(pairwise_mae) / len(pairwise_mae)
    max_mae = max(pairwise_mae)
    qualifies = (
        mean_mae >= STUDY_DIVERSITY_MEAN_MAE_MIN
        and max_mae >= STUDY_DIVERSITY_MAX_MAE_MIN
    )
    return {
        "method": "3x2-cell-pairwise-rgb-mae-v1",
        "pair_count": len(pairwise_mae),
        "min_pairwise_mae_percent": round(min(pairwise_mae), 3),
        "mean_pairwise_mae_percent": round(mean_mae, 3),
        "max_pairwise_mae_percent": round(max_mae, 3),
        "mean_threshold_percent": STUDY_DIVERSITY_MEAN_MAE_MIN,
        "max_threshold_percent": STUDY_DIVERSITY_MAX_MAE_MIN,
        "qualifies": qualifies,
    }


def _image_mae_percent(first_path: Path, second_path: Path) -> float:
    """Measure whole-image RGB separation between two study atlases."""
    first = PILImage.open(first_path).convert("RGB").resize((192, 192))
    second = PILImage.open(second_path).convert("RGB").resize((192, 192))
    difference = ImageChops.difference(first, second)
    channel_means = ImageStat.Stat(difference).mean
    return sum(channel_means) / (len(channel_means) * 255.0) * 100.0


def _cross_render_diversity_metrics(
    current_path: Path,
    study_index: int,
    prior_paths: dict[int, list[Path]],
) -> dict[str, Any]:
    """Reject recycled atlases within a study or across study topics."""
    same_study = [
        _image_mae_percent(current_path, prior_path)
        for prior_path in prior_paths.get(study_index, [])
    ]
    other_studies = [
        _image_mae_percent(current_path, prior_path)
        for prior_study, paths in prior_paths.items()
        if prior_study != study_index
        for prior_path in paths
    ]
    same_study_min = min(same_study) if same_study else None
    other_study_min = min(other_studies) if other_studies else None
    qualifies = (
        (same_study_min is None or same_study_min >= STUDY_CROSS_PASS_MAE_MIN)
        and (
            other_study_min is None
            or other_study_min >= STUDY_CROSS_TOPIC_MAE_MIN
        )
    )
    return {
        "method": "whole-atlas-rgb-mae-v1",
        "same_study_comparisons": len(same_study),
        "other_study_comparisons": len(other_studies),
        "same_study_min_mae_percent": (
            round(same_study_min, 3) if same_study_min is not None else None
        ),
        "other_study_min_mae_percent": (
            round(other_study_min, 3) if other_study_min is not None else None
        ),
        "same_study_threshold_percent": STUDY_CROSS_PASS_MAE_MIN,
        "other_study_threshold_percent": STUDY_CROSS_TOPIC_MAE_MIN,
        "qualifies": qualifies,
    }


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        delete=False,
    ) as handle:
        handle.write(content)
        temporary_path = Path(handle.name)
    temporary_path.replace(path)


@dataclass
class ShaderAgentState:
    workspace: Path
    renderer: Path
    render_budget: int
    render_size: int = 1024
    min_successful_revisions: int = 1
    required_studies: int = 0
    require_variant_inventory: bool = False
    min_successful_study_renders: int = 1
    require_study_diversity: bool = False
    require_artifact_blocks: bool = False
    require_study_selector: bool = False
    require_study_promotions: bool = False
    reference_image: Path | None = None
    selector_model: str = "gpt-5.5"
    selector_effort: str = "high"
    selector_runner: Any | None = field(default=None, repr=False)
    resume_existing: bool = False
    protocol: str = "persistent-agent-render-tools-v8"
    graph_enabled: bool = False
    min_graph_nodes: int = 3
    max_graph_nodes: int = 8
    max_graph_depth: int = 3
    final_render_reserve: int = 2
    revision: int = 0
    render_calls: int = 0
    submitted: bool = False
    current_hash: str | None = None
    successful_render_by_revision: dict[int, Path] = field(default_factory=dict)
    successful_render_stage_by_revision: dict[int, str] = field(
        default_factory=dict
    )
    successful_render_hash_by_revision: dict[int, str] = field(
        default_factory=dict
    )
    latest_successful_study_render: dict[int, dict[str, int]] = field(
        default_factory=dict
    )
    latest_successful_promotion_render: dict[int, dict[str, int]] = field(
        default_factory=dict
    )
    successful_study_render_count: dict[int, int] = field(default_factory=dict)
    qualified_study_render_paths: dict[int, list[Path]] = field(
        default_factory=dict
    )
    qualified_study_candidates: dict[int, list[dict[str, Any]]] = field(
        default_factory=dict
    )
    study_rankings: dict[int, dict[str, Any]] = field(default_factory=dict)
    study_records: dict[int, dict[str, Any]] = field(default_factory=dict)
    promotion_records: dict[int, dict[str, Any]] = field(default_factory=dict)
    locked_artifacts: dict[str, dict[str, Any]] = field(default_factory=dict)
    study_dag: AdaptiveStudyDAG | None = field(default=None, init=False)
    node_evaluations: dict[str, list[dict[str, Any]]] = field(
        default_factory=dict
    )
    graph_growth_events: list[dict[str, Any]] = field(default_factory=list)
    attempted_revisions: set[int] = field(default_factory=set)
    events: list[dict[str, Any]] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.workspace = self.workspace.resolve()
        self.renderer = self.renderer.resolve()
        if self.protocol not in {
            "persistent-agent-render-tools-v8",
            "persistent-agent-render-tools-v9",
        }:
            raise ValueError("unsupported shader-agent protocol")
        if self.graph_enabled and self.protocol != "persistent-agent-render-tools-v9":
            raise ValueError("adaptive study graphs require the v9 protocol")
        if not self.graph_enabled and self.protocol == "persistent-agent-render-tools-v9":
            raise ValueError("the v9 protocol requires adaptive graph mode")
        if self.reference_image is not None:
            self.reference_image = self.reference_image.resolve()
        if self.render_budget < 1:
            raise ValueError("render budget must be at least 1")
        if not 1 <= self.min_successful_revisions <= self.render_budget:
            raise ValueError(
                "min_successful_revisions must be between 1 and render_budget"
            )
        if not 0 <= self.required_studies <= 8:
            raise ValueError("required_studies must be between 0 and 8")
        if self.graph_enabled and self.required_studies != 0:
            raise ValueError("adaptive graph mode owns studies; required_studies must be 0")
        if (
            self.graph_enabled
            and self.final_render_reserve < self.min_successful_revisions
        ):
            raise ValueError(
                "final_render_reserve must cover min_successful_revisions"
            )
        if self.min_successful_study_renders < 1:
            raise ValueError("min_successful_study_renders must be at least 1")
        minimum_budget = (
            self.min_successful_revisions
            if self.graph_enabled
            else self.required_studies * self.min_successful_study_renders
            + (
                self.required_studies
                if self.require_study_promotions
                else 0
            )
            + self.min_successful_revisions
        )
        if self.render_budget < minimum_budget:
            raise ValueError(
                "render budget must allow every required study plus the "
                "minimum successful final revisions"
            )
        if not self.renderer.is_file():
            raise FileNotFoundError(f"renderer not found: {self.renderer}")
        if self.require_study_selector and (
            self.reference_image is None or not self.reference_image.is_file()
        ):
            raise FileNotFoundError(
                "an isolated reference image is required for study selection"
            )
        if self.require_study_promotions and not self.require_artifact_blocks:
            raise ValueError(
                "study promotions require exact artifact blocks"
            )
        self.workspace.mkdir(parents=True, exist_ok=True)
        (self.workspace / "renders").mkdir(exist_ok=True)
        (self.workspace / "artifacts").mkdir(exist_ok=True)
        (self.workspace / "selectors").mkdir(exist_ok=True)
        if self.resume_existing:
            if not self.state_path.is_file():
                raise FileNotFoundError(
                    f"resume checkpoint not found: {self.state_path}"
                )
            self._load_checkpoint()
        else:
            if self.graph_enabled:
                self.study_dag = AdaptiveStudyDAG(
                    min_initial_nodes=self.min_graph_nodes,
                    max_nodes=self.max_graph_nodes,
                    max_depth=self.max_graph_depth,
                    render_budget=self.render_budget,
                    final_render_reserve=self.final_render_reserve,
                )
            self._persist()

    @property
    def shader_path(self) -> Path:
        return self.workspace / "shader.wgsl"

    @property
    def state_path(self) -> Path:
        return self.workspace / "agent_state.json"

    def _checkpoint_owned_file(
        self,
        raw_path: object,
        expected_path: Path,
        label: str,
    ) -> Path:
        """Resolve one persisted server file without trusting checkpoint paths."""
        if not isinstance(raw_path, str) or not raw_path:
            raise ValueError(f"checkpoint {label} path must be a non-empty string")
        supplied = Path(raw_path)
        if not supplied.is_absolute():
            raise ValueError(f"checkpoint {label} path must be absolute")
        expected = expected_path.absolute()
        try:
            relative = expected.relative_to(self.workspace)
        except ValueError as error:
            raise ValueError(f"checkpoint {label} expected path escaped workspace") from error
        cursor = self.workspace
        for component in relative.parts:
            cursor /= component
            if cursor.is_symlink():
                raise ValueError(f"checkpoint {label} path contains a symlink")
        try:
            resolved = supplied.resolve(strict=True)
        except FileNotFoundError as error:
            raise FileNotFoundError(
                f"checkpoint {label} file is missing: {supplied}"
            ) from error
        if not resolved.is_relative_to(self.workspace) or resolved != expected.resolve():
            raise ValueError(f"checkpoint {label} path escaped its server-owned path")
        if not resolved.is_file():
            raise ValueError(f"checkpoint {label} path is not a regular file")
        return resolved

    def _event(self, event_type: str, **details: Any) -> None:
        self.events.append(
            {"timestamp": _utc_now(), "type": event_type, **details}
        )
        self._persist()

    def _load_checkpoint(self) -> None:
        """Rehydrate exact state after an interrupted outer model session."""
        payload = json.loads(self.state_path.read_text(encoding="utf-8"))
        if payload.get("protocol") != self.protocol:
            raise ValueError("checkpoint protocol does not match this server")
        if int(payload.get("render_budget", -1)) != self.render_budget:
            raise ValueError("resume render budget does not match checkpoint")
        raw_revision = payload.get("revision", 0)
        if (
            not isinstance(raw_revision, int)
            or isinstance(raw_revision, bool)
            or raw_revision < 0
        ):
            raise ValueError("checkpoint revision must be a non-negative integer")
        raw_render_calls = payload.get("render_calls", 0)
        if (
            not isinstance(raw_render_calls, int)
            or isinstance(raw_render_calls, bool)
            or not 0 <= raw_render_calls <= self.render_budget
        ):
            raise ValueError(
                "checkpoint render_calls must be an integer within render_budget"
            )
        self.revision = raw_revision
        self.render_calls = raw_render_calls
        self.submitted = bool(payload.get("submitted", False))
        self.current_hash = payload.get("current_hash")
        self.events = list(payload.get("events", []))
        self.attempted_revisions = {
            int(event["revision"])
            for event in self.events
            if event.get("type") == "render_shader"
            and event.get("revision") is not None
        }
        for event in self.events:
            if event.get("type") != "render_shader":
                continue
            call = event.get("render_call")
            revision_value = event.get("revision")
            if (
                not isinstance(call, int)
                or isinstance(call, bool)
                or call < 1
                or not isinstance(revision_value, int)
                or isinstance(revision_value, bool)
                or revision_value < 0
            ):
                raise ValueError("checkpoint render event has invalid call/revision")
            if event.get("log"):
                self._checkpoint_owned_file(
                    event["log"],
                    self.workspace / "renders" / f"render_{call:02d}.log",
                    f"render {call} log",
                )
            if not event.get("ok"):
                continue
            revision = revision_value
            image_path = self._checkpoint_owned_file(
                event.get("image"),
                self.workspace / "renders" / f"render_{call:02d}.png",
                f"render {call} image",
            )
            self.successful_render_by_revision[revision] = image_path
            self.successful_render_stage_by_revision[revision] = str(
                event.get("stage", "final")
            )
            if event.get("sha256"):
                self.successful_render_hash_by_revision[revision] = str(
                    event["sha256"]
                )
            if event.get("stage") == "promotion":
                self.latest_successful_promotion_render[
                    int(event["study_index"])
                ] = {
                    "revision": revision,
                    "render_call": int(event["render_call"]),
                }
        self.successful_study_render_count = {
            int(index): int(count)
            for index, count in payload.get(
                "successful_study_render_count", {}
            ).items()
        }
        self.qualified_study_render_paths = {
            int(index): [
                self._checkpoint_owned_file(
                    path,
                    self.workspace
                    / "renders"
                    / f"render_{int(Path(str(path)).stem.split('_')[-1]):02d}.png",
                    f"qualified study {index} render",
                )
                for path in paths
            ]
            for index, paths in payload.get(
                "qualified_study_render_paths", {}
            ).items()
        }
        self.qualified_study_candidates = {
            int(index): [
                {
                    **candidate,
                    "atlas_path": self._checkpoint_owned_file(
                        candidate["atlas_path"],
                        self.workspace
                        / "renders"
                        / f"render_{int(candidate['render_call']):02d}.png",
                        f"study {index} candidate atlas",
                    ),
                    "source_path": self._checkpoint_owned_file(
                        candidate["source_path"],
                        self.workspace
                        / "renders"
                        / (
                            f"render_{int(candidate['render_call']):02d}_"
                            f"revision_{int(candidate['revision']):02d}.wgsl"
                        ),
                        f"study {index} candidate source",
                    ),
                }
                for candidate in candidates
            ]
            for index, candidates in payload.get(
                "qualified_study_candidates", {}
            ).items()
        }
        for study_index, candidates in self.qualified_study_candidates.items():
            if not candidates:
                continue
            latest = max(candidates, key=lambda item: int(item["render_call"]))
            self.latest_successful_study_render[study_index] = {
                "revision": int(latest["revision"]),
                "render_call": int(latest["render_call"]),
                "study_pass": int(latest["study_pass"]),
            }
        self.study_rankings = {
            int(index): record
            for index, record in payload.get("study_rankings", {}).items()
        }
        for study_index, record in self.study_rankings.items():
            record["candidate_sheet"] = str(
                self._checkpoint_owned_file(
                    record.get("candidate_sheet"),
                    self.workspace
                    / "selectors"
                    / f"study_{study_index:02d}_candidates.png",
                    f"study {study_index} selector sheet",
                )
            )
            for candidate_id, candidate in record.get("candidate_map", {}).items():
                render_call = int(candidate["render_call"])
                revision = int(candidate["revision"])
                candidate["atlas_path"] = str(
                    self._checkpoint_owned_file(
                        candidate["atlas_path"],
                        self.workspace / "renders" / f"render_{render_call:02d}.png",
                        f"study {study_index} selector {candidate_id} atlas",
                    )
                )
                candidate["source_path"] = str(
                    self._checkpoint_owned_file(
                        candidate["source_path"],
                        self.workspace
                        / "renders"
                        / f"render_{render_call:02d}_revision_{revision:02d}.wgsl",
                        f"study {study_index} selector {candidate_id} source",
                    )
                )
        self.study_records = {
            int(index): record
            for index, record in payload.get("study_records", {}).items()
        }
        self.promotion_records = {
            int(index): record
            for index, record in payload.get("promotion_records", {}).items()
        }
        for artifact_id, metadata in payload.get(
            "locked_artifacts", {}
        ).items():
            if not re.fullmatch(r"study_(\d+)_([A-F])", str(artifact_id)):
                raise ValueError(f"invalid locked artifact id: {artifact_id}")
            source_path = Path(str(metadata["artifact_source_path"]))
            expected_path = (
                self.workspace / "artifacts" / artifact_id / "artifact.wgsl"
            ).resolve()
            if source_path.is_symlink():
                raise ValueError(
                    f"locked artifact source cannot be a symlink: {source_path}"
                )
            try:
                resolved_source_path = source_path.resolve(strict=True)
            except FileNotFoundError:
                raise FileNotFoundError(
                    f"locked artifact source missing: {source_path}"
                )
            if (
                not resolved_source_path.is_relative_to(self.workspace)
                or resolved_source_path != expected_path
            ):
                raise ValueError(
                    f"locked artifact source escaped its server-owned path: "
                    f"{source_path}"
                )
            owned_cursor = self.workspace
            for component in ("artifacts", artifact_id, "artifact.wgsl"):
                owned_cursor /= component
                if owned_cursor.is_symlink():
                    raise ValueError(
                        f"locked artifact path contains a symlink: {owned_cursor}"
                    )
            source = resolved_source_path.read_text(encoding="utf-8")
            for path_key, filename in (
                ("artifact_crop_path", "selected.png"),
                ("artifact_atlas_path", "atlas.png"),
                ("artifact_origin_shader_path", "atlas.wgsl"),
            ):
                self._checkpoint_owned_file(
                    metadata.get(path_key),
                    expected_path.parent / filename,
                    f"locked artifact {artifact_id} {path_key}",
                )
            digest = hashlib.sha256(source.encode("utf-8")).hexdigest()
            if digest != metadata.get("sha256"):
                raise ValueError(
                    f"locked artifact hash mismatch on resume: {artifact_id}"
                )
            blocks = _extract_artifact_blocks(source)
            if set(blocks) != {artifact_id}:
                raise ValueError(
                    f"locked artifact file has invalid marker identity: {artifact_id}"
                )
            block = blocks[artifact_id]
            expected_study = int(artifact_id.split("_")[1])
            expected_variant = artifact_id.rsplit("_", 1)[1]
            if (
                int(metadata.get("study_index", -1)) != expected_study
                or metadata.get("variant") != expected_variant
                or metadata.get("entry_symbol") != block["entry_symbol"]
                or block["sha256"] != digest
            ):
                raise ValueError(
                    f"locked artifact metadata mismatch on resume: {artifact_id}"
                )
            manifest_path = expected_path.parent / "manifest.json"
            if manifest_path.is_symlink() or not manifest_path.is_file():
                raise ValueError(
                    f"locked artifact manifest is missing or symlinked: {artifact_id}"
                )
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest_keys = (
                "artifact_id",
                "study_index",
                "variant",
                "entry_symbol",
                "sha256",
                "origin_revision",
                "origin_render_call",
                "artifact_source_path",
                "artifact_crop_path",
                "artifact_atlas_path",
                "artifact_origin_shader_path",
                "status",
            )
            if any(manifest.get(key) != metadata.get(key) for key in manifest_keys):
                raise ValueError(
                    f"locked artifact manifest disagrees with state: {artifact_id}"
                )
            input_errors = _artifact_entry_input_errors(block)
            if input_errors and not self.submitted:
                raise ValueError("; ".join(input_errors))
            self.locked_artifacts[artifact_id] = {
                **metadata,
                "artifact_source_path": str(resolved_source_path),
                "source": source,
            }
        if self.require_artifact_blocks:
            for study_index, promotion in self.promotion_records.items():
                artifact_id = str(promotion.get("artifact_id", ""))
                artifact_dir = self.workspace / "artifacts" / artifact_id
                self._checkpoint_owned_file(
                    promotion.get("promotion_shader"),
                    artifact_dir / "promotion.wgsl",
                    f"study {study_index} promotion shader",
                )
                self._checkpoint_owned_file(
                    promotion.get("promotion_render"),
                    artifact_dir / "promotion.png",
                    f"study {study_index} promotion render",
                )
        self.node_evaluations = {
            str(node_id): list(records)
            for node_id, records in payload.get("node_evaluations", {}).items()
        }
        self.graph_growth_events = list(
            payload.get("graph_growth_events", [])
        )
        if self.graph_enabled:
            graph_payload = payload.get("study_dag")
            if graph_payload is None:
                raise ValueError("v9 checkpoint is missing study_dag state")
            self.study_dag = AdaptiveStudyDAG.from_dict(graph_payload)
            if self.study_dag.render_calls_used != self.render_calls:
                raise ValueError(
                    "graph and shader-agent render ledgers disagree"
                )
            graph_config = self.study_dag.to_dict()["config"]
            expected_graph_config = {
                "min_initial_nodes": self.min_graph_nodes,
                "max_nodes": self.max_graph_nodes,
                "max_depth": self.max_graph_depth,
                "render_budget": self.render_budget,
                "final_render_reserve": self.final_render_reserve,
            }
            mismatches = {
                key: {
                    "checkpoint": graph_config[key],
                    "configured": value,
                }
                for key, value in expected_graph_config.items()
                if graph_config[key] != value
            }
            if mismatches:
                raise ValueError(
                    "resume graph configuration does not match checkpoint: "
                    + json.dumps(mismatches, sort_keys=True)
                )
        self._validate_checkpoint_consistency(payload)

    def _validate_checkpoint_consistency(self, payload: dict[str, Any]) -> None:
        """Cross-check persisted files, events, graph state, and lineage ledgers."""
        render_events = [
            event
            for event in self.events
            if event.get("type") == "render_shader"
            and event.get("render_call") is not None
        ]
        render_numbers = sorted(int(event["render_call"]) for event in render_events)
        if render_numbers != list(range(1, self.render_calls + 1)):
            raise ValueError("checkpoint render event ledger is not contiguous")

        if self.revision:
            if not self.shader_path.is_file():
                raise FileNotFoundError("checkpoint head shader is missing")
            head_source = self.shader_path.read_text(encoding="utf-8")
            head_digest = hashlib.sha256(head_source.encode("utf-8")).hexdigest()
            if head_digest != self.current_hash:
                raise ValueError("checkpoint head shader hash does not match state")
            lineage_errors = self._locked_artifact_errors(head_source)
            if lineage_errors:
                raise ValueError(
                    "checkpoint executable artifact lineage is invalid: "
                    + "; ".join(lineage_errors)
                )
        elif self.current_hash is not None:
            raise ValueError("revision-zero checkpoint cannot have a shader hash")

        if not self.graph_enabled:
            return
        graph = self._require_study_dag()
        snapshots = graph.snapshots()
        known_indexes = {snapshot.study_index for snapshot in snapshots}
        for mapping_name, mapping in (
            ("study_records", self.study_records),
            ("promotion_records", self.promotion_records),
            ("successful_study_render_count", self.successful_study_render_count),
        ):
            unknown = set(mapping) - known_indexes
            if unknown:
                raise ValueError(
                    f"checkpoint {mapping_name} references unknown studies: "
                    f"{sorted(unknown)}"
                )

        artifacts_by_study: dict[int, list[dict[str, Any]]] = {}
        for metadata in self.locked_artifacts.values():
            artifacts_by_study.setdefault(int(metadata["study_index"]), []).append(
                metadata
            )
        for snapshot in snapshots:
            index = snapshot.study_index
            successful_passes = self.successful_study_render_count.get(index, 0)
            if successful_passes != snapshot.successful_passes:
                raise ValueError(
                    f"checkpoint pass ledger disagrees for study {index}: "
                    f"{successful_passes} != {snapshot.successful_passes}"
                )
            has_record = index in self.study_records
            has_promotion = index in self.promotion_records
            artifacts = artifacts_by_study.get(index, [])
            if has_record != (snapshot.status in {"selected", "promoted"}):
                raise ValueError(
                    f"checkpoint selection ledger disagrees for study {index}"
                )
            if has_promotion != (snapshot.status == "promoted"):
                raise ValueError(
                    f"checkpoint promotion ledger disagrees for study {index}"
                )
            if self.require_artifact_blocks:
                expected_artifact_count = (
                    1 if snapshot.status in {"selected", "promoted"} else 0
                )
                if len(artifacts) != expected_artifact_count:
                    raise ValueError(
                        f"checkpoint artifact ledger disagrees for study {index}"
                    )
                if artifacts:
                    expected_status = (
                        "promoted_locked"
                        if snapshot.status == "promoted"
                        else "selected_pending_promotion"
                    )
                    if artifacts[0].get("status") != expected_status:
                        raise ValueError(
                            f"checkpoint artifact status disagrees for study {index}"
                        )

        distinct_final_hashes = {
            self.successful_render_hash_by_revision.get(revision)
            for revision, stage in self.successful_render_stage_by_revision.items()
            if stage == "final"
        }
        distinct_final_hashes.discard(None)
        if len(distinct_final_hashes) != graph.successful_final_renders:
            raise ValueError(
                "checkpoint graph final ledger disagrees with distinct final hashes"
            )

    def _persist(self) -> None:
        payload = {
            "protocol": self.protocol,
            "render_budget": self.render_budget,
            "render_calls": self.render_calls,
            "remaining_renders": max(0, self.render_budget - self.render_calls),
            "min_successful_revisions": self.min_successful_revisions,
            "successful_revisions": len(self.successful_render_by_revision),
            "successful_final_revisions": sum(
                stage == "final"
                for stage in self.successful_render_stage_by_revision.values()
            ),
            "required_studies": self.required_studies,
            "require_variant_inventory": self.require_variant_inventory,
            "min_successful_study_renders": self.min_successful_study_renders,
            "require_study_diversity": self.require_study_diversity,
            "require_artifact_blocks": self.require_artifact_blocks,
            "require_study_selector": self.require_study_selector,
            "require_study_promotions": self.require_study_promotions,
            "selector_model": self.selector_model,
            "selector_effort": self.selector_effort,
            "successful_study_render_count": self.successful_study_render_count,
            "qualified_study_render_paths": {
                str(index): [str(path) for path in paths]
                for index, paths in self.qualified_study_render_paths.items()
            },
            "qualified_study_candidates": {
                str(index): [
                    {
                        key: str(value) if isinstance(value, Path) else value
                        for key, value in candidate.items()
                    }
                    for candidate in candidates
                ]
                for index, candidates in self.qualified_study_candidates.items()
            },
            "study_rankings": self.study_rankings,
            "completed_studies": sorted(self.study_records),
            "study_records": self.study_records,
            "completed_promotions": sorted(self.promotion_records),
            "promotion_records": self.promotion_records,
            "locked_artifacts": {
                artifact_id: {
                    key: value
                    for key, value in artifact.items()
                    if key != "source"
                }
                for artifact_id, artifact in self.locked_artifacts.items()
            },
            "graph_enabled": self.graph_enabled,
            "study_dag": (
                self.study_dag.to_dict() if self.study_dag is not None else None
            ),
            "node_evaluations": self.node_evaluations,
            "graph_growth_events": self.graph_growth_events,
            "revision": self.revision,
            "current_hash": self.current_hash,
            "submitted": self.submitted,
            "events": self.events,
        }
        _atomic_write(self.state_path, json.dumps(payload, indent=2))

    def _require_study_dag(self) -> AdaptiveStudyDAG:
        if not self.graph_enabled or self.study_dag is None:
            raise StudyDAGError("adaptive study graph tools are disabled")
        return self.study_dag

    def _study_graph_snapshot(self) -> dict[str, Any]:
        graph = self._require_study_dag()
        frontier = set(graph.frontier_node_ids())
        return {
            "graph_closed": graph.graph_closed,
            "final_node_id": graph.final_node_id,
            "render_calls_used": graph.render_calls_used,
            "render_budget": graph.render_budget,
            "budget_remaining": graph.budget_remaining,
            "minimum_remaining_work": graph.minimum_remaining_work,
            "remaining_final_reserve": graph.remaining_final_reserve,
            "budget_slack": graph.budget_slack,
            "ready_frontier": list(graph.frontier_node_ids()),
            "nodes": [
                {
                    **snapshot.node.to_dict(),
                    "study_index": snapshot.study_index,
                    "status": snapshot.status,
                    "successful_passes": snapshot.successful_passes,
                    "required_passes": snapshot.required_passes,
                    "ready": snapshot.node.node_id in frontier,
                    "latest_evaluation": (
                        self.node_evaluations.get(snapshot.node.node_id, [None])[-1]
                        if self.node_evaluations.get(snapshot.node.node_id)
                        else None
                    ),
                }
                for snapshot in graph.snapshots()
            ],
            "growth_events": self.graph_growth_events,
        }

    def define_study_graph(
        self,
        graph_json: str,
        rationale: str,
    ) -> dict[str, Any]:
        """Define the bounded initial study DAG before any shader work."""
        graph = self._require_study_dag()
        if self.revision or self.render_calls:
            return {
                "ok": False,
                "error": "define the initial study graph before writing or rendering WGSL",
            }
        if len(rationale.strip()) < 120:
            return {
                "ok": False,
                "error": (
                    "rationale must contain at least 120 characters explaining "
                    "the visual risks, dependency boundaries, and joins"
                ),
            }
        try:
            nodes = json.loads(graph_json)
            assignments = graph.define_nodes(nodes)
        except (json.JSONDecodeError, StudyDAGError) as error:
            return {"ok": False, "error": str(error)}
        event = {
            "timestamp": _utc_now(),
            "type": "define_study_graph",
            "assignments": assignments,
            "rationale": rationale.strip()[:4_000],
        }
        self.graph_growth_events.append(event)
        result = {
            "ok": True,
            "assignments": assignments,
            "rationale": event["rationale"],
            **self._study_graph_snapshot(),
        }
        self._event("define_study_graph", **result)
        return result

    def inspect_study_graph(self) -> dict[str, Any]:
        try:
            return {"ok": True, **self._study_graph_snapshot()}
        except StudyDAGError as error:
            return {"ok": False, "error": str(error)}

    def begin_study_node(self, node_id: str) -> dict[str, Any]:
        """Activate one topologically ready node and return its stable index."""
        try:
            graph = self._require_study_dag()
            snapshot = graph.snapshot(node_id)
            if snapshot.status == "pending":
                snapshot = graph.begin_node(node_id)
            elif snapshot.status != "active":
                raise StudyDAGError(
                    "only a pending ready node or already-active node can begin"
                )
        except StudyDAGError as error:
            return {"ok": False, "error": str(error)}
        index = snapshot.study_index
        result = {
            "ok": True,
            "node_id": node_id,
            "study_index": index,
            "status": snapshot.status,
            "required_passes": snapshot.required_passes,
            "successful_passes": snapshot.successful_passes,
            "depends_on": list(snapshot.node.depends_on),
            "decision_question": snapshot.node.decision_question,
            "success_criteria": list(snapshot.node.success_criteria),
            "failure_signals": list(snapshot.node.failure_signals),
            "artifact_ids": [
                f"study_{index}_{variant}" for variant in VARIANTS
            ],
            "ready_frontier": list(graph.frontier_node_ids()),
        }
        self._event("begin_study_node", **result)
        return result

    @staticmethod
    def _parse_string_list(raw: str, field: str) -> list[str]:
        try:
            values = json.loads(raw)
        except json.JSONDecodeError as error:
            raise StudyDAGError(f"{field} is invalid JSON: {error}") from error
        if (
            not isinstance(values, list)
            or any(not isinstance(value, str) or not value.strip() for value in values)
        ):
            raise StudyDAGError(f"{field} must be a JSON array of strings")
        return [value.strip() for value in values]

    @staticmethod
    def _parse_residuals(raw: str) -> list[dict[str, Any]]:
        try:
            values = json.loads(raw)
        except json.JSONDecodeError as error:
            raise StudyDAGError(f"residuals_json is invalid JSON: {error}") from error
        if not isinstance(values, list):
            raise StudyDAGError("residuals_json must be a JSON array")
        parsed: list[dict[str, Any]] = []
        for value in values:
            if not isinstance(value, dict) or set(value) != {"residual", "severity"}:
                raise StudyDAGError(
                    "each residual must contain exactly residual and severity"
                )
            residual = value["residual"]
            severity = value["severity"]
            if not isinstance(residual, str) or not residual.strip():
                raise StudyDAGError("residual text must be non-empty")
            if (
                isinstance(severity, bool)
                or not isinstance(severity, (int, float))
                or not 0.0 <= float(severity) <= 1.0
            ):
                raise StudyDAGError("residual severity must be between 0 and 1")
            parsed.append(
                {"residual": residual.strip(), "severity": float(severity)}
            )
        return parsed

    def evaluate_study_node(
        self,
        node_id: str,
        decision: str,
        visible_evidence: str,
        failed_criteria_json: str,
        residuals_json: str,
        expected_information_gain: float,
    ) -> dict[str, Any]:
        """Record public accept/expand evidence after full-frame promotion."""
        try:
            graph = self._require_study_dag()
            snapshot = graph.snapshot(node_id)
            if snapshot.status != "promoted":
                raise StudyDAGError("evaluate only after exact full-frame promotion")
            if decision not in {"accept", "expand"}:
                raise StudyDAGError("decision must be accept or expand")
            if len(visible_evidence.strip()) < 100:
                raise StudyDAGError(
                    "visible_evidence must contain at least 100 characters"
                )
            failed = self._parse_string_list(
                failed_criteria_json, "failed_criteria_json"
            )
            unknown = sorted(set(failed) - set(snapshot.node.success_criteria))
            if unknown:
                raise StudyDAGError(
                    f"failed criteria must exactly match declared criteria: {unknown}"
                )
            residuals = self._parse_residuals(residuals_json)
            if (
                isinstance(expected_information_gain, bool)
                or not isinstance(expected_information_gain, (int, float))
                or not 0.0 <= float(expected_information_gain) <= 1.0
            ):
                raise StudyDAGError(
                    "expected_information_gain must be between 0 and 1"
                )
            if decision == "accept":
                if failed:
                    raise StudyDAGError(
                        "accept requires every declared success criterion to pass"
                    )
                severe_residuals = [
                    residual
                    for residual in residuals
                    if residual["severity"] > 0.25
                ]
                if severe_residuals or float(expected_information_gain) >= 0.1:
                    raise StudyDAGError(
                        "accept permits only residual severity <= 0.25 and "
                        "expected_information_gain < 0.1"
                    )
            if decision == "expand" and (
                not failed
                or not residuals
                or float(expected_information_gain) < 0.1
            ):
                raise StudyDAGError(
                    "expand requires failed criteria, residuals, and information gain >= 0.1"
                )
        except StudyDAGError as error:
            return {"ok": False, "error": str(error)}
        record = {
            "timestamp": _utc_now(),
            "node_id": node_id,
            "study_index": snapshot.study_index,
            "decision": decision,
            "visible_evidence": visible_evidence.strip()[:4_000],
            "failed_criteria": failed,
            "residuals": residuals,
            "expected_information_gain": float(expected_information_gain),
        }
        self.node_evaluations.setdefault(node_id, []).append(record)
        result = {"ok": True, **record, **self._study_graph_snapshot()}
        self._event("evaluate_study_node", **result)
        return result

    def expand_study_graph(
        self,
        source_node_id: str,
        graph_json: str,
        visible_evidence: str,
        failed_criteria_json: str,
        expected_information_gain: float,
    ) -> dict[str, Any]:
        """Append evidence-backed children without mutating prior graph nodes."""
        try:
            graph = self._require_study_dag()
            source = graph.snapshot(source_node_id)
            if source.status != "promoted":
                raise StudyDAGError("only a promoted node can grow children")
            evaluations = self.node_evaluations.get(source_node_id, [])
            if not evaluations or evaluations[-1]["decision"] != "expand":
                raise StudyDAGError(
                    "record an expand evaluation for this node before growth"
                )
            if len(visible_evidence.strip()) < 100:
                raise StudyDAGError(
                    "visible_evidence must contain at least 100 characters"
                )
            failed = self._parse_string_list(
                failed_criteria_json, "failed_criteria_json"
            )
            if sorted(failed) != sorted(evaluations[-1]["failed_criteria"]):
                raise StudyDAGError(
                    "growth failed criteria must match the latest evaluation"
                )
            if not 0.1 <= float(expected_information_gain) <= 1.0:
                raise StudyDAGError(
                    "expected_information_gain must be between 0.1 and 1"
                )
            if (
                abs(
                    float(expected_information_gain)
                    - float(evaluations[-1]["expected_information_gain"])
                )
                > 1e-9
            ):
                raise StudyDAGError(
                    "growth information gain must match the latest evaluation"
                )
            nodes = json.loads(graph_json)
            if isinstance(nodes, list) and len(nodes) > 2:
                raise StudyDAGError(
                    "one evaluation may append at most two focused child nodes"
                )
            if not isinstance(nodes, list) or not any(
                isinstance(node, dict)
                and source_node_id in node.get("depends_on", [])
                for node in nodes
            ):
                raise StudyDAGError(
                    "growth must add at least one direct child of source_node_id"
                )
            assignments = graph.expand_nodes(nodes)
        except (json.JSONDecodeError, StudyDAGError, TypeError, ValueError) as error:
            return {"ok": False, "error": str(error)}
        growth = {
            "timestamp": _utc_now(),
            "type": "expand_study_graph",
            "source_node_id": source_node_id,
            "assignments": assignments,
            "visible_evidence": visible_evidence.strip()[:4_000],
            "failed_criteria": failed,
            "expected_information_gain": float(expected_information_gain),
        }
        self.graph_growth_events.append(growth)
        result = {"ok": True, **growth, **self._study_graph_snapshot()}
        self._event("expand_study_graph", **result)
        return result

    def close_study_graph(self, evidence: str) -> dict[str, Any]:
        """Freeze one all-promoted, fully evaluated integration DAG."""
        try:
            graph = self._require_study_dag()
            if len(evidence.strip()) < 120:
                raise StudyDAGError(
                    "closure evidence must contain at least 120 characters"
                )
            unevaluated = [
                snapshot.node.node_id
                for snapshot in graph.snapshots()
                if not self.node_evaluations.get(snapshot.node.node_id)
                or self.node_evaluations[snapshot.node.node_id][-1]["decision"]
                != "accept"
            ]
            if unevaluated:
                raise StudyDAGError(
                    f"every node needs a latest accept evaluation: {unevaluated}"
                )
            snapshots = graph.snapshots()
            dependency_ids = {
                dependency
                for snapshot in snapshots
                for dependency in snapshot.node.depends_on
            }
            sinks = [
                snapshot.node.node_id
                for snapshot in snapshots
                if snapshot.node.node_id not in dependency_ids
            ]
            if len(sinks) == 1 and graph.node(sinks[0]).mode != "integrate":
                raise StudyDAGError("the unique final sink must use integrate mode")
            final_node_id = graph.close_graph()
        except StudyDAGError as error:
            return {"ok": False, "error": str(error)}
        result = {
            "ok": True,
            "final_node_id": final_node_id,
            "evidence": evidence.strip()[:4_000],
            **self._study_graph_snapshot(),
        }
        self._event("close_study_graph", **result)
        return result

    def _locked_artifact_errors(self, shader_source: str) -> list[str]:
        """Reject missing, edited, or dead-only promoted implementations."""
        if not self.locked_artifacts:
            return []
        try:
            blocks = _extract_artifact_blocks(shader_source)
        except ValueError as error:
            return [str(error)]
        errors: list[str] = []
        strict_dependencies = (
            self.protocol == "persistent-agent-render-tools-v9"
            and not self.submitted
        )
        for artifact_id, locked in sorted(self.locked_artifacts.items()):
            current = blocks.get(artifact_id)
            if current is None:
                errors.append(f"locked artifact {artifact_id} is missing")
                continue
            if current["source"] != locked["source"]:
                errors.append(
                    f"locked artifact {artifact_id} changed byte-for-byte"
                )
                continue
            parent_entries: set[str] = set()
            if strict_dependencies:
                try:
                    parent_entries = self._artifact_parent_entries(
                        int(locked["study_index"])
                    )
                except (KeyError, StudyDAGError, ValueError) as error:
                    errors.append(f"locked artifact {artifact_id}: {error}")
                    continue
            if not self.submitted:
                errors.extend(_artifact_entry_input_errors(current))
            errors.extend(
                _artifact_dependency_errors(
                    shader_source,
                    current,
                    allowed_external_entries=parent_entries,
                    required_parent_entries=parent_entries,
                    enforce_self_contained=strict_dependencies,
                )
            )
        return errors

    def _artifact_parent_entries(self, study_index: int) -> set[str]:
        """Resolve the exact selected entry symbols this study must build on."""
        parent_indexes: set[int]
        if self.graph_enabled and self.study_dag is not None:
            node_id = self.study_dag.node_id_for_index(study_index)
            parent_indexes = {
                self.study_dag.snapshot(dependency).study_index
                for dependency in self.study_dag.node(node_id).depends_on
            }
        else:
            parent_indexes = {
                index for index in self.study_records if index < study_index
            }
        entries = {
            str(metadata["entry_symbol"])
            for metadata in self.locked_artifacts.values()
            if int(metadata["study_index"]) in parent_indexes
        }
        if len(entries) != len(parent_indexes):
            missing = sorted(
                parent_indexes
                - {
                    int(metadata["study_index"])
                    for metadata in self.locked_artifacts.values()
                }
            )
            raise StudyDAGError(
                "declared parent nodes are missing selected executable artifacts: "
                + ", ".join(str(index) for index in missing)
            )
        return entries

    def _expand_locked_artifact_injections(
        self,
        shader_source: str,
    ) -> tuple[str, list[str], list[str]]:
        """Replace server-owned placeholders with exact immutable source."""
        errors: list[str] = []
        injected: list[str] = []
        matches: dict[str, int] = {}
        for match in ARTIFACT_INJECT_RE.finditer(shader_source):
            artifact_id = match.group(1)
            matches[artifact_id] = matches.get(artifact_id, 0) + 1
        for artifact_id, count in sorted(matches.items()):
            if artifact_id not in self.locked_artifacts:
                errors.append(
                    f"cannot inject unknown or unselected artifact {artifact_id}"
                )
            if count != 1:
                errors.append(
                    f"artifact injection {artifact_id} appears {count} times"
                )
        if errors:
            return shader_source, injected, errors
        expanded = shader_source
        for artifact_id, count in sorted(matches.items()):
            if count != 1:
                continue
            pattern = re.compile(
                rf"(?m)^// @shaderbench-inject "
                rf"id={re.escape(artifact_id)}[ \t]*(?:\n|$)"
            )
            expanded = pattern.sub(
                lambda _: self.locked_artifacts[artifact_id]["source"],
                expanded,
                count=1,
            )
            injected.append(artifact_id)
        return expanded, injected, errors

    def _selector_rubric(self, study_index: int) -> str:
        common = (
            "Judge visible fidelity to the reference, not implementation "
            "convenience. Do not reward a candidate for being easier to attach, "
            "cleaner to clip, more complex, more regular, or more complete if "
            "those traits weaken the target. Penalize generic ovals, glued-on "
            "parts, arbitrary repeated batches, and geometric regularity that "
            "erases character. Prefer distinctive curvature, meaningful "
            "negative space, coherent overlap, specific proportions, and an "
            "organic relationship between soft and hard edges."
        )
        if self.graph_enabled and self.study_dag is not None:
            snapshot = self.study_dag.snapshot(
                self.study_dag.node_id_for_index(study_index)
            )
            node = snapshot.node
            stage = (
                f"Adaptive DAG node '{node.title}' ({node.node_id}), mode "
                f"{node.mode}. Decision question: {node.decision_question} "
                "Success criteria: "
                + "; ".join(node.success_criteria)
                + ". Explicit failure signals: "
                + "; ".join(node.failure_signals)
                + ". Rank only this declared decision while preserving visible "
                "parent achievements."
            )
        else:
            stage = {
            1: (
                "This is the signature macro-form study. Rank silhouette, pose, "
                "major mass proportions, carved negative spaces, hooked/bent/"
                "twisted form language, and continuity of the root anatomy. "
                "Ignore readiness for later decoration and do not reward extra "
                "appendages merely because they are present."
            ),
            2: (
                "This is the parent-attached subsystem study. Preserve the "
                "strong macro form while ranking whether the new shell, branch, "
                "layer, appendage, or major secondary structure grows from the "
                "parent geometry, follows its frame and curvature, and creates "
                "the reference's overlap and boundary relationships."
            ),
            3: (
                "This is the surface treatment and art-direction study. Preserve "
                "the selected hierarchy while ranking whether local units, "
                "material, color, and lighting conform to the real parent "
                "surface; vary coherently; overlap at useful scale; and retain "
                "the reference's emotional focal hierarchy without becoming a "
                "flat grid, texture stamp, finger field, or armor sheet."
            ),
            }.get(
                study_index,
                (
                    "Rank the candidates by reference fidelity and by whether the "
                    "new subsystem belongs to the already selected hierarchy."
                ),
            )
        return common + " " + stage

    def _build_selector_sheet(
        self,
        study_index: int,
        candidates: list[dict[str, Any]],
    ) -> tuple[Path, dict[str, dict[str, Any]]]:
        """Build a deterministically shuffled, opaque candidate contact sheet."""
        ordered = sorted(
            candidates,
            key=lambda item: hashlib.sha256(
                (
                    f"shaderbench-v8-selector:{study_index}:"
                    f"{item['render_call']}:{item['variant']}"
                ).encode("utf-8")
            ).hexdigest(),
        )
        candidate_map: dict[str, dict[str, Any]] = {}
        cell_width = 360
        image_height = 520
        label_height = 40
        columns = 3
        rows = math.ceil(len(ordered) / columns)
        sheet = PILImage.new(
            "RGB",
            (cell_width * columns, (image_height + label_height) * rows),
            (13, 17, 23),
        )
        draw = ImageDraw.Draw(sheet)
        for index, candidate in enumerate(ordered):
            candidate_id = f"candidate_{index + 1:02d}"
            candidate_map[candidate_id] = {
                key: str(value) if isinstance(value, Path) else value
                for key, value in candidate.items()
            }
            crop = _crop_atlas_cell(
                Path(candidate["atlas_path"]),
                str(candidate["variant"]),
            )
            crop.thumbnail((cell_width - 8, image_height - 8))
            column = index % columns
            row = index // columns
            x = column * cell_width + (cell_width - crop.width) // 2
            y0 = row * (image_height + label_height)
            y = y0 + label_height + (image_height - crop.height) // 2
            sheet.paste(crop, (x, y))
            draw.text(
                (column * cell_width + 12, y0 + 10),
                candidate_id,
                fill=(235, 240, 248),
            )
        sheet_path = (
            self.workspace
            / "selectors"
            / f"study_{study_index:02d}_candidates.png"
        )
        sheet.save(sheet_path)
        return sheet_path, candidate_map

    def _run_selector_cli(
        self,
        study_index: int,
        sheet_path: Path,
        candidate_ids: list[str],
    ) -> dict[str, Any]:
        """Run a fresh, read-only visual selector with no generator context."""
        assert self.reference_image is not None
        with tempfile.TemporaryDirectory(
            prefix=f"shader_selector_{study_index:02d}_"
        ) as temporary:
            selector_workspace = Path(temporary)
            reference = selector_workspace / "reference.png"
            sheet = selector_workspace / "candidates.png"
            last_message = selector_workspace / "last_message.txt"
            shutil.copy2(self.reference_image, reference)
            shutil.copy2(sheet_path, sheet)
            prompt = f"""\
You are an isolated visual selector for a procedural reconstruction benchmark.
The first attached image is the reference. The second is a blinded contact sheet
whose labels are opaque candidate IDs. Rank every candidate exactly once.

SELECTION RUBRIC
{self._selector_rubric(study_index)}

Return ONLY this JSON schema:
{{
  "ranking": {json.dumps(candidate_ids)},
  "winner": "{candidate_ids[0]}",
  "evidence": "specific visible comparison against the reference",
  "runner_up_tradeoff": "specific reason the runner-up loses"
}}

Replace the example ordering and winner with your actual judgment. The ranking
must contain each supplied ID exactly once. Do not infer pass order, code,
future composability, or treatment names; you do not have that information.
"""
            command = [
                "codex",
                "exec",
                "--ephemeral",
                "--ignore-user-config",
                "--ignore-rules",
                "--sandbox",
                "read-only",
                "--skip-git-repo-check",
                "--cd",
                str(selector_workspace),
                "--json",
                "--output-last-message",
                str(last_message),
                "--model",
                self.selector_model,
                "--image",
                str(reference),
                "--image",
                str(sheet),
            ]
            if self.selector_effort:
                command.extend(
                    [
                        "--config",
                        "reasoning_effort="
                        + json.dumps(self.selector_effort),
                    ]
                )
            command.append("-")
            environment = os.environ.copy()
            for key in (
                "CLAUDECODE",
                "CLAUDECODE_SESSION_ID",
                "ANTHROPIC_API_KEY",
                "OPENAI_API_KEY",
                "GEMINI_API_KEY",
                "GOOGLE_API_KEY",
            ):
                environment.pop(key, None)
            completed = subprocess.run(
                command,
                input=prompt,
                capture_output=True,
                text=True,
                timeout=240,
                env=environment,
                cwd=selector_workspace,
            )
            selector_log = (
                self.workspace
                / "selectors"
                / f"study_{study_index:02d}_selector.jsonl"
            )
            _atomic_write(selector_log, completed.stdout or "")
            _atomic_write(
                self.workspace
                / "selectors"
                / f"study_{study_index:02d}_selector.stderr.txt",
                completed.stderr or "",
            )
            if completed.returncode != 0 or not last_message.exists():
                raise RuntimeError(
                    "isolated selector failed: "
                    + (completed.stderr or completed.stdout or "no response")[
                        -2_000:
                    ]
                )
            return _parse_selector_output(
                last_message.read_text(encoding="utf-8")
            )

    def rank_study(
        self,
        study_index: int,
    ) -> tuple[dict[str, Any], Path | None]:
        """Blindly rank every qualified cell without generator self-selection."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }, None
        if self.graph_enabled:
            try:
                graph = self._require_study_dag()
                node_id = graph.node_id_for_index(study_index)
                snapshot = graph.snapshot(node_id)
                if snapshot.status != "studied":
                    raise StudyDAGError(
                        "rank only after every required qualified node pass"
                    )
                required_passes = snapshot.required_passes
            except StudyDAGError as error:
                return {"ok": False, "error": str(error)}, None
        else:
            if not 1 <= study_index <= self.required_studies:
                return {
                    "ok": False,
                    "error": (
                        "study_index must identify one of the required studies "
                        f"(1-{self.required_studies})."
                    ),
                }, None
            node_id = None
            required_passes = self.min_successful_study_renders
        if study_index in self.study_records:
            return {
                "ok": False,
                "error": "This study is already recorded and immutable.",
            }, None
        if study_index in self.study_rankings:
            existing = self.study_rankings[study_index]
            return {"ok": True, **existing, "cached": True}, Path(
                existing["candidate_sheet"]
            )
        candidates = self.qualified_study_candidates.get(study_index, [])
        successful_passes = self.successful_study_render_count.get(
            study_index, 0
        )
        if (
            successful_passes < required_passes
            or not candidates
        ):
            return {
                "ok": False,
                "error": (
                    "Complete every required qualified study pass before "
                    "requesting independent selection."
                ),
                "successful_study_renders": successful_passes,
                "min_successful_study_renders": required_passes,
            }, None
        sheet_path, candidate_map = self._build_selector_sheet(
            study_index, candidates
        )
        candidate_ids = list(candidate_map)
        try:
            raw_result = (
                self.selector_runner(
                    study_index=study_index,
                    reference_path=self.reference_image,
                    candidate_sheet_path=sheet_path,
                    candidate_ids=candidate_ids,
                    rubric=self._selector_rubric(study_index),
                )
                if self.selector_runner is not None
                else self._run_selector_cli(
                    study_index,
                    sheet_path,
                    candidate_ids,
                )
            )
            parsed = (
                _parse_selector_output(raw_result)
                if isinstance(raw_result, str)
                else raw_result
            )
            if not isinstance(parsed, dict):
                raise ValueError("selector result must be an object")
            ranking = parsed.get("ranking")
            winner = parsed.get("winner")
            if (
                not isinstance(ranking, list)
                or len(ranking) != len(candidate_ids)
                or len(set(ranking)) != len(candidate_ids)
                or set(ranking) != set(candidate_ids)
            ):
                raise ValueError(
                    "selector ranking must contain every opaque candidate "
                    "exactly once"
                )
            if winner != ranking[0] or winner not in candidate_map:
                raise ValueError(
                    "selector winner must be the first ranked candidate"
                )
            evidence = str(parsed.get("evidence", "")).strip()
            if len(evidence) < 40:
                raise ValueError(
                    "selector evidence must contain at least 40 characters"
                )
        except Exception as error:
            result = {
                "ok": False,
                "error": f"independent selector failed closed: {error}",
                "candidate_sheet": str(sheet_path),
            }
            self._event("rank_study_failed", **result)
            return result, sheet_path
        winner_origin = candidate_map[str(winner)]
        record = {
            "study_index": study_index,
            "node_id": node_id,
            "selector_model": self.selector_model,
            "selector_effort": self.selector_effort,
            "rubric": self._selector_rubric(study_index),
            "rubric_sha256": hashlib.sha256(
                self._selector_rubric(study_index).encode("utf-8")
            ).hexdigest(),
            "candidate_sheet": str(sheet_path),
            "candidate_map": candidate_map,
            "ranking": ranking,
            "winner": winner,
            "winner_origin": winner_origin,
            "evidence": evidence,
            "runner_up_tradeoff": str(
                parsed.get("runner_up_tradeoff", "")
            ).strip()[:2_000],
        }
        self.study_rankings[study_index] = record
        result = {"ok": True, **record, "cached": False}
        self._event("rank_study", **result)
        return result, sheet_path

    def write_shader(
        self,
        shader_source: str,
        revision_critique: str = "",
    ) -> dict[str, Any]:
        """Replace the one permitted shader file with a complete WGSL program."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        shader_source, injected_artifacts, injection_errors = (
            self._expand_locked_artifact_injections(shader_source)
        )
        if injection_errors:
            return {
                "ok": False,
                "error": "Artifact injection placeholders are invalid.",
                "artifact_injection_errors": injection_errors,
            }
        encoded = shader_source.encode("utf-8")
        if not shader_source.strip():
            return {"ok": False, "error": "shader_source cannot be empty"}
        if len(encoded) > MAX_SHADER_BYTES:
            return {
                "ok": False,
                "error": f"shader exceeds the {MAX_SHADER_BYTES}-byte limit",
            }
        locked_errors = self._locked_artifact_errors(shader_source)
        if locked_errors:
            return {
                "ok": False,
                "error": (
                    "The rewrite would lose, alter, or stop calling a selected "
                    "executable study artifact."
                ),
                "artifact_lineage_errors": locked_errors,
            }
        if self.revision >= 1 and len(revision_critique.strip()) < 40:
            return {
                "ok": False,
                "error": (
                    "A rewrite after revision 1 requires a concrete "
                    "revision_critique of at least 40 characters comparing "
                    "the rendered image with the target."
                ),
            }

        self.revision += 1
        self.current_hash = hashlib.sha256(encoded).hexdigest()
        _atomic_write(self.shader_path, shader_source)
        revision_path = (
            self.workspace / "renders" / f"revision_{self.revision:02d}.wgsl"
        )
        shutil.copy2(self.shader_path, revision_path)
        result = {
            "ok": True,
            "revision": self.revision,
            "sha256": self.current_hash,
            "bytes": len(encoded),
            "remaining_renders": self.render_budget - self.render_calls,
            "revision_critique": revision_critique.strip()[:4_000],
            "injected_artifacts": injected_artifacts,
        }
        self._event("write_shader", **result)
        return result

    def render_shader(
        self,
        stage: str = "final",
        study_index: int = 0,
        variation_manifest: str = "",
    ) -> tuple[dict[str, Any], Path | None]:
        """Render the current revision and return metadata plus its image path."""
        if stage not in {"study", "promotion", "final"}:
            result = {
                "ok": False,
                "error": (
                    "stage must be 'study', 'promotion', or 'final'."
                ),
            }
            self._event("render_rejected", **result)
            return result, None
        graph_node_id: str | None = None
        if stage == "study":
            if self.graph_enabled:
                try:
                    graph = self._require_study_dag()
                    graph_node_id = graph.node_id_for_index(study_index)
                    graph_snapshot = graph.snapshot(graph_node_id)
                    if graph_snapshot.status != "active":
                        raise StudyDAGError(
                            "call begin_study_node for a ready node before rendering"
                        )
                except StudyDAGError as error:
                    result = {"ok": False, "error": str(error)}
                    self._event("render_rejected", **result)
                    return result, None
            else:
                graph = None
                graph_node_id = None
                if not 1 <= study_index <= self.required_studies:
                    result = {
                        "ok": False,
                        "error": (
                            "study_index must identify one of the required "
                            f"studies (1-{self.required_studies})."
                        ),
                    }
                    self._event("render_rejected", **result)
                    return result, None
            if self.require_artifact_blocks and study_index in self.study_records:
                result = {
                    "ok": False,
                    "error": (
                        "This study already has an immutable selected artifact; "
                        "later same-study renders cannot erase or supersede it."
                    ),
                }
                self._event("render_rejected", **result)
                return result, None
            missing_prior = (
                [
                    graph.study_index(dependency)
                    for dependency in graph_snapshot.node.depends_on
                    if graph.snapshot(dependency).status != "promoted"
                ]
                if self.graph_enabled and graph is not None
                else [
                    index
                    for index in range(1, study_index)
                    if index
                    not in (
                        self.promotion_records
                        if self.require_study_promotions
                        else self.study_records
                    )
                ]
            )
            if missing_prior:
                result = {
                    "ok": False,
                    "error": (
                        (
                            "Promote each earlier study before rendering this "
                            "one, so later studies operate on the exact selected "
                            "implementation."
                        )
                        if self.require_study_promotions
                        else (
                            "Record each earlier study before rendering this "
                            "one, so later studies can reuse the selected "
                            "construction."
                        )
                    ),
                    "missing_prior_studies": missing_prior,
                }
                self._event("render_rejected", **result)
                return result, None
            if self.require_study_diversity:
                manifest = variation_manifest.strip()
                missing_variants = [
                    label
                    for label in ("A:", "B:", "C:", "D:", "E:", "F:")
                    if label not in manifest.upper()
                ]
                if len(manifest) < 180 or missing_variants:
                    result = {
                        "ok": False,
                        "error": (
                            "variation_manifest must predeclare materially "
                            "different A: through F: constructions in at least "
                            "180 characters before this study render."
                        ),
                        "missing_variant_labels": missing_variants,
                        "render_budget_consumed": False,
                    }
                    self._event("render_rejected", **result)
                    return result, None
                if self.min_successful_study_renders >= 3:
                    structural_errors = _structural_manifest_errors(manifest)
                    if structural_errors:
                        result = {
                            "ok": False,
                            "error": (
                                "This wide-search study requires an auditable "
                                "A-F structural manifest. Every variant needs "
                                "family=, construction=, and "
                                "structural_difference= fields."
                            ),
                            "structural_manifest_errors": structural_errors,
                            "render_budget_consumed": False,
                        }
                        self._event("render_rejected", **result)
                        return result, None
        elif stage == "promotion":
            if self.graph_enabled:
                try:
                    graph = self._require_study_dag()
                    graph_node_id = graph.node_id_for_index(study_index)
                    graph_snapshot = graph.snapshot(graph_node_id)
                    if graph_snapshot.status != "selected":
                        raise StudyDAGError(
                            "record the selected node artifact before promotion"
                        )
                except StudyDAGError as error:
                    result = {"ok": False, "error": str(error)}
                    self._event("render_rejected", **result)
                    return result, None
            else:
                graph = None
                graph_node_id = None
                if not 1 <= study_index <= self.required_studies:
                    result = {
                        "ok": False,
                        "error": (
                            "promotion study_index must identify one of the "
                            f"required studies (1-{self.required_studies})."
                        ),
                    }
                    self._event("render_rejected", **result)
                    return result, None
            if study_index not in self.study_records:
                result = {
                    "ok": False,
                    "error": (
                        "Record the independently selected study artifact "
                        "before rendering its full-frame promotion."
                    ),
                }
                self._event("render_rejected", **result)
                return result, None
            if study_index in self.promotion_records:
                result = {
                    "ok": False,
                    "error": "This study promotion is already immutable.",
                }
                self._event("render_rejected", **result)
                return result, None
            missing_prior = (
                [
                    graph.study_index(dependency)
                    for dependency in graph_snapshot.node.depends_on
                    if graph.snapshot(dependency).status != "promoted"
                ]
                if self.graph_enabled and graph is not None
                else [
                    index
                    for index in range(1, study_index)
                    if index not in self.promotion_records
                ]
            )
            if missing_prior:
                result = {
                    "ok": False,
                    "error": (
                        "Promote every earlier selected artifact before this "
                        "full-frame promotion."
                    ),
                    "missing_prior_promotions": missing_prior,
                }
                self._event("render_rejected", **result)
                return result, None
        elif study_index != 0:
            result = {
                "ok": False,
                "error": "study_index must be 0 for a final render.",
            }
            self._event("render_rejected", **result)
            return result, None
        if stage == "final" and self.graph_enabled:
            try:
                graph = self._require_study_dag()
                if not graph.graph_closed:
                    raise StudyDAGError(
                        "close the all-promoted study graph before final renders"
                    )
            except StudyDAGError as error:
                result = {"ok": False, "error": str(error)}
                self._event("render_rejected", **result)
                return result, None
        if (
            stage == "final"
            and not self.graph_enabled
            and self.require_study_promotions
            and len(self.promotion_records) < self.required_studies
        ):
            result = {
                "ok": False,
                "error": (
                    "Promote every exact selected artifact in full-frame "
                    "context before rendering the final reconstruction."
                ),
                "completed_promotions": sorted(self.promotion_records),
                "required_studies": self.required_studies,
            }
            self._event("render_rejected", **result)
            return result, None
        if (
            stage == "final"
            and not self.graph_enabled
            and len(self.study_records) < self.required_studies
        ):
            result = {
                "ok": False,
                "error": (
                    "Complete and record every required visual study before "
                    "rendering the final reconstruction."
                ),
                "completed_studies": sorted(self.study_records),
                "required_studies": self.required_studies,
            }
            self._event("render_rejected", **result)
            return result, None
        if self.submitted:
            result = {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
            self._event("render_rejected", **result)
            return result, None
        if self.render_calls >= self.render_budget:
            result = {
                "ok": False,
                "error": "Render budget exhausted.",
                "render_budget": self.render_budget,
                "render_calls": self.render_calls,
            }
            self._event("render_rejected", **result)
            return result, None
        if not self.shader_path.exists():
            result = {
                "ok": False,
                "error": "No shader exists. Call write_shader first.",
            }
            self._event("render_rejected", **result)
            return result, None
        shader_source = self.shader_path.read_text(encoding="utf-8")
        if stage == "study" and self.require_artifact_blocks:
            strict_dependencies = (
                self.protocol == "persistent-agent-render-tools-v9"
            )
            parent_entries: set[str] = set()
            if strict_dependencies:
                try:
                    parent_entries = self._artifact_parent_entries(study_index)
                except (KeyError, StudyDAGError, ValueError) as error:
                    result = {
                        "ok": False,
                        "error": str(error),
                        "render_budget_consumed": False,
                    }
                    self._event("render_rejected", **result)
                    return result, None
            artifact_errors = _artifact_manifest_errors(
                shader_source,
                study_index,
                allowed_external_entries=parent_entries,
                required_parent_entries=parent_entries,
                enforce_self_contained=strict_dependencies,
            )
            if artifact_errors:
                result = {
                    "ok": False,
                    "error": (
                        "Every A-F cell must expose a unique, called, exact "
                        "artifact block before this study render."
                    ),
                    "artifact_manifest_errors": artifact_errors,
                    "render_budget_consumed": False,
                }
                self._event("render_rejected", **result)
                return result, None
        lineage_errors = self._locked_artifact_errors(shader_source)
        if lineage_errors:
            result = {
                "ok": False,
                "error": (
                    "The current shader fails executable artifact lineage "
                    "validation."
                ),
                "artifact_lineage_errors": lineage_errors,
                "render_budget_consumed": False,
            }
            self._event("render_rejected", **result)
            return result, None
        if stage == "final" and self.current_hash in {
            self.successful_render_hash_by_revision.get(revision)
            for revision, recorded_stage
            in self.successful_render_stage_by_revision.items()
            if recorded_stage == "final"
        }:
            result = {
                "ok": False,
                "error": (
                    "This exact shader hash already has a successful final render. "
                    "Make an evidence-based source revision before spending another "
                    "reserved final call."
                ),
                "render_budget_consumed": False,
                "revision": self.revision,
                "remaining_renders": self.render_budget - self.render_calls,
            }
            self._event("render_rejected", **result)
            return result, None
        if self.revision in self.attempted_revisions:
            result = {
                "ok": False,
                "error": (
                    "This exact revision has already been rendered or attempted. "
                    "Inspect the existing feedback, call write_shader with a "
                    "revised complete program, then render the new revision."
                ),
                "revision": self.revision,
                "remaining_renders": self.render_budget - self.render_calls,
            }
            self._event("render_rejected", **result)
            return result, None

        self.render_calls += 1
        self.attempted_revisions.add(self.revision)
        call_number = self.render_calls
        output_path = (
            self.workspace / "renders" / f"render_{call_number:02d}.png"
        )
        log_path = (
            self.workspace / "renders" / f"render_{call_number:02d}.log"
        )
        shader_snapshot = (
            self.workspace
            / "renders"
            / f"render_{call_number:02d}_revision_{self.revision:02d}.wgsl"
        )
        shutil.copy2(self.shader_path, shader_snapshot)

        command = [
            str(self.renderer),
            "--shader",
            str(self.shader_path),
            "--output",
            str(output_path),
            "--size",
            str(self.render_size),
        ]
        try:
            completed = subprocess.run(
                command,
                cwd=self.workspace,
                capture_output=True,
                text=True,
                timeout=120,
            )
            stdout = completed.stdout or ""
            stderr = completed.stderr or ""
            returncode = completed.returncode
        except subprocess.TimeoutExpired as exc:
            stdout = exc.stdout or ""
            stderr = (exc.stderr or "") + "\nRenderer timed out after 120s."
            returncode = 124

        log_path.write_text(
            "COMMAND\n"
            + " ".join(command)
            + "\n\nSTDOUT\n"
            + stdout
            + "\n\nSTDERR\n"
            + stderr,
            encoding="utf-8",
        )
        success = returncode == 0 and output_path.is_file()
        previous_final_hashes = {
            self.successful_render_hash_by_revision.get(revision)
            for revision, recorded_stage
            in self.successful_render_stage_by_revision.items()
            if recorded_stage == "final"
        }
        previous_final_hashes.discard(None)
        bookkeeping_snapshot = {
            "successful_render_by_revision": copy.deepcopy(
                self.successful_render_by_revision
            ),
            "successful_render_stage_by_revision": copy.deepcopy(
                self.successful_render_stage_by_revision
            ),
            "successful_render_hash_by_revision": copy.deepcopy(
                self.successful_render_hash_by_revision
            ),
            "latest_successful_study_render": copy.deepcopy(
                self.latest_successful_study_render
            ),
            "latest_successful_promotion_render": copy.deepcopy(
                self.latest_successful_promotion_render
            ),
            "successful_study_render_count": copy.deepcopy(
                self.successful_study_render_count
            ),
            "qualified_study_render_paths": copy.deepcopy(
                self.qualified_study_render_paths
            ),
            "qualified_study_candidates": copy.deepcopy(
                self.qualified_study_candidates
            ),
            "study_records": copy.deepcopy(self.study_records),
        }
        graph_checkpoint = (
            self.study_dag.to_dict()
            if self.graph_enabled and self.study_dag is not None
            else None
        )
        if success:
            self.successful_render_by_revision[self.revision] = output_path
            self.successful_render_stage_by_revision[self.revision] = stage
            if self.current_hash is not None:
                self.successful_render_hash_by_revision[
                    self.revision
                ] = self.current_hash
            if stage == "study":
                study_pass = (
                    self.successful_study_render_count.get(study_index, 0) + 1
                )
                study_diversity = _atlas_diversity_metrics(output_path)
                cross_render_diversity = _cross_render_diversity_metrics(
                    output_path,
                    study_index,
                    self.qualified_study_render_paths,
                )
                if self.graph_enabled:
                    same_min = cross_render_diversity.get(
                        "same_study_min_mae_percent"
                    )
                    cross_render_diversity["qualifies"] = (
                        same_min is None
                        or same_min >= STUDY_CROSS_PASS_MAE_MIN
                    )
                    cross_render_diversity[
                        "other_study_gate_applied"
                    ] = False
                study_pass_qualified = (
                    not self.require_study_diversity
                    or (
                        bool(study_diversity["qualifies"])
                        and bool(cross_render_diversity["qualifies"])
                    )
                )
                if study_pass_qualified:
                    self.successful_study_render_count[study_index] = study_pass
                    self.qualified_study_render_paths.setdefault(
                        study_index, []
                    ).append(output_path)
                    self.latest_successful_study_render[study_index] = {
                        "revision": self.revision,
                        "render_call": call_number,
                        "study_pass": study_pass,
                    }
                    self.qualified_study_candidates.setdefault(
                        study_index, []
                    ).extend(
                        {
                            "revision": self.revision,
                            "render_call": call_number,
                            "study_pass": study_pass,
                            "variant": variant,
                            "atlas_path": output_path,
                            "source_path": shader_snapshot,
                            "variation_manifest": (
                                variation_manifest.strip()[:4_000]
                            ),
                        }
                        for variant in VARIANTS
                    )
                    if not self.require_artifact_blocks:
                        self.study_records.pop(study_index, None)
            elif stage == "promotion":
                study_pass = 0
                study_diversity = None
                cross_render_diversity = None
                study_pass_qualified = True
                self.latest_successful_promotion_render[study_index] = {
                    "revision": self.revision,
                    "render_call": call_number,
                }
            else:
                study_pass = 0
                study_diversity = None
                cross_render_diversity = None
                study_pass_qualified = True
        else:
            study_pass = 0
            study_diversity = None
            cross_render_diversity = None
            study_pass_qualified = False

        graph_accounting_error = None
        if self.graph_enabled:
            try:
                graph = self._require_study_dag()
                if stage == "study":
                    graph.record_pass(
                        str(graph_node_id),
                        success=bool(success and study_pass_qualified),
                        render_calls_used=self.render_calls,
                    )
                elif stage == "promotion":
                    graph.sync_render_calls(self.render_calls)
                else:
                    graph.record_final(
                        success=bool(
                            success and self.current_hash not in previous_final_hashes
                        ),
                        render_calls_used=self.render_calls,
                    )
            except StudyDAGError as error:
                graph_accounting_error = str(error)
                if graph_checkpoint is not None:
                    try:
                        self.study_dag = AdaptiveStudyDAG.from_dict(
                            graph_checkpoint
                        )
                        self.study_dag.sync_render_calls(self.render_calls)
                    except StudyDAGError as reconcile_error:
                        graph_accounting_error += (
                            f"; graph reconciliation failed: {reconcile_error}"
                        )
                for name, value in bookkeeping_snapshot.items():
                    setattr(self, name, value)

        result = {
            "ok": bool(success and graph_accounting_error is None),
            "render_call": call_number,
            "render_budget": self.render_budget,
            "remaining_renders": self.render_budget - call_number,
            "revision": self.revision,
            "stage": stage,
            "study_index": study_index,
            "node_id": graph_node_id,
            "study_pass": study_pass,
            "study_pass_qualified": study_pass_qualified,
            "study_diversity": study_diversity,
            "cross_render_diversity": cross_render_diversity,
            "variation_manifest": variation_manifest.strip()[:4_000],
            "sha256": self.current_hash,
            "image": (
                str(output_path)
                if success and graph_accounting_error is None
                else None
            ),
            "log": str(log_path),
            "returncode": returncode,
            "compiler_feedback": (stderr + "\n" + stdout).strip()[-12_000:],
        }
        if self.graph_enabled:
            result["study_graph"] = self._study_graph_snapshot()
            if graph_accounting_error is not None:
                result["graph_accounting_error"] = graph_accounting_error
        self._event("render_shader", **result)
        return (
            result,
            output_path if success and graph_accounting_error is None else None,
        )

    def record_study(
        self,
        study_index: int,
        subject: str,
        selected_variant: str,
        selection_rationale: str,
        handoff_requirements: str,
        variant_inventory: str = "",
        selected_render_call: int = 0,
    ) -> dict[str, Any]:
        """Record and materialize one exact selected atlas implementation."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        if self.require_artifact_blocks and study_index in self.study_records:
            return {
                "ok": False,
                "error": "This study selection is already immutable.",
            }
        if self.graph_enabled:
            try:
                graph = self._require_study_dag()
                node_id = graph.node_id_for_index(study_index)
                node_snapshot = graph.snapshot(node_id)
                if node_snapshot.status != "studied":
                    raise StudyDAGError(
                        "record only after every required node pass and ranking"
                    )
                required_passes = node_snapshot.required_passes
            except StudyDAGError as error:
                return {"ok": False, "error": str(error)}
        else:
            node_id = None
            required_passes = self.min_successful_study_renders
        latest_rendered = self.latest_successful_study_render.get(study_index)
        if latest_rendered is None:
            return {
                "ok": False,
                "error": (
                    "Render this study successfully before recording its "
                    "selection."
                ),
            }
        successful_passes = self.successful_study_render_count.get(
            study_index, 0
        )
        if successful_passes < required_passes:
            return {
                "ok": False,
                "error": (
                    "This study needs more distinct successful render passes "
                    "before selection can be recorded."
                ),
                "successful_study_renders": successful_passes,
                "min_successful_study_renders": required_passes,
            }
        ranking = self.study_rankings.get(study_index)
        if self.require_study_selector and ranking is None:
            return {
                "ok": False,
                "error": (
                    "Call rank_study and accept its blinded winner before "
                    "recording this study."
                ),
            }
        variant = selected_variant.strip().upper()
        if not variant and ranking is not None:
            variant = str(ranking["winner_origin"]["variant"])
        if variant not in set(VARIANTS):
            return {
                "ok": False,
                "error": "selected_variant must be one of A, B, C, D, E, or F.",
            }
        if ranking is not None and self.require_study_selector:
            winner_origin = ranking["winner_origin"]
            expected_variant = str(winner_origin["variant"])
            expected_call = int(winner_origin["render_call"])
            if variant != expected_variant or (
                selected_render_call not in {0, expected_call}
            ):
                return {
                    "ok": False,
                    "error": (
                        "The generator cannot override the enforced blinded "
                        "selector winner."
                    ),
                    "selector_variant": expected_variant,
                    "selector_render_call": expected_call,
                }
            selected_render_call = expected_call
        elif selected_render_call == 0:
            selected_render_call = int(latest_rendered["render_call"])
        selected_candidates = [
            candidate
            for candidate in self.qualified_study_candidates.get(
                study_index, []
            )
            if int(candidate["render_call"]) == selected_render_call
            and str(candidate["variant"]) == variant
        ]
        if not selected_candidates:
            if self.require_artifact_blocks:
                return {
                    "ok": False,
                    "error": (
                        "The selected render/cell is not a qualified immutable "
                        "study candidate."
                    ),
                }
            selected_candidate = {
                **latest_rendered,
                "variant": variant,
                "atlas_path": self.successful_render_by_revision.get(
                    int(latest_rendered["revision"]),
                    self.workspace / "renders" / "unavailable.png",
                ),
                "source_path": (
                    self.workspace
                    / "renders"
                    / f"revision_{int(latest_rendered['revision']):02d}.wgsl"
                ),
                "variation_manifest": "",
            }
        else:
            selected_candidate = selected_candidates[0]
        if len(subject.strip()) < 4:
            return {"ok": False, "error": "subject is too short."}
        if self.require_variant_inventory:
            inventory = variant_inventory.strip()
            missing_variants = [
                label
                for label in ("A:", "B:", "C:", "D:", "E:", "F:")
                if label not in inventory.upper()
            ]
            if len(inventory) < 180 or missing_variants:
                return {
                    "ok": False,
                    "error": (
                        "variant_inventory must describe materially distinct "
                        "A: through F: constructions in at least 180 characters."
                    ),
                    "missing_variant_labels": missing_variants,
                }
        if (
            not self.require_study_selector
            and len(selection_rationale.strip()) < 80
        ):
            return {
                "ok": False,
                "error": (
                    "selection_rationale must contain at least 80 characters "
                    "of visible comparison evidence."
                ),
            }
        if len(handoff_requirements.strip()) < 80:
            return {
                "ok": False,
                "error": (
                    "handoff_requirements must contain at least 80 characters "
                    "naming the reusable code, coordinates, and parameters."
                ),
            }
        artifact_metadata: dict[str, Any] = {}
        if self.require_artifact_blocks:
            source_path = Path(selected_candidate["source_path"])
            atlas_path = Path(selected_candidate["atlas_path"])
            source = source_path.read_text(encoding="utf-8")
            artifact_id = f"study_{study_index}_{variant}"
            try:
                block = _extract_artifact_blocks(source).get(artifact_id)
            except ValueError as error:
                return {"ok": False, "error": str(error)}
            if block is None:
                return {
                    "ok": False,
                    "error": (
                        f"Selected candidate has no exact {artifact_id} block."
                    ),
                }
            strict_dependencies = (
                self.protocol == "persistent-agent-render-tools-v9"
            )
            parent_entries: set[str] = set()
            if strict_dependencies:
                try:
                    parent_entries = self._artifact_parent_entries(study_index)
                except (KeyError, StudyDAGError, ValueError) as error:
                    return {"ok": False, "error": str(error)}
            selected_errors = _artifact_entry_input_errors(block)
            selected_errors.extend(
                _artifact_dependency_errors(
                    source,
                    block,
                    allowed_external_entries=parent_entries,
                    required_parent_entries=parent_entries,
                    enforce_self_contained=strict_dependencies,
                )
            )
            if selected_errors:
                return {
                    "ok": False,
                    "error": "Selected artifact no longer satisfies its live ABI.",
                    "artifact_lineage_errors": selected_errors,
                }
            artifact_dir = self.workspace / "artifacts" / artifact_id
            artifact_dir.mkdir(parents=True, exist_ok=True)
            artifact_source_path = artifact_dir / "artifact.wgsl"
            artifact_crop_path = artifact_dir / "selected.png"
            artifact_atlas_path = artifact_dir / "atlas.png"
            artifact_origin_path = artifact_dir / "atlas.wgsl"
            _atomic_write(artifact_source_path, block["source"])
            _crop_atlas_cell(atlas_path, variant).save(artifact_crop_path)
            shutil.copy2(atlas_path, artifact_atlas_path)
            shutil.copy2(source_path, artifact_origin_path)
            artifact_metadata = {
                "artifact_id": artifact_id,
                "study_index": study_index,
                "variant": variant,
                "entry_symbol": block["entry_symbol"],
                "sha256": block["sha256"],
                "origin_revision": int(selected_candidate["revision"]),
                "origin_render_call": selected_render_call,
                "artifact_source_path": str(artifact_source_path),
                "artifact_crop_path": str(artifact_crop_path),
                "artifact_atlas_path": str(artifact_atlas_path),
                "artifact_origin_shader_path": str(artifact_origin_path),
                "status": "selected_pending_promotion",
            }
            self.locked_artifacts[artifact_id] = {
                **artifact_metadata,
                "source": block["source"],
            }
            _atomic_write(
                artifact_dir / "manifest.json",
                json.dumps(artifact_metadata, indent=2),
            )
        rendered = {
            "revision": int(selected_candidate["revision"]),
            "render_call": selected_render_call,
            "study_pass": int(selected_candidate.get("study_pass", 0)),
        }
        record = {
            "study_index": study_index,
            "node_id": node_id,
            "subject": subject.strip()[:300],
            "selected_variant": variant,
            "variant_inventory": variant_inventory.strip()[:4_000],
            "selection_rationale": (
                str(ranking["evidence"])
                if ranking is not None and self.require_study_selector
                else selection_rationale.strip()
            )[:4_000],
            "generator_self_assessment": selection_rationale.strip()[:4_000],
            "handoff_requirements": handoff_requirements.strip()[:4_000],
            "selected_by": (
                "isolated_blinded_selector"
                if ranking is not None and self.require_study_selector
                else "generator"
            ),
            "selector_winner": (
                ranking["winner"] if ranking is not None else None
            ),
            **artifact_metadata,
            **rendered,
        }
        if self.graph_enabled:
            try:
                self._require_study_dag().select_node(str(node_id))
            except StudyDAGError as error:
                return {"ok": False, "error": str(error)}
        self.study_records[study_index] = record
        result = {
            "ok": True,
            **record,
            "completed_studies": sorted(self.study_records),
            "required_studies": self.required_studies,
        }
        self._event("record_study", **result)
        return result

    def promote_study(
        self,
        study_index: int,
        integration_evidence: str,
    ) -> dict[str, Any]:
        """Freeze evidence that the exact selected artifact works full-frame."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        if self.graph_enabled:
            try:
                graph = self._require_study_dag()
                node_id = graph.node_id_for_index(study_index)
                if graph.snapshot(node_id).status != "selected":
                    raise StudyDAGError(
                        "promote only after this node's winner is recorded"
                    )
            except StudyDAGError as error:
                return {"ok": False, "error": str(error)}
        else:
            node_id = None
        record = self.study_records.get(study_index)
        rendered = self.latest_successful_promotion_render.get(study_index)
        if record is None or rendered is None:
            return {
                "ok": False,
                "error": (
                    "Record the selected artifact, write it into a full-frame "
                    "scene, and render stage='promotion' before promotion."
                ),
            }
        if study_index in self.promotion_records:
            return {
                "ok": False,
                "error": "This study promotion is already immutable.",
            }
        if len(integration_evidence.strip()) < 80:
            return {
                "ok": False,
                "error": (
                    "integration_evidence must contain at least 80 characters "
                    "comparing the promoted full-frame result with the target "
                    "and prior champion."
                ),
            }
        artifact_id = str(record.get("artifact_id", ""))
        if not artifact_id or artifact_id not in self.locked_artifacts:
            return {
                "ok": False,
                "error": "No exact selected artifact is available to promote.",
            }
        artifact_dir = self.workspace / "artifacts" / artifact_id
        promotion_shader = artifact_dir / "promotion.wgsl"
        promotion_render = artifact_dir / "promotion.png"
        revision = int(rendered["revision"])
        render_call = int(rendered["render_call"])
        shutil.copy2(
            self.workspace / "renders" / f"revision_{revision:02d}.wgsl",
            promotion_shader,
        )
        shutil.copy2(
            self.workspace / "renders" / f"render_{render_call:02d}.png",
            promotion_render,
        )
        promoted_status = "promoted_locked"
        promotion = {
            "study_index": study_index,
            "node_id": node_id,
            "artifact_id": artifact_id,
            "revision": revision,
            "render_call": render_call,
            "promotion_shader": str(promotion_shader),
            "promotion_render": str(promotion_render),
            "integration_evidence": integration_evidence.strip()[:4_000],
            "status": promoted_status,
        }
        if self.graph_enabled:
            try:
                graph.promote_node(
                    str(node_id), render_calls_used=self.render_calls
                )
            except StudyDAGError as error:
                return {"ok": False, "error": str(error)}
        self.promotion_records[study_index] = promotion
        record["status"] = promoted_status
        self.locked_artifacts[artifact_id]["status"] = promoted_status
        manifest_path = artifact_dir / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest.update(promotion)
        manifest["status"] = promoted_status
        _atomic_write(manifest_path, json.dumps(manifest, indent=2))
        result = {
            "ok": True,
            **promotion,
            "completed_promotions": sorted(self.promotion_records),
            "required_studies": self.required_studies,
        }
        if self.graph_enabled:
            result["study_graph"] = self._study_graph_snapshot()
        self._event("promote_study", **result)
        return result

    def restore_revision(
        self,
        revision: int,
        reason: str,
    ) -> dict[str, Any]:
        """Create a new head from an immutable historical source revision."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        if len(reason.strip()) < 40:
            return {
                "ok": False,
                "error": "restore reason must contain at least 40 characters",
            }
        source_path = (
            self.workspace / "renders" / f"revision_{revision:02d}.wgsl"
        )
        if not source_path.is_file():
            return {"ok": False, "error": "unknown historical revision"}
        source = source_path.read_text(encoding="utf-8")
        lineage_errors = self._locked_artifact_errors(source)
        if lineage_errors:
            return {
                "ok": False,
                "error": (
                    "That historical revision predates or violates the current "
                    "immutable artifact lineage."
                ),
                "artifact_lineage_errors": lineage_errors,
            }
        self.revision += 1
        encoded = source.encode("utf-8")
        self.current_hash = hashlib.sha256(encoded).hexdigest()
        _atomic_write(self.shader_path, source)
        new_revision_path = (
            self.workspace / "renders" / f"revision_{self.revision:02d}.wgsl"
        )
        shutil.copy2(self.shader_path, new_revision_path)
        result = {
            "ok": True,
            "revision": self.revision,
            "restored_from": revision,
            "sha256": self.current_hash,
            "reason": reason.strip()[:4_000],
            "prior_render_image": (
                str(self.successful_render_by_revision[revision])
                if revision in self.successful_render_by_revision
                else None
            ),
            "remaining_renders": self.render_budget - self.render_calls,
        }
        self._event("restore_revision", **result)
        return result

    def submit_final(
        self,
        summary: str = "",
        revision: int = 0,
    ) -> dict[str, Any]:
        """Freeze any successful final revision, not necessarily the newest."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        if self.graph_enabled:
            try:
                if not self._require_study_dag().graph_closed:
                    raise StudyDAGError(
                        "close the accepted study graph before submission"
                    )
            except StudyDAGError as error:
                return {"ok": False, "error": str(error)}
        submitted_revision = revision or self.revision
        rendered_path = self.successful_render_by_revision.get(
            submitted_revision
        )
        if rendered_path is None:
            result = {
                "ok": False,
                "error": (
                    "The requested shader revision has not rendered "
                    "successfully."
                ),
                "revision": submitted_revision,
                "remaining_renders": self.render_budget - self.render_calls,
            }
            self._event("submit_rejected", **result)
            return result
        if (
            self.successful_render_stage_by_revision.get(submitted_revision)
            != "final"
        ):
            result = {
                "ok": False,
                "error": (
                    "The requested revision is not a final "
                    "reconstruction. Integrate the selected studies and render "
                    "the final stage before submitting."
                ),
            }
            self._event("submit_rejected", **result)
            return result
        if len(self.study_records) < self.required_studies:
            result = {
                "ok": False,
                "error": "Every required study must be recorded before submission.",
                "completed_studies": sorted(self.study_records),
                "required_studies": self.required_studies,
            }
            self._event("submit_rejected", **result)
            return result
        successful_final_hashes = {
            self.successful_render_hash_by_revision.get(candidate_revision)
            for candidate_revision, stage
            in self.successful_render_stage_by_revision.items()
            if stage == "final"
        }
        successful_final_hashes.discard(None)
        successful_final_revisions = len(successful_final_hashes)
        if successful_final_revisions < self.min_successful_revisions:
            result = {
                "ok": False,
                "error": (
                    "More distinct successfully rendered revisions are required "
                    "before submission."
                ),
                "successful_revisions": successful_final_revisions,
                "min_successful_revisions": self.min_successful_revisions,
                "remaining_renders": self.render_budget - self.render_calls,
            }
            self._event("submit_rejected", **result)
            return result

        final_shader = self.workspace / "final_shader.wgsl"
        final_render = self.workspace / "final_render.png"
        submitted_source = (
            self.workspace
            / "renders"
            / f"revision_{submitted_revision:02d}.wgsl"
        )
        shutil.copy2(submitted_source, final_shader)
        shutil.copy2(rendered_path, final_render)
        self.submitted = True
        submitted_hash = self.successful_render_hash_by_revision.get(
            submitted_revision
        )
        result = {
            "ok": True,
            "revision": submitted_revision,
            "head_revision": self.revision,
            "sha256": submitted_hash,
            "render_call": next(
                (
                    event["render_call"]
                    for event in reversed(self.events)
                    if event.get("type") == "render_shader"
                    and event.get("revision") == submitted_revision
                    and event.get("ok")
                ),
                None,
            ),
            "render_calls_used": self.render_calls,
            "render_budget": self.render_budget,
            "final_shader": str(final_shader),
            "final_render": str(final_render),
            "summary": summary[:4_000],
        }
        self._event("submit_final", **result)
        (self.workspace / "submission.json").write_text(
            json.dumps(result, indent=2), encoding="utf-8"
        )
        return result


def _state_from_environment() -> ShaderAgentState:
    required = (
        "SHADER_AGENT_WORKSPACE",
        "SHADER_AGENT_RENDERER",
        "SHADER_AGENT_RENDER_BUDGET",
    )
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise RuntimeError(
            "Missing shader-agent environment variables: " + ", ".join(missing)
        )
    return ShaderAgentState(
        workspace=Path(os.environ["SHADER_AGENT_WORKSPACE"]),
        renderer=Path(os.environ["SHADER_AGENT_RENDERER"]),
        render_budget=int(os.environ["SHADER_AGENT_RENDER_BUDGET"]),
        protocol=os.environ.get(
            "SHADER_AGENT_PROTOCOL", "persistent-agent-render-tools-v8"
        ),
        graph_enabled=(
            os.environ.get("SHADER_AGENT_GRAPH_ENABLED", "0") == "1"
        ),
        min_graph_nodes=int(
            os.environ.get("SHADER_AGENT_MIN_GRAPH_NODES", "3")
        ),
        max_graph_nodes=int(
            os.environ.get("SHADER_AGENT_MAX_GRAPH_NODES", "8")
        ),
        max_graph_depth=int(
            os.environ.get("SHADER_AGENT_MAX_GRAPH_DEPTH", "3")
        ),
        final_render_reserve=int(
            os.environ.get("SHADER_AGENT_FINAL_RENDER_RESERVE", "2")
        ),
        render_size=int(os.environ.get("SHADER_AGENT_RENDER_SIZE", "1024")),
        min_successful_revisions=int(
            os.environ.get("SHADER_AGENT_MIN_SUCCESSFUL_REVISIONS", "1")
        ),
        required_studies=int(
            os.environ.get("SHADER_AGENT_REQUIRED_STUDIES", "0")
        ),
        require_variant_inventory=(
            os.environ.get("SHADER_AGENT_REQUIRE_VARIANT_INVENTORY", "0") == "1"
        ),
        min_successful_study_renders=int(
            os.environ.get(
                "SHADER_AGENT_MIN_SUCCESSFUL_STUDY_RENDERS", "1"
            )
        ),
        require_study_diversity=(
            os.environ.get("SHADER_AGENT_REQUIRE_STUDY_DIVERSITY", "0") == "1"
        ),
        require_artifact_blocks=(
            os.environ.get("SHADER_AGENT_REQUIRE_ARTIFACT_BLOCKS", "0") == "1"
        ),
        require_study_selector=(
            os.environ.get("SHADER_AGENT_REQUIRE_STUDY_SELECTOR", "0") == "1"
        ),
        require_study_promotions=(
            os.environ.get("SHADER_AGENT_REQUIRE_STUDY_PROMOTIONS", "0") == "1"
        ),
        reference_image=(
            Path(os.environ["SHADER_AGENT_REFERENCE_IMAGE"])
            if os.environ.get("SHADER_AGENT_REFERENCE_IMAGE")
            else None
        ),
        selector_model=os.environ.get(
            "SHADER_AGENT_SELECTOR_MODEL", "gpt-5.5"
        ),
        selector_effort=os.environ.get(
            "SHADER_AGENT_SELECTOR_EFFORT", "high"
        ),
        resume_existing=(
            os.environ.get("SHADER_AGENT_RESUME_EXISTING", "0") == "1"
        ),
    )


def create_mcp(state: ShaderAgentState) -> FastMCP:
    """Bind the fixed workspace state to the bounded MCP surface."""
    server = FastMCP(
        "shader-render-tools",
        instructions=(
            "Work only through the bounded shader tools. "
            "Every render consumes one unit of the fixed budget, including "
            "compile failures. Inspect each returned image before revising. "
            "When required, variation_manifest must predeclare materially "
            "different A-F constructions before a study render. "
            "Three-pass wide-search studies require family=, construction=, "
            "and structural_difference= for every A-F entry. "
            "When study_pass_qualified is false, the atlas was too visually "
            "similar internally or recycled a prior pass/topic, so it must be "
            "revised despite compiling. "
            "When artifact lineage is enabled, call rank_study after all "
            "qualified passes, record its enforced winner, render that exact "
            "artifact full-frame with stage='promotion', and call "
            "promote_study before the next study. Marker blocks are immutable "
            "and must remain byte-identical and called. A single top-level "
            "'// @shaderbench-inject id=study_N_X' placeholder lets "
            "write_shader inject exact locked source. "
            "When adaptive graph mode is enabled, define the bounded DAG "
            "before writing shader code, begin only ready nodes, evaluate "
            "every promoted node from visible render evidence, and expand "
            "only through the evidence-gated graph tool. Independent ready "
            "siblings may be studied in either order. Close the graph only "
            "after every node is promoted and accepted and the unique sink "
            "integrates all branches. "
            "submit_final may select an earlier successful final revision when "
            "the newest one regresses."
        ),
    )

    @server.tool()
    def write_shader(
        shader_source: str,
        revision_critique: str = "",
    ) -> str:
        """Write complete WGSL; rewrites require a target/render critique."""
        return json.dumps(
            state.write_shader(shader_source, revision_critique), indent=2
        )

    @server.tool(structured_output=False)
    def render_shader(
        stage: str = "final",
        study_index: int = 0,
        variation_manifest: str = "",
    ) -> CallToolResult:
        """Render the current shader. Return compiler feedback and the image."""
        result, image_path = state.render_shader(
            stage, study_index, variation_manifest
        )
        content: list[Any] = [
            TextContent(type="text", text=json.dumps(result, indent=2))
        ]
        if image_path is not None:
            content.append(Image(path=image_path).to_image_content())
        return CallToolResult(content=content, isError=False)

    @server.tool(structured_output=False)
    def rank_study(study_index: int) -> CallToolResult:
        """Blindly rank all qualified A-F cells with an isolated selector."""
        result, sheet_path = state.rank_study(study_index)
        content: list[Any] = [
            TextContent(type="text", text=json.dumps(result, indent=2))
        ]
        if sheet_path is not None:
            content.append(Image(path=sheet_path).to_image_content())
        return CallToolResult(content=content, isError=False)

    @server.tool()
    def record_study(
        study_index: int,
        subject: str,
        selected_variant: str,
        selection_rationale: str,
        handoff_requirements: str,
        variant_inventory: str = "",
        selected_render_call: int = 0,
    ) -> str:
        """Materialize the selected cell and exact executable artifact."""
        return json.dumps(
            state.record_study(
                study_index,
                subject,
                selected_variant,
                selection_rationale,
                handoff_requirements,
                variant_inventory,
                selected_render_call,
            ),
            indent=2,
        )

    @server.tool()
    def promote_study(study_index: int, integration_evidence: str) -> str:
        """Freeze a selected artifact after its full-frame promotion render."""
        return json.dumps(
            state.promote_study(study_index, integration_evidence),
            indent=2,
        )

    @server.tool()
    def define_study_graph(graph_json: str, rationale: str) -> str:
        """Atomically define the bounded initial dependency graph as JSON."""
        return json.dumps(
            state.define_study_graph(graph_json, rationale), indent=2
        )

    @server.tool()
    def inspect_study_graph() -> str:
        """Return node states, stable indexes, frontier, and render budget."""
        return json.dumps(state.inspect_study_graph(), indent=2)

    @server.tool()
    def begin_study_node(node_id: str) -> str:
        """Activate a ready node and return its stable numeric study index."""
        return json.dumps(state.begin_study_node(node_id), indent=2)

    @server.tool()
    def evaluate_study_node(
        node_id: str,
        decision: str,
        visible_evidence: str,
        failed_criteria_json: str,
        residuals_json: str,
        expected_information_gain: float,
    ) -> str:
        """Record public accept/expand evidence after node promotion."""
        return json.dumps(
            state.evaluate_study_node(
                node_id,
                decision,
                visible_evidence,
                failed_criteria_json,
                residuals_json,
                expected_information_gain,
            ),
            indent=2,
        )

    @server.tool()
    def expand_study_graph(
        source_node_id: str,
        graph_json: str,
        visible_evidence: str,
        failed_criteria_json: str,
        expected_information_gain: float,
    ) -> str:
        """Append evidence-backed descendant nodes without rewriting history."""
        return json.dumps(
            state.expand_study_graph(
                source_node_id,
                graph_json,
                visible_evidence,
                failed_criteria_json,
                expected_information_gain,
            ),
            indent=2,
        )

    @server.tool()
    def close_study_graph(evidence: str) -> str:
        """Freeze an all-promoted, all-accepted graph with one integrate sink."""
        return json.dumps(state.close_study_graph(evidence), indent=2)

    @server.tool()
    def restore_revision(revision: int, reason: str) -> str:
        """Branch the current head from exact historical shader source."""
        return json.dumps(
            state.restore_revision(revision, reason),
            indent=2,
        )

    @server.tool()
    def submit_final(summary: str = "", revision: int = 0) -> str:
        """Submit any exact successfully rendered final revision."""
        return json.dumps(state.submit_final(summary, revision), indent=2)

    return server


if __name__ == "__main__":
    create_mcp(_state_from_environment()).run(transport="stdio")
