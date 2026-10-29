#!/usr/bin/env bash
# Called by github-gitlab-sync.py --apply --collect-ci
set -Eeuo pipefail
: "${GITLAB_TOKEN:?Missing GITLAB_TOKEN (read_api)}"
: "${GITHUB_TOKEN:?Missing GITHUB_TOKEN (contents:write to alice-ci-reports)}"
: "${GITLAB_PROJECTS:?Missing GITLAB_PROJECTS}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
exec 9>"${ALICE_CI_LOCK:-/tmp/alice-ci-reports.lock}"
flock -n 9 || { echo "CI collector already running"; exit 0; }
cat > "$WORK/askpass" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' x-access-token ;;
  *Password*) printf '%s\n' "$GITHUB_TOKEN" ;;
  *) exit 1 ;;
esac
EOF
chmod 700 "$WORK/askpass"
export GIT_ASKPASS="$WORK/askpass" GIT_TERMINAL_PROMPT=0
git clone -q https://github.com/serafin1367/alice-ci-reports.git "$WORK/reports"
cd "$WORK/reports"
test -f scripts/collect_pipelines.py || { echo "Merge alice-ci-reports PR #1 first"; exit 1; }
export REPORT_DIR="$PWD"
python3 scripts/collect_pipelines.py
git add index.json latest/ history/
if git diff --cached --quiet; then
  echo "No CI report changes"
  exit 0
fi
git -c user.name="alice-ci-reporter" -c user.email="alice-ci-reporter@users.noreply.github.com" commit -qm "ci: update GitLab pipeline reports"
git push -q origin HEAD:main
