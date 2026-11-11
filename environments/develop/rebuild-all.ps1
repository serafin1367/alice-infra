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
    "health-service",
    "budget-service",
    "media-service",
    "iot-workshop"
)

# Docker Compose may otherwise build independent Maven services concurrently.
# Keep caching enabled; --no-cache redownloads all Maven dependencies on every run.
$previousParallelLimit = [Environment]::GetEnvironmentVariable("COMPOSE_PARALLEL_LIMIT", "Process")
$env:COMPOSE_PARALLEL_LIMIT = "1"
Write-Host "Buduje uslugi kolejno, z cache Maven i Docker (COMPOSE_PARALLEL_LIMIT=1)..." -ForegroundColor Cyan
try {
    & docker @composeBaseArguments build @buildServices
    $buildExitCode = $LASTEXITCODE
} finally {
    [Environment]::SetEnvironmentVariable("COMPOSE_PARALLEL_LIMIT", $previousParallelLimit, "Process")
}
if ($buildExitCode -ne 0) {
    throw "Budowanie obrazow zakonczone kodem $buildExitCode."
}
# Build completed successfully; images can now be recreated.
#

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

& docker @composeBaseArguments logs -f
