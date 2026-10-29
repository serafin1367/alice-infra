while ($true) {
   py github-gitlab-sync.py --workers 8 --apply
    Start-Sleep -Seconds 100
}
