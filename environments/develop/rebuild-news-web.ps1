[CmdletBinding()]
param(
    [switch]$SkipNewsRebuild
)

$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot ".env"
$composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
$webDockerfile = Join-Path $PSScriptRoot "../../../alice-web/Dockerfile"
if (-not (Test-Path -LiteralPath $envFile)) { throw "Brak prywatnego pliku .env." }
if (-not (Test-Path -LiteralPath $webDockerfile)) {
    throw "Brak kodu Alice Web. Uruchom .\pull-all.ps1."
}
$base = @("compose", "--project-directory", $PSScriptRoot,
    "--env-file", $envFile, "-f", $composeFile)

function Invoke-Compose([string[]]$ArgsList) {
    & docker @base @ArgsList
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose: $($ArgsList -join ' ') zakonczyl sie kodem $LASTEXITCODE."
    }
}

function Assert-Get([string]$Url, [string]$Expected) {
    Write-Host "Sprawdzam GET $Url" -ForegroundColor Cyan
    $response = & curl.exe --silent --show-error --fail --max-time 20 $Url
    if ($LASTEXITCODE -ne 0) {
        throw "Niepowodzenie GET $Url."
    }
    $body = [string]::Join([Environment]::NewLine, [string[]]@($response))
    if (-not $body.Contains($Expected)) {
        throw "GET $Url: odpowiedz nie zawiera spodziewanego znacznika."
    }
}

try {
    if (-not $SkipNewsRebuild) {
        & (Join-Path $PSScriptRoot "rebuild-news.ps1")
    }

    Write-Host "Buduje tylko obraz Alice Web..." -ForegroundColor Cyan
    Invoke-Compose -ArgsList @("build", "alice-web")
    Write-Host "Odtwarzam tylko kontener Alice Web (z nowym NEWS_UPSTREAM)..." -ForegroundColor Cyan
    Invoke-Compose -ArgsList @("up", "-d", "--no-deps", "--force-recreate", "--wait", "alice-web")

    $portResult = & docker @base port alice-web 80
    if ($LASTEXITCODE -ne 0 -or -not $portResult) {
        throw "Nie mozna odczytac portu Alice Web."
    }
    $address = ([string](@($portResult)[-1])).Trim()
    $webUrl = "http://$address"

    Assert-Get "$webUrl/health" "OK"
    Assert-Get "$webUrl/news/" 'data-module="news"'
    Assert-Get "$webUrl/api/news/categories" '"slug"'
    Assert-Get "$webUrl/api/news/articles?limit=1" '"title"'
    Assert-Get "$webUrl/api/news/sources" '"name"'

    # Never submit a token or issue an admin import from the public gateway.
    # Check a harmless POST on categories, which must be denied by nginx.
    $postStatus = & curl.exe --silent --output NUL --write-out "%{http_code}" --max-time 15 --request POST "$webUrl/api/news/categories"
    if ($LASTEXITCODE -ne 0 -or ([string]$postStatus).Trim() -ne "403") {
        throw "Gateway Alice News powinien zabronic POST; uzyskano HTTP $postStatus."
    }
    Write-Host "Alice News przez Alice Web: OK. POST zablokowany HTTP 403." -ForegroundColor Green
    Write-Host "Widok: $webUrl/news/" -ForegroundColor Green
} catch {
    Write-Warning "Test integracji News/Alice Web nie powiodl sie. Ostatnie logi:"
    & docker @base logs --tail 60 --no-color alice-web news-service
    throw
}
