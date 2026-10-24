"""Exercise the OpenCode installer in a temporary config directory."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "scripts" / "install-opencode.py"
SOURCE = ROOT / "harnesses" / "opencode" / "opencode.jsonc"


class OpenCodeInstallTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.config = Path(self.temp.name) / "opencode"
        self.config.mkdir()
        self.legacy = self.config / "opencode.json"
        self.jsonc = self.config / "opencode.jsonc"
        self.plugin = self.config / "plugin" / "block-pass-secrets.ts"
        self.plugin.parent.mkdir()
        self.legacy.write_text(json.dumps({
            "$schema": "https://opencode.ai/config.json",
            "permission": {"bash": {
                "pass": "deny", "pass *": "deny", "pass ls*": "allow",
                "pass find *": "allow", "pass git *": "allow",
                "pass insert *": "allow", "pass generate *": "allow",
                "pass edit *": "allow", "pass rm *": "allow",
                "pass mv *": "allow", "pass cp *": "allow",
                "pass help*": "allow", "pass --version": "allow",
                "passenv *": "allow", "passkeys *": "allow",
            }},
        }))
        self.jsonc.write_text('{"$schema":"https://opencode.ai/config.json"}')
        self.plugin.write_text("legacy plugin placeholder")

    def install(self, *args):
        return subprocess.run(
            [sys.executable, str(INSTALLER), "--config-dir", str(self.config), *args],
            capture_output=True, text=True,
        )

    def test_preview_backup_and_idempotence(self):
        preview = self.install()
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertTrue(self.legacy.exists())
        self.assertTrue(self.plugin.exists())

        applied = self.install("--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertFalse(self.legacy.exists())
        self.assertFalse(self.plugin.exists())
        self.assertEqual(json.loads(self.jsonc.read_text()), json.loads(SOURCE.read_text()))
        backup = next((self.config / "backups").iterdir())
        self.assertTrue((backup / "opencode.json").exists())
        self.assertTrue((backup / "opencode.jsonc").exists())
        self.assertEqual((backup / "plugin" / "block-pass-secrets.ts").read_text(),
                         "legacy plugin placeholder")
        self.assertIn("already installed", self.install("--apply").stdout)

    def test_refuse_unreviewed_config(self):
        self.legacy.write_text('{"model":"custom/my-model"}')
        rejected = self.install("--apply")
        self.assertNotEqual(rejected.returncode, 0)
        self.assertEqual(self.legacy.read_text(), '{"model":"custom/my-model"}')
        self.assertEqual(self.install("--apply", "--replace-reviewed").returncode, 0)

    def test_native_v2_policy_shape(self):
        data = json.loads(SOURCE.read_text())
        self.assertNotIn("permission", data)
        self.assertEqual(data["$schema"], "https://opencode.ai/config.json")
        self.assertEqual(data["policies"][0], {
            "action": "tool.use", "resource": "shell:pass *", "effect": "deny",
        })
        for rule in data["policies"] + data["permissions"]:
            self.assertEqual(set(rule), {"action", "resource", "effect"})


if __name__ == "__main__":
    unittest.main()
