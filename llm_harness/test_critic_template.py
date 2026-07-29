import tempfile
import unittest
from pathlib import Path

from critic_template import CriticTemplate


class CriticTemplateTests(unittest.TestCase):
    def test_reconstruction_aliases_populate_all_three_criteria(self):
        content = """__VISUAL_MATCH__
match silhouette and color
__PROCEDURAL_INTEGRITY__
procedural only
__COMPLETENESS__
include every major element
"""
        questions = CriticTemplate().parse_questions(content)
        self.assertEqual(
            questions,
            {
                1: "match silhouette and color",
                2: "procedural only",
                3: "include every major element",
            },
        )

    def test_formatted_reconstruction_prompt_uses_real_rubric(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            critic = root / "critic.txt"
            request = root / "request.txt"
            critic.write_text(
                "__VISUAL_MATCH__\nMATCH ME\n"
                "__PROCEDURAL_INTEGRITY__\nNO CHEATING\n"
                "__COMPLETENESS__\nALL ELEMENTS\n"
            )
            request.write_text("REPRODUCE")
            prompt = CriticTemplate().format_critic_prompt(critic, request)
        for required in ("MATCH ME", "NO CHEATING", "ALL ELEMENTS"):
            self.assertIn(required, prompt)
        self.assertNotIn("Mathematical Precision Assessment", prompt)


if __name__ == "__main__":
    unittest.main()
