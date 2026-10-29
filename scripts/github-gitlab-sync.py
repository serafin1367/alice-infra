#!/usr/bin/env python3
"""AliceAI one-way GitHub -> GitLab fast-forward sync. Python 3.10+; git CLI."""
import argparse
import datetime as dt
from concurrent.futures import ThreadPoolExecutor
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

def sync_project(project, cfg, branch, apply):
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
                        return item
                    if base.returncode:
                        raise RuntimeError("Cannot verify fast-forward ancestry")
                if not apply:
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
    return item

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    p.add_argument("--apply", action="store_true", help="Perform fast-forward pushes (default behavior; retained for compatibility)")
    p.add_argument("--dry-run", action="store_true", help="Only preview sync; do not publish CI reports")
    p.add_argument("--only", action="append", default=[], help="GitHub repository name; repeatable")
    p.add_argument("--report", type=Path, help="Report path (default: reports/github-gitlab-sync.json)")
    p.add_argument("--workers", type=int, default=4, help="Concurrent repositories (1-16, default 4)")\n    p.add_argument("--collect-ci", action="store_true", help="Collect CI reports (enabled by default; retained for compatibility)")
    p.add_argument("--no-collect-ci", action="store_true", help="Skip CI report collection")
    args = p.parse_args()
    if not 1 <= args.workers <= 16:
        p.error("--workers must be 1..16")
    if args.collect_ci and not args.apply:\n        p.error("--collect-ci requires --apply")\n    cfg = json.loads(args.config.read_text(encoding="utf-8"))
    report_file = args.report or BASE / "reports" / "github-gitlab-sync.json"
    report_file.parent.mkdir(parents=True, exist_ok=True)
    branch = cfg.get("branch", "main")
    projects = [x for x in cfg["projects"] if not args.only or x["github"] in args.only]
    unknown = set(args.only) - {x["github"] for x in cfg["projects"]}
    if unknown:
        p.error("Unknown project(s): " + ", ".join(sorted(unknown)))
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        results = list(executor.map(lambda project: sync_project(project, cfg, branch, apply), projects))
    for item in results:
        print(f"{item['github']}: {item['status']}")
    report = {"schema_version": 1, "generated_at": iso(), "mode": "apply" if apply else "dry-run", "workers": args.workers,
              "projects": results}
    report_file.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Report:", report_file)
    sync_failed = any(x["status"] in ("ERROR", "DIVERGED") for x in results)\n    if args.collect_ci:\n        # Collect all configured projects, including ones whose sync failed, so CI errors remain visible.\n        collector = BASE / "scripts" / "publish-ci-reports.sh"\n        env = dict(os.environ, GITLAB_URL=cfg["gitlab_base_url"],\n                   GITLAB_PROJECTS=",".join(x["gitlab"] for x in projects))\n        try:\n            completed = subprocess.run(["bash", str(collector)], env=env, timeout=600, check=False)\n            if completed.returncode:\n                print("CI report collection/publish failed", file=sys.stderr)\n                sync_failed = True\n        except (OSError, subprocess.TimeoutExpired) as exc:\n            print(f"CI report collection failed: {type(exc).__name__}", file=sys.stderr)\n            sync_failed = True\n    return 1 if sync_failed else 0

if __name__ == "__main__":
    sys.exit(main())
