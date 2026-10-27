$ErrorActionPreference = "Stop"

$composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
$envFile = Join-Path $PSScriptRoot ".env"

if (-not (Test-Path -LiteralPath $composeFile)) {
    throw "Nie znaleziono pliku Compose: $composeFile"
}

if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Nie znaleziono pliku .env: $envFile"
}

try {
    docker version --format '{{.Server.Version}}' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker daemon is unavailable."
    }
} catch {
    throw "Docker Desktop nie jest uruchomiony albo demon Docker jest niedostepny."
}

$composeBaseArguments = @(
    "compose",
    "--project-directory", $PSScriptRoot,
    "--env-file", $envFile,
    "-f", $composeFile
)

$services = @(
    "alice-web",
    "media-service"
)

Write-Host "Sprawdza konfiguracje Compose..." -ForegroundColor Cyan
& docker @composeBaseArguments config --quiet
if ($LASTEXITCODE -ne 0) {
    throw "Konfiguracja Docker Compose jest niepoprawna (kod $LASTEXITCODE)."
}

Write-Host "Buduje obrazy: $($services -join ', ') (bez cache)..." -ForegroundColor Cyan
& docker @composeBaseArguments build --no-cache @services
if ($LASTEXITCODE -ne 0) {
    throw "Budowanie obrazow zakonczone kodem $LASTEXITCODE."
}

Write-Host "Odtwarza tylko kontenery: $($services -join ', ')..." -ForegroundColor Cyan
& docker @composeBaseArguments up --detach --force-recreate --no-deps @services
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose zakonczyl sie kodem $LASTEXITCODE."
}

Write-Host "Stan kontenerow:" -ForegroundColor Green
& docker @composeBaseArguments ps @services
if ($LASTEXITCODE -ne 0) {
    throw "Nie udalo sie odczytac stanu kontenerow (kod $LASTEXITCODE)."
}

Write-Host "Logi Alice Web i Media Service (Ctrl+C aby zakonczyc):" -ForegroundColor Yellow
& docker @composeBaseArguments logs -f @services
