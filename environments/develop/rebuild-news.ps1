[CmdletBinding()]
param(
    [switch]$SkipHttpSmokeTest
)

$ErrorActionPreference = "Stop"
$composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
$envFile = Join-Path $PSScriptRoot ".env"
$newsRepository = Join-Path $PSScriptRoot "../../../microservices/news"

if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Brak pliku .env. Skopiuj .env.example do .env i uzupelnij haslo NEWS_DB_PASSWORD."
}
if (-not (Test-Path -LiteralPath (Join-Path $newsRepository "Dockerfile"))) {
    throw "Brak Alice News w microservices/news. Uruchom .\pull-all.ps1."
}

& docker version --format '{{.Server.Version}}' | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Docker nie jest dostepny." }

$base = @("compose", "--project-directory", $PSScriptRoot,
          "--env-file", $envFile, "-f", $composeFile)

function Invoke-DevCompose {
    param([string[]]$ComposeArgs)
    & docker @base @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose ($($ComposeArgs -join ' ')) nie powiodl sie: $LASTEXITCODE"
    }
}

Write-Host "Uruchamiam zaleznosci DEV (bez kasowania wolumenow)..." -ForegroundColor Cyan
Invoke-DevCompose -ComposeArgs @("up", "--detach", "--wait", "postgres", "rabbitmq")

Write-Host "Tworze baze i role Alice News, jesli ich jeszcze nie ma..." -ForegroundColor Cyan
Invoke-DevCompose -ComposeArgs @("exec", "-T", "postgres", "bash",
    "/docker-entrypoint-initdb.d/09-init-news-database.sh")

Write-Host "Buduje obraz Alice News..." -ForegroundColor Cyan
Invoke-DevCompose -ComposeArgs @("build", "news-service")

Write-Host "Uruchamiam Alice News i czekam na Actuator readiness..." -ForegroundColor Cyan
Invoke-DevCompose -ComposeArgs @("up", "--detach", "--no-deps", "--wait", "news-service")

Invoke-DevCompose -ComposeArgs @("ps", "news-service")
if (-not $SkipHttpSmokeTest) {
    $address = & docker @base port news-service 8080
    if ($LASTEXITCODE -ne 0 -or -not $address) {
        throw "Nie mozna ustalic portu API News."
    }
    $address = ([string](@($address)[-1])).Trim()
    $url = "http://$address/actuator/health/readiness"
    Write-Host "Sprawdzam $url" -ForegroundColor Cyan
    & curl.exe --fail --silent --show-error --max-time 10 $url
    if ($LASTEXITCODE -ne 0) {
        throw "Actuator readiness nie odpowiada poprawnie ($url)."
    }
}

Write-Host "`nAlice News DEV: uruchomiony, baza zainicjalizowana i sprawdzono gotowosc." -ForegroundColor Green
