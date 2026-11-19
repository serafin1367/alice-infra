[CmdletBinding()]
param(
    [switch]$Enable,
    [switch]$Disable
)

$ErrorActionPreference = "Stop"
if ($Enable -and $Disable) { throw "Wybierz tylko -Enable albo -Disable." }
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path -LiteralPath $envFile)) { throw "Brak prywatnego .env w DEV." }
$base = @("compose", "--project-directory", $PSScriptRoot,
    "--env-file", $envFile, "-f", (Join-Path $PSScriptRoot "docker-compose.yml"))
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$original = [System.IO.File]::ReadAllText($envFile, $utf8)

function Read-Setting([string]$Text, [string]$Name) {
    $matches = [regex]::Matches($Text, "(?m)^" + [regex]::Escape($Name) + "=([^\r\n]*)")
    if ($matches.Count -gt 1) { throw "Wiele definicji $Name w .env." }
    if ($matches.Count -eq 0) { return "(brak, wartosc domyslna Compose)" }
    return $matches[0].Groups[1].Value.Trim()
}

$names = @("NEWS_RSS_ENABLED", "NEWS_RSS_POLL_MS", "NEWS_ENRICHMENT_ENABLED",
    "NEWS_ENRICHMENT_BATCH_SIZE", "NEWS_ENRICHMENT_INTERVAL_MS",
    "NEWS_RETENTION_CLEANUP_ENABLED")
Write-Host "Alice NEWS MVP - konfiguracja DEV (bez sekretow):" -ForegroundColor Cyan
foreach ($name in $names) {
    Write-Host ("{0}={1}" -f $name, (Read-Setting $original $name))
}
if (-not ($Enable -or $Disable)) {
    Write-Host "Tylko odczyt. Opcje: -Enable / -Disable." -ForegroundColor Green
    return
}

$requested = if ($Enable) {
    [ordered]@{
        NEWS_RSS_ENABLED = "true"
        NEWS_RSS_POLL_MS = "60000"
        NEWS_ENRICHMENT_ENABLED = "true"
        NEWS_ENRICHMENT_BATCH_SIZE = "10"
        NEWS_ENRICHMENT_INTERVAL_MS = "600000"
        NEWS_RETENTION_CLEANUP_ENABLED = "false"
    }
} else {
    [ordered]@{
        NEWS_RSS_ENABLED = "false"
        NEWS_ENRICHMENT_ENABLED = "false"
        NEWS_RETENTION_CLEANUP_ENABLED = "false"
    }
}
if ($Enable) {
    Write-Host "RSS: kontrola terminow zrodel co 60 s; EN->PL: do 10 artykulow co 10 min." -ForegroundColor Yellow
    if ((Read-Host "Aby wlaczyc automatyzacje DEV, wpisz WLACZ") -cne "WLACZ") {
        Write-Host "Anulowano."; return
    }
} else {
    if ((Read-Host "Aby wylaczyc harmonogramy DEV, wpisz WYLACZ") -cne "WYLACZ") {
        Write-Host "Anulowano."; return
    }
}

$newText = $original
$lineEnding = [Environment]::NewLine
foreach ($name in $requested.Keys) {
    $pattern = "(?m)^" + [regex]::Escape($name) + "=[^\r\n]*"
    $matches = [regex]::Matches($newText, $pattern)
    if ($matches.Count -gt 1) { throw "Wiele definicji $name w .env." }
    $line = $name + "=" + $requested[$name]
    if ($matches.Count -eq 1) {
        $newText = [regex]::Replace($newText, $pattern, $line)
    } else {
        if ($newText.Length -gt 0 -and -not $newText.EndsWith([string][char]10)) {
            $newText += $lineEnding
        }
        $newText += $line + $lineEnding
    }
}
if ($newText -ceq $original) {
    Write-Host "Wybrane ustawienia sa juz zapisane. Kontener bez zmian."
    return
}

$changed = $false
try {
    [System.IO.File]::WriteAllText($envFile, $newText, $utf8)
    $changed = $true
    & docker @base config --quiet
    if ($LASTEXITCODE -ne 0) { throw "Blad konfiguracji Docker Compose." }
    & docker @base up -d --no-deps --force-recreate --wait news-service
    if ($LASTEXITCODE -ne 0) { throw "News service nie przeszedl healthcheck." }
    foreach ($name in @("NEWS_RSS_ENABLED", "NEWS_ENRICHMENT_ENABLED",
                       "NEWS_ENRICHMENT_BATCH_SIZE", "NEWS_ENRICHMENT_INTERVAL_MS")) {
        $value = & docker @base exec -T news-service printenv $name
        if ($LASTEXITCODE -ne 0) { throw "Brak aktywnej flagi $name." }
        Write-Host ("{0}={1}" -f $name, ([string](@($value)[-1])).Trim())
    }
    Write-Host "Gotowe: zmieniono jedynie DEV news-service i wybrane flagi .env." -ForegroundColor Green
} catch {
    if ($changed) {
        Write-Warning "Przywracam oryginalny .env i kontener news-service."
        [System.IO.File]::WriteAllText($envFile, $original, $utf8)
        & docker @base up -d --no-deps --force-recreate --wait news-service
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Nie udalo sie odtworzyc kontenera - sprawdz logi News."
        }
    }
    throw
}
