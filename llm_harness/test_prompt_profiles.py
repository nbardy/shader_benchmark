import unittest

from prompt_profiles import (
    BASELINE_PROFILE,
    CHATGPT_SHADER_HARNESS_PROFILE,
    AMBITIOUS_3D_PROFILE,
    DOMAIN_EXPERT_PROFILE,
    DOMAIN_EXPERT_V2_PROFILE,
    DOMAIN_EXPERT_V3_PROFILE,
    DOMAIN_EXPERT_V4_PROFILE,
    DOMAIN_EXPERT_V5_PROFILE,
    SCRATCHPAD_ART_DIRECTION_PROFILE,
    SCRATCHPAD_ART_DIRECTION_AMBITIOUS_3D_PROFILE,
    SCRATCHPAD_PROFILE,
    apply_prompt_profile,
)


class PromptProfileTests(unittest.TestCase):
    def test_baseline_is_byte_for_byte_unchanged(self):
        prompt = "BASE PROMPT\n"
        self.assertEqual(apply_prompt_profile(prompt, BASELINE_PROFILE), prompt)

    def test_chatgpt_profile_has_auditable_plan_before_shader(self):
        result = apply_prompt_profile(
            "BASE PROMPT", CHATGPT_SHADER_HARNESS_PROFILE
        )
        profile_text = result[result.index("EXPERIMENTAL PROFILE") :]

        self.assertIn("<scratchpad>", profile_text)
        self.assertIn("</scratchpad>", profile_text)
        self.assertIn('<shader file="shader.wgsl">', profile_text)
        self.assertLess(
            profile_text.index("<scratchpad>"),
            profile_text.index('<shader file="shader.wgsl">'),
        )
        self.assertNotIn("\n<think>\n", profile_text)

    def test_chatgpt_profile_requires_real_representation_choice(self):
        result = apply_prompt_profile(
            "BASE PROMPT", CHATGPT_SHADER_HARNESS_PROFILE
        )
        for required in (
            "2D construction",
            "layered 2.5D",
            "ray-marched 3D SDFs",
            "smooth union",
            "fBm",
            "domain warping",
            "perspective camera",
            "art direction",
        ):
            self.assertIn(required, result)
        self.assertIn("analytic ray", result)
        self.assertIn("intersections", result)

    def test_scratchpad_arm_has_no_separate_art_direction_block(self):
        result = apply_prompt_profile("BASE", SCRATCHPAD_PROFILE)
        self.assertIn("<scratchpad>", result)
        self.assertNotIn("<artistic_subtleties_and_elegance>", result)
        self.assertLess(
            result.index("<scratchpad>"),
            result.index('<shader file="shader.wgsl">'),
        )

    def test_art_direction_arm_orders_all_three_elements(self):
        result = apply_prompt_profile(
            "BASE", SCRATCHPAD_ART_DIRECTION_PROFILE
        )
        art = result.index("<artistic_subtleties_and_elegance>")
        scratchpad = result.index("<scratchpad>")
        shader = result.index('<shader file="shader.wgsl">')
        self.assertLess(art, scratchpad)
        self.assertLess(scratchpad, shader)

        for required in (
            "emotionally legible",
            "uncanny",
            "controlled imperfection",
            "correlated randomness",
            "hierarchical scale variation",
            "clusters and sparse exceptions",
            "domain warping",
            "Randomness alone is not realism",
        ):
            self.assertIn(required, result)

    def test_ambitious_3d_profile_requires_real_depth(self):
        result = apply_prompt_profile("BASE", AMBITIOUS_3D_PROFILE)
        for required in (
            "true 3D is the default",
            "perspective or deliberately justified orthographic camera ray",
            "genuine 3D geometry",
            "normals derived from the 3D field",
            "real occlusion",
            "Do not collapse back to 2.5D",
            "bounded performance budget",
        ):
            self.assertIn(required, result)
        self.assertIn("<scratchpad>", result)
        self.assertLess(
            result.index("<scratchpad>"),
            result.index('<shader file="shader.wgsl">'),
        )

    def test_combined_profile_orders_art_then_3d_plan_then_shader(self):
        result = apply_prompt_profile(
            "BASE", SCRATCHPAD_ART_DIRECTION_AMBITIOUS_3D_PROFILE
        )
        art = result.index("<artistic_subtleties_and_elegance>")
        scratchpad = result.index("<scratchpad>")
        shader = result.index('<shader file="shader.wgsl">')
        self.assertLess(art, scratchpad)
        self.assertLess(scratchpad, shader)
        for required in (
            "controlled imperfection",
            "true 3D is the default",
            "genuine 3D geometry",
            "Do not collapse back to 2.5D",
            "bounded budget for",
        ):
            self.assertIn(required, result)

    def test_domain_expert_profile_turns_critiques_into_observable_contract(self):
        result = apply_prompt_profile("BASE", DOMAIN_EXPERT_PROFILE)
        art = result.index("<artistic_subtleties_and_elegance>")
        scratchpad = result.index("<scratchpad>")
        shader = result.index('<shader file="shader.wgsl">')
        self.assertLess(art, scratchpad)
        self.assertLess(scratchpad, shader)
        self.assertNotIn("\n<think>\n", result)
        normalized = " ".join(result.split())

        for required in (
            "floor/fract",
            "repeat actual 3D or analytic objects",
            "Search neighboring cells",
            "clusters and clearings",
            "palette ladder",
            "color-theory comments",
            "albedo plus roughness",
            "view-dependent Fresnel",
            "A flat shiny primitive",
            "bounding planes",
            "Do not merely restate this directive",
        ):
            self.assertIn(required, normalized)

    def test_domain_expert_v2_is_lean_and_has_a_verifiable_3d_gate(self):
        result = apply_prompt_profile("BASE", DOMAIN_EXPERT_V2_PROFILE)
        normalized = " ".join(result.split())
        self.assertIn("<scratchpad>", result)
        self.assertNotIn("<artistic_subtleties_and_elegance>", result)
        self.assertLess(
            result.index("<scratchpad>"),
            result.index('<shader file="shader.wgsl">'),
        )
        for required in (
            "LEAN 3D GATE",
            "perspective 3D camera ray",
            "mapScene(vec3)",
            "normals derived from those 3D surfaces",
            "feather groups evaluated in object/world coordinates",
            "MUST NOT construct the bird",
            "Hierarchical bounds",
            "Structured variation",
            "Unified surfaces",
            "remove microdetail and keep the 3D architecture",
        ):
            self.assertIn(required, normalized)

    def test_domain_expert_v3_replaces_regular_parts_with_surface_flow(self):
        result = apply_prompt_profile("BASE", DOMAIN_EXPERT_V3_PROFILE)
        normalized = " ".join(result.split())
        for required in (
            "ORGANIC FEATHER FLOW",
            "perspective 3D camera",
            "No repeated peg-board silhouette",
            "Coherent surface field",
            "golden-angle distribution",
            "Sparse hero feathers",
            "leaf/lens or curved tapered profile",
            "Derive placement from a curved wing envelope",
            "Variation must be correlated and hierarchical",
            "Feather material is broad and satin-matte",
        ):
            self.assertIn(required, normalized)

    def test_domain_expert_v4_defines_multiscale_plumage_material(self):
        result = apply_prompt_profile("BASE", DOMAIN_EXPERT_V4_PROFILE)
        normalized = " ".join(result.split())
        for required in (
            "PLUMAGE MATERIAL SYSTEM",
            "perspective, genuinely 3D",
            "no global sine bands",
            "three-scale object-space plumage system",
            "warped non-axis-aligned feather-cell field",
            "stable neighboring-cell evaluation",
            "material-specific tangent flow",
            "roughness roughly 0.65–0.9",
            "bounded plumage normal perturbation",
            "cheap macro bounds before meso detail",
        ):
            self.assertIn(required, normalized)

    def test_domain_expert_v5_requires_containment_and_designed_sequences(self):
        result = apply_prompt_profile("BASE", DOMAIN_EXPERT_V5_PROFILE)
        normalized = " ".join(result.split())
        for required in (
            "CONTAINED DESIGNED VARIATION",
            "Build and compile the complete macro bird before adding detail",
            "A performance `if` is not geometric containment",
            "dContained = max(dDetail, dParentRegion)",
            "Never apply unbounded `fract`, `mod`, or periodic folding",
            "Randomness modifies a designed sequence",
            "7–10 explicitly bounded 3D flight feathers",
            "Do not call `select()` on structs",
            "Do not assign to vector swizzles",
            "cheap parent bounds before evaluating local detail",
        ):
            self.assertIn(required, normalized)


if __name__ == "__main__":
    unittest.main()
