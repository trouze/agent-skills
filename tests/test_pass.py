"""Run pass helpers against a fake password store, never the real one."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1] / "skills" / "pass" / "scripts"


class PassHelpersTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        bindir = self.home / "fake-bin"
        bindir.mkdir()
        fake_pass = bindir / "pass"
        fake_pass.write_text(
            "#!/bin/sh\n"
            "test \"$1\" = show || exit 2\n"
            "printf '%s\\n' 'topsecretpassword' 'API_TOKEN=dummy-only' "
            "'MODE=test' 'not-an-env-line'\n"
        )
        fake_pass.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", HOME=str(self.home))

    def run_script(self, name, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPTS / name), *args],
            env=self.env, capture_output=True, text=True,
        )

    def test_passkeys_never_prints_password_line(self):
        result = self.run_script("passkeys.py", "sample")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["API_TOKEN", "MODE"])
        self.assertNotIn("topsecret", result.stdout)

    def test_passenv_names_only_and_command_injection(self):
        names = self.run_script("passenv.py", "sample")
        self.assertEqual(names.stdout.splitlines(), ["API_TOKEN", "MODE"])
        child = self.run_script(
            "passenv.py", "sample", "--", sys.executable, "-c",
            "import os; print(os.environ['API_TOKEN'])",
        )
        self.assertEqual(child.returncode, 0, child.stderr)
        self.assertEqual(child.stdout.strip(), "dummy-only")

    def test_install_helpers_and_do_not_clobber_existing(self):
        installer = self.run_script("install_helpers.py")
        self.assertEqual(installer.returncode, 0, installer.stderr)
        for name in ("passenv", "passkeys"):
            launcher = self.home / ".local" / "bin" / name
            self.assertTrue(launcher.exists())
            self.assertTrue(os.access(launcher, os.X_OK))
        wrapped = subprocess.run(
            [str(self.home / ".local" / "bin" / "passkeys"), "sample"],
            env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(wrapped.returncode, 0, wrapped.stderr)
        self.assertEqual(wrapped.stdout.splitlines(), ["API_TOKEN", "MODE"])
        existing = self.home / ".local" / "bin" / "passkeys"
        existing.write_text("user-modified launcher\n")
        retry = self.run_script("install_helpers.py")
        self.assertNotEqual(retry.returncode, 0)
        self.assertEqual(existing.read_text(), "user-modified launcher\n")


if __name__ == "__main__":
    unittest.main()
