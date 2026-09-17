$ErrorActionPreference = "Stop"
$composeFile = Join-Path $PSScriptRoot "docker-compose.yml"

if (-not (Test-Path -LiteralPath $composeFile)) {
    throw "Nie znaleziono pliku Compose: $composeFile"
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
    "--env-file", (Join-Path $PSScriptRoot ".env"),
    "-f", $composeFile
)

$buildServices = @(
    "alice-web",
    "weather-service",
    "time-coordinator-service",
    "mail-service",
    "llm-service",
    "work-service",
    "shopping-service",
    "knowledge-service",
    "health-service"
    "budget-service"
)

Write-Host "Buduje wszystkie obrazy uslug od nowa, bez cache..." -ForegroundColor Cyan
& docker @composeBaseArguments build --no-cache @buildServices
if ($LASTEXITCODE -ne 0) {
    throw "Budowanie obrazow zakonczone kodem $LASTEXITCODE."
}

$composeArguments = $composeBaseArguments + @(
    "up",
    "--detach",
    "--force-recreate",
    "--remove-orphans"
)

Write-Host "Przebudowuje i odtwarza kontenery srodowiska develop..." -ForegroundColor Cyan
& docker @composeArguments
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose zakonczyl sie kodem $LASTEXITCODE."
}

Write-Host "Aktualny stan kontenerow:" -ForegroundColor Green
& docker compose --project-directory $PSScriptRoot --env-file (Join-Path $PSScriptRoot ".env") -f $composeFile ps
if ($LASTEXITCODE -ne 0) {
    throw "Nie udalo sie odczytac stanu kontenerow (kod $LASTEXITCODE)."
}

& docker compose logs -f
