#!/usr/bin/env python3
"""Collect GitLab CI reports and push via existing Git credentials (Windows/Linux)."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

REPO = "git@github.com:serafin1367/alice-ci-reports.git"

def run(*args, cwd=None, env=None, timeout=300):
    subprocess.run(args, cwd=cwd, env=env, timeout=timeout, check=True)

def main():
    for name in ("GITLAB_TOKEN", "GITLAB_PROJECTS"):
        if not os.environ.get(name):
            print(f"Missing {name}", file=sys.stderr)
            return 2
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0")
    with tempfile.TemporaryDirectory(prefix="alice-ci-reports-") as tmp:
        dest = Path(tmp) / "reports"
        run("git", "clone", "-q", REPO, str(dest), env=env)
        collector = dest / "scripts" / "collect_pipelines.py"
        if not collector.is_file():
            print("Missing scripts/collect_pipelines.py in reports repository", file=sys.stderr)
            return 2
        env["REPORT_DIR"] = str(dest)
        run(sys.executable, str(collector), cwd=dest, env=env, timeout=600)
        run("git", "add", "-A", "--", "index.json", "latest", "history", cwd=dest, env=env)
        diff = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=dest, env=env)
        if diff.returncode == 0:
            print("No CI report changes")
            return 0
        if diff.returncode != 1:
            print("Unable to inspect staged changes", file=sys.stderr)
            return 1
        run("git", "-c", "user.name=alice-ci-reporter",
            "-c", "user.email=alice-ci-reporter@users.noreply.github.com",
            "commit", "-m", "ci: update GitLab pipeline reports", cwd=dest, env=env)
        run("git", "push", "origin", "HEAD:main", cwd=dest, env=env)
        print("CI reports published to alice-ci-reports/main")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError) as exc:
        print(f"CI publish failed: {exc}", file=sys.stderr)
        sys.exit(1)
