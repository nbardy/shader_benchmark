"""
Shader runtime registry — decouples language (prompt syntax) from runtime
(rendering backend).

Until 2026-04 these were 1:1 inside `test_runner.py:render_shader()`:
ShadertoySpec → headless-browser/WebGL, everything else → Rust+WGPU. This
file adds an explicit slot so a CLI flag can pick the renderer independently
of the language the prompt asks for.

Currently shipped runtimes:
  - wgpu       : Rust `shader_harness/` binary, GPU-rendered. Default for WGSL.
  - shadertoy  : Playwright/WebGL via `shadertoy_runtime.py`. Default for GLSL
                 in Shadertoy mode.

Each runtime delegates back to the existing TestRunner methods so we don't
duplicate the rendering logic — this is a slot, not a rewrite. New runtimes
should add a class and an entry in SUPPORTED_RUNTIMES.
"""

from abc import ABC, abstractmethod
from pathlib import Path
from typing import Tuple, Optional

from language_specs import ShaderLanguageSpec, ShadertoySpec


class ShaderRuntime(ABC):
    """Base class for a shader rendering backend."""

    name: str = ""
    file_extensions: Tuple[str, ...] = ()

    @abstractmethod
    async def prepare(self, test_runner) -> None:
        """One-time setup before any render. Called once per benchmark run.

        WGPU compiles the Rust binary here; Shadertoy is a no-op.
        """

    @abstractmethod
    async def render(self, test_runner, test_folder: Path) -> Path:
        """Render the shader in `test_folder/shaders/` and return the result PNG path."""


class WGPURuntime(ShaderRuntime):
    name = "wgpu"
    file_extensions = (".wgsl",)

    async def prepare(self, test_runner) -> None:
        await test_runner.prebuild_shader_binary()

    async def render(self, test_runner, test_folder: Path) -> Path:
        return await test_runner.render_shader_wgpu(test_folder)


class ShadertoyRuntime(ShaderRuntime):
    name = "shadertoy"
    file_extensions = (".glsl",)

    async def prepare(self, test_runner) -> None:
        # No precompile step; Playwright is loaded lazily inside the render path.
        return None

    async def render(self, test_runner, test_folder: Path) -> Path:
        return await test_runner.render_shader_shadertoy(test_folder)


SUPPORTED_RUNTIMES = {
    "wgpu": WGPURuntime,
    "shadertoy": ShadertoyRuntime,
}


def get_runtime(name: str) -> ShaderRuntime:
    cls = SUPPORTED_RUNTIMES.get(name)
    if cls is None:
        raise ValueError(
            f"Unknown runtime '{name}'. Supported: {sorted(SUPPORTED_RUNTIMES)}"
        )
    return cls()


def default_runtime_for_language(language_spec: Optional[ShaderLanguageSpec]) -> ShaderRuntime:
    """Pick the sensible runtime when --runtime is not specified.

    Preserves prior behaviour: ShadertoySpec → shadertoy, everything else → wgpu.
    """
    if isinstance(language_spec, ShadertoySpec):
        return get_runtime("shadertoy")
    return get_runtime("wgpu")
