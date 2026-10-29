#!/usr/bin/env python3
"""AliceAI one-way GitHub -> GitLab fast-forward sync. Python 3.10+; git CLI."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.parse import quote

BASE = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG = BASE / "config" / "github-gitlab-projects.json"

def git(*args, cwd=None):
    # Never include credentials in URLs; git credential helper / SSH agent handles auth.
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0")
    return subprocess.run(["git", *args], cwd=cwd, env=env, text=True,
                          capture_output=True, check=False, timeout=180)

def url_path(s):
    # Encode each component; spaces in project names must not become URL delimiters.
    return "/".join(quote(part, safe="-._~") for part in s.split("/"))

def iso():
    return dt.datetime.now(dt.timezone.utc).isoformat()

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    p.add_argument("--apply", action="store_true", help="Perform fast-forward pushes (default: dry-run)")
    p.add_argument("--only", action="append", default=[], help="GitHub repository name; repeatable")
    p.add_argument("--report", type=Path, help="Report path (default: reports/github-gitlab-sync.json)")
    args = p.parse_args()
    cfg = json.loads(args.config.read_text(encoding="utf-8"))
    report_file = args.report or BASE / "reports" / "github-gitlab-sync.json"
    report_file.parent.mkdir(parents=True, exist_ok=True)
    branch = cfg.get("branch", "main")
    projects = [x for x in cfg["projects"] if not args.only or x["github"] in args.only]
    unknown = set(args.only) - {x["github"] for x in cfg["projects"]}
    if unknown:
        p.error("Unknown project(s): " + ", ".join(sorted(unknown)))
    results = []
    for project in projects:
        name, target = project["github"], project["gitlab"]
        owner = cfg["github_owner"]
        gh = f"https://github.com/{owner}/{quote(name, safe='-._~')}.git"
        gl = cfg["gitlab_base_url"].rstrip("/") + "/" + url_path(target) + ".git"
        item = {"github": name, "gitlab": target, "branch": branch, "source_sha": None,
                "target_sha": None, "status": "ERROR", "detail": ""}
        try:
            with tempfile.TemporaryDirectory(prefix="alice-git-sync-") as tmp:
                init = git("init", "-q", tmp)
                if init.returncode:
                    raise RuntimeError("git init failed")
                src = git("fetch", "-q", "--no-tags", gh, f"refs/heads/{branch}", cwd=tmp)
                if src.returncode:
                    raise RuntimeError("GitHub fetch failed (check repository/access/branch)")
                source = git("rev-parse", "FETCH_HEAD", cwd=tmp)
                if source.returncode:
                    raise RuntimeError("Cannot resolve GitHub branch")
                item["source_sha"] = source.stdout.strip()
                # Distinguish missing target branch from inaccessible repository via ls-remote.
                remote = git("ls-remote", "--heads", gl, f"refs/heads/{branch}", cwd=tmp)
                if remote.returncode:
                    raise RuntimeError("GitLab ls-remote failed (check project/access)")
                target_sha = remote.stdout.split()[0] if remote.stdout.strip() else None
                item["target_sha"] = target_sha
                if target_sha == item["source_sha"]:
                    item["status"] = "UP_TO_DATE"
                else:
                    if target_sha:
                        fetched = git("fetch", "-q", "--no-tags", gl, f"refs/heads/{branch}", cwd=tmp)
                        if fetched.returncode:
                            raise RuntimeError("GitLab fetch failed")
                        base = git("merge-base", "--is-ancestor", target_sha, item["source_sha"], cwd=tmp)
                        if base.returncode == 1:
                            item["status"] = "DIVERGED"
                            item["detail"] = "Target is not an ancestor of GitHub; manual review required"
                            results.append(item)
                            print(f"{name}: DIVERGED (no push)")
                            continue
                        if base.returncode:
                            raise RuntimeError("Cannot verify fast-forward ancestry")
                    if not args.apply:
                        item["status"] = "WOULD_CREATE" if not target_sha else "WOULD_UPDATE"
                    else:
                        # Git server enforces non-force fast-forward; prevents clobbering concurrent changes.
                        push = git("push", "--porcelain", gl,
                                   f"{item['source_sha']}:refs/heads/{branch}", cwd=tmp)
                        if push.returncode:
                            raise RuntimeError("GitLab push rejected (permissions, race, or branch protection)")
                        item["status"] = "CREATED" if not target_sha else "UPDATED"
        except (RuntimeError, subprocess.TimeoutExpired, OSError) as e:
            item["status"] = "ERROR"
            item["detail"] = str(e)
        results.append(item)
        print(f"{name}: {item['status']}")
    report = {"schema_version": 1, "generated_at": iso(), "mode": "apply" if args.apply else "dry-run",
              "projects": results}
    report_file.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Report:", report_file)
    return 1 if any(x["status"] in ("ERROR", "DIVERGED") for x in results) else 0

if __name__ == "__main__":
    sys.exit(main())
