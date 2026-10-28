[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot "../../.."),
    [int]$MaxDepth = 5
)

$ErrorActionPreference = "Continue" # Git stderr is handled by exit code, including in Windows PowerShell 5.1.
$Root = (Resolve-Path -LiteralPath $Root).Path
$excluded = @(".git", "node_modules", "target", "build", "dist", ".venv", "venv", ".next", ".idea")
$pending = New-Object System.Collections.Stack
$pending.Push(@($Root, 0))
$repositories = New-Object System.Collections.Generic.List[string]

while ($pending.Count -gt 0) {
    $entry = $pending.Pop()
    $dir = [string]$entry[0]
    $depth = [int]$entry[1]
    if (Test-Path -LiteralPath (Join-Path $dir ".git")) {
        $top = & git -C $dir rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $top) {
            $resolvedTop = [System.IO.Path]::GetFullPath(([string](@($top)[-1])).Trim()).TrimEnd([char[]]@('/', '\'))
            $resolvedDir = [System.IO.Path]::GetFullPath($dir).TrimEnd([char[]]@('/', '\'))
            if ([string]::Equals($resolvedTop, $resolvedDir, [System.StringComparison]::OrdinalIgnoreCase)) {
                $repositories.Add($dir)
                continue
            }
        }
        Write-Warning "Nieprawidlowy katalog .git: $dir. Sprawdzam podkatalogi."
    }
    if ($depth -ge $MaxDepth) { continue }
    foreach ($child in (Get-ChildItem -LiteralPath $dir -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($excluded -contains $child.Name) { continue }
        $pending.Push(@($child.FullName, ($depth + 1)))
    }
}

$updated = 0
$unchanged = 0
$skipped = 0
$failed = 0

foreach ($repoPath in ($repositories | Sort-Object)) {
    Write-Host "`n=== $repoPath ===" -ForegroundColor Cyan
    $status = & git -C $repoPath status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Nie udalo sie odczytac stanu Git. Pomijam."
        $failed++
        continue
    }
    if ($status) {
        Write-Warning "Lokalne zmiany (w tym pliki nieśledzone). Pomijam, aby ich nie naruszyc."
        $skipped++
        continue
    }

    $branch = (& git -C $repoPath symbolic-ref --quiet --short HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Detached HEAD. Pomijam."
        $skipped++
        continue
    }

    $upstream = (& git -C $repoPath rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $upstream) {
        Write-Warning "Brak skonfigurowanego upstream dla $branch. Pomijam."
        $skipped++
        continue
    }

    $before = (& git -C $repoPath rev-parse HEAD).Trim()
    Write-Host "Galaz: $branch, upstream: $upstream"
    & git -C $repoPath pull github main --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Pull nie powiodl sie. Sprawdz komunikat Git powyzej."
        $failed++
        continue
    }
    $after = (& git -C $repoPath rev-parse HEAD).Trim()
    if ($before -eq $after) { $unchanged++ } else { $updated++ }
}

Write-Host "`n=== Podsumowanie ===" -ForegroundColor Green
Write-Host "Znalezione: $($repositories.Count) | Zaktualizowane: $updated | Bez zmian: $unchanged | Pominiete: $skipped | Bledy: $failed"
if ($failed -gt 0) { exit 1 }
