"""Contract and offline smoke tests for the Linux GitHub -> GitLab sync runner."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "sync.sh"
CONFIG = ROOT / "config" / "github-gitlab-projects.json"


class SyncShellTests(unittest.TestCase):
    def test_speech_is_in_repo_mapping_once(self):
        cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
        names = [x["github"] for x in cfg["projects"]]
        self.assertEqual(len(names), len(set(names)), "Duplicate GitHub repo entries")
        self.assertEqual(names.count("alice-speech-service"), 1)
        speech = next(x for x in cfg["projects"] if x["github"] == "alice-speech-service")
        self.assertEqual(speech["gitlab"], "alice/microservices/speech")

    def test_node_manager_mirror_uses_actual_github_repository(self):
        cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
        node = [p for p in cfg["projects"]
                if p["gitlab"] == "alice/microservices/node-manager"]
        self.assertEqual(len(node), 1)
        self.assertEqual(node[0]["github"], "alice-microservices-node-manager")
        self.assertNotIn("alice-node-manager", [p["github"] for p in cfg["projects"]])

    def test_runner_keeps_fast_forward_ssh_backend_and_lock(self):
        script = SCRIPT.read_text(encoding="utf-8")
        self.assertTrue(script.startswith("#!/usr/bin/env bash\n"))
        self.assertIn('l-github-gitlab-sync.py', script)
        self.assertIn('flock -n 9', script)
        self.assertIn('--dry-run', script)
        self.assertIn('--no-collect-ci', script)
        self.assertIn('ALICE_SYNC_INTERVAL_SECONDS', script)
        self.assertIn('ALICE_SYNC_LOCK_FILE', script)
        self.assertNotIn('--force', script.replace('never force-pushes', ''))

    @unittest.skipUnless(shutil.which("bash"), "Bash unavailable in this test container")
    def test_shell_syntax_and_help(self):
        result = subprocess.run(["bash", "-n", str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run(["bash", str(SCRIPT), "--help"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--once", result.stdout)
        self.assertIn("--dry-run", result.stdout)

    @unittest.skipUnless(all(shutil.which(x) for x in ("bash", "git", "flock")),
                         "Requires Bash, Git and flock")
    def test_dry_run_and_one_shot_propagate_exit_code_without_network(self):
        with tempfile.TemporaryDirectory(prefix="alice-sync-test-") as td:
            root = Path(td)
            bindir = root / "bin"
            bindir.mkdir()
            call_args = root / "args.txt"
            python_stub = bindir / "python3"
            python_stub.write_text(
                "#!/bin/sh\n"
                'printf "%s\\n" "$@" > "$ALICE_SYNC_TEST_ARGS"\n'
                'exit "${ALICE_SYNC_TEST_RETURN:-0}"\n',
                encoding="utf-8"
            )
            python_stub.chmod(0o755)
            env = dict(os.environ,
                       PATH=str(bindir) + os.pathsep + os.environ.get("PATH", ""),
                       ALICE_SYNC_TEST_ARGS=str(call_args),
                       ALICE_SYNC_LOCK_FILE=str(root / "lock"))

            result = subprocess.run(
                ["bash", str(SCRIPT), "--dry-run", "--only", "alice-speech-service"],
                cwd=root, env=env, capture_output=True, text=True, timeout=15
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            args = call_args.read_text(encoding="utf-8").splitlines()
            self.assertIn("--dry-run", args)
            self.assertIn("--config", args)
            self.assertIn(str(CONFIG), args)
            self.assertIn("alice-speech-service", args)
            self.assertNotIn("--apply", args)

            env["ALICE_SYNC_TEST_RETURN"] = "7"
            result = subprocess.run(
                ["bash", str(SCRIPT), "--once", "--no-collect-ci"],
                cwd=root, env=env, capture_output=True, text=True, timeout=15
            )
            self.assertEqual(result.returncode, 7, result.stderr)
            self.assertIn("BŁĄD synchronizacji (kod 7)", result.stderr)
            args = call_args.read_text(encoding="utf-8").splitlines()
            self.assertIn("--apply", args)
            self.assertIn("--no-collect-ci", args)

    @unittest.skipUnless(shutil.which("bash"), "Bash unavailable")
    def test_invalid_values_fail_before_running_sync(self):
        for bad_args in (
            ["--interval", "9"],
            ["--workers", "0"],
            ["--workers", "17"],
            ["--only"],
            ["--unknown"],
        ):
            with self.subTest(args=bad_args):
                result = subprocess.run(
                    ["bash", str(SCRIPT), *bad_args],
                    capture_output=True, text=True, timeout=10
                )
                self.assertEqual(result.returncode, 2)
                self.assertIn("BŁĄD:", result.stderr)


if __name__ == "__main__":
    unittest.main()
