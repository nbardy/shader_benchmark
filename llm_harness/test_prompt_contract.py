import os
import tempfile
import unittest

from llm_client import LLMClient


class PromptContractTests(unittest.TestCase):
    def test_prompt_is_cwd_independent_and_forbids_extra_uniform_fields(self):
        client = LLMClient()
        original_cwd = os.getcwd()
        try:
            with tempfile.TemporaryDirectory() as temporary:
                os.chdir(temporary)
                prompt = client.build_generation_prompt("Draw it.")
        finally:
            os.chdir(original_cwd)
        self.assertIn("Do NOT add fields", prompt)
        self.assertNotIn("Add problem-specific fields", prompt)
        self.assertNotIn("Use var<function>", prompt)
        self.assertIn("do NOT write var<function>", prompt)


if __name__ == "__main__":
    unittest.main()
