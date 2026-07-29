import unittest

from prompt_profiles import (
    BASELINE_PROFILE,
    CHATGPT_SHADER_HARNESS_PROFILE,
    AMBITIOUS_3D_PROFILE,
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


if __name__ == "__main__":
    unittest.main()
