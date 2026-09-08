"""Exercise deployment clone decisions using temporary local Git repositories."""
import pathlib
import shutil
import subprocess
import tempfile
import unittest


class RepositoryCloneTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="alice-deploy-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.source = self.root / "source"
        self.git("init", "-b", "main", str(self.source))
        self.git("-C", str(self.source), "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "commit", "--allow-empty", "-m", "fixture")
        self.helper = pathlib.Path(__file__).resolve().parents[1] / "repository-functions.sh"
        windows_bash = pathlib.Path("C:/Program Files/Git/bin/bash.exe")
        self.bash = str(windows_bash) if windows_bash.exists() else shutil.which("bash")

    def git(self, *args):
        return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout.strip()

    def ensure(self, target, source=None):
        return subprocess.run([self.bash, "-c", 'source "$1"; ensure_repository "$2" "$3" main',
                               "test", self.helper.as_posix(), target.as_posix(),
                               (source or self.source).as_posix()], capture_output=True, text=True)

    def test_clones_missing_repository_and_parents(self):
        target = self.root / "microservices" / "knowledge"
        result = self.ensure(target)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("-C", str(target), "branch", "--show-current"), "main")

    def test_accepts_empty_directory(self):
        target = self.root / "empty"
        target.mkdir()
        self.assertEqual(self.ensure(target).returncode, 0)
        self.assertTrue((target / ".git").exists())

    def test_preserves_existing_repository_and_local_files(self):
        target = self.root / "existing"
        self.assertEqual(self.ensure(target).returncode, 0)
        (target / "local.txt").write_text("keep")
        origin = self.git("-C", str(target), "remote", "get-url", "origin")
        self.assertEqual(self.ensure(target, self.root / "nonexistent").returncode, 0)
        self.assertEqual((target / "local.txt").read_text(), "keep")
        self.assertEqual(self.git("-C", str(target), "remote", "get-url", "origin"), origin)

    def test_refuses_nonempty_directory_without_deleting_data(self):
        target = self.root / "data"
        target.mkdir()
        (target / "important.txt").write_text("keep")
        self.assertNotEqual(self.ensure(target).returncode, 0)
        self.assertEqual((target / "important.txt").read_text(), "keep")
        self.assertFalse((target / ".git").exists())


if __name__ == "__main__":
    unittest.main()
