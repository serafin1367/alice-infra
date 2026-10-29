$env:CI_REPORTS_PRIVATE = "true"

while ($true) {
   py github-gitlab-sync.py --workers 8 --apply
    Start-Sleep -Seconds 100
}
