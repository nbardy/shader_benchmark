import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from llm_client import CLI_ISOLATION_PROTOCOL, CliExecutor


class CliIsolationTests(unittest.TestCase):
    def test_codex_generation_uses_fresh_cwd_and_staged_image(self):
        observed = {}

        def fake_run(cmd, **kwargs):
            observed["cmd"] = cmd
            observed["cwd"] = kwargs.get("cwd")
            image_index = cmd.index("-i") + 1
            observed["image"] = cmd[image_index]
            output_index = cmd.index("-o") + 1
            Path(cmd[output_index]).write_text("<shader>ok</shader>")
            self.assertTrue(Path(observed["image"]).exists())
            return subprocess.CompletedProcess(cmd, 0, "", "")

        with tempfile.TemporaryDirectory() as temp_dir:
            reference = Path(temp_dir) / "parrot.png"
            reference.write_bytes(b"not-a-real-png")
            with patch("llm_client.subprocess.run", side_effect=fake_run):
                content, _usage = CliExecutor()._run_codex(
                    "PROMPT",
                    str(reference),
                    model="gpt-5.6-sol",
                    reasoning_effort="medium",
                )

        self.assertEqual(content, "<shader>ok</shader>")
        self.assertIn(CLI_ISOLATION_PROTOCOL.split("-v1")[0], "isolated-temp-workspace")
        self.assertIn("--ignore-user-config", observed["cmd"])
        self.assertIn("--ignore-rules", observed["cmd"])
        self.assertIn("--ephemeral", observed["cmd"])
        self.assertNotEqual(
            Path(observed["cwd"]).resolve(), Path(__file__).parent.resolve()
        )
        self.assertEqual(Path(observed["image"]).parent, Path(observed["cwd"]))


if __name__ == "__main__":
    unittest.main()
