[CmdletBinding()]
param(
    [Alias("ListProfiles")]
    [switch]$ShowTranslator
)

$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot ".env"
$compose = @("compose", "--project-directory", $PSScriptRoot,
             "--env-file", $envFile, "-f", (Join-Path $PSScriptRoot "docker-compose.yml"))
if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Brak prywatnego pliku .env w katalogu DEV."
}

function Get-LocalComposePort([string]$Service, [int]$ContainerPort) {
    $published = & docker @compose port $Service $ContainerPort
    if ($LASTEXITCODE -ne 0 -or -not $published) {
        throw "Kontener $Service nie udostepnia lokalnego portu $ContainerPort."
    }
    $last = [string](@($published)[-1])
    if ($last -notmatch ':(\d+)\s*$') {
        throw "Nie rozpoznano portu $Service z odpowiedzi Docker Compose."
    }
    return [int]$Matches[1]
}

# The LLM service chooses the translator by purpose; profile IDs are not configuration.
$llmPort = Get-LocalComposePort "llm-service" 8084
try {
    $profile = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$llmPort/api/llm/profiles/purpose/TRANSLATOR" -TimeoutSec 15
} catch {
    throw "Nie znaleziono profilu TRANSLATOR w Alice LLM. Zaktualizuj llm-service z migracja V101 i przypisz profilowi przeznaczenie Tlumacz."
}
if ($null -eq $profile -or $profile.purpose -ne "TRANSLATOR" -or
    [string]::IsNullOrWhiteSpace($profile.model)) {
    throw "Alice LLM nie zwrocil poprawnie skonfigurowanego profilu TRANSLATOR."
}

Write-Host "Automatycznie wykryty profil tlumacza:" -ForegroundColor Cyan
[pscustomobject]@{
    Przeznaczenie = "Tłumacz"
    Nazwa = $profile.name
    Model = $profile.model
    Dostawca = $profile.providerId
} | Format-List
if ($ShowTranslator) {
    Write-Host "Tryb tylko odczyt: nie uruchomiono tlumaczenia." -ForegroundColor Green
    return
}

$newsPort = Get-LocalComposePort "news-service" 8080
$newsUrl = "http://127.0.0.1:$newsPort"
$readiness = Invoke-RestMethod -Method Get -Uri "$newsUrl/actuator/health/readiness" -TimeoutSec 15
if ($readiness.status -ne "UP") {
    throw "Alice News nie jest gotowy. Nie uruchamiam przetwarzania."
}
$batchSizeOutput = & docker @compose exec -T news-service printenv NEWS_ENRICHMENT_BATCH_SIZE
if ($LASTEXITCODE -ne 0) {
    throw "Nie mozna odczytac wielkosci partii News."
}
$batchSize = ([string](@($batchSizeOutput)[-1])).Trim()
Write-Host "Jedno wywolanie przetworzy maksymalnie $batchSize artykulow."
if ((Read-Host "Przetworzyc jedna partie tytulow i streszczen? Wpisz TAK") -cne "TAK") {
    Write-Host "Anulowano. Bez zmian." -ForegroundColor Yellow
    return
}

# The admin token is entered securely and never placed in CLI arguments/history.
$secureToken = Read-Host "NEWS_ADMIN_TOKEN" -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
try {
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Token jest pusty. Nie wyslano zadania."
    }
    $result = Invoke-RestMethod -Method Post -Uri "$newsUrl/api/news/admin/enrichment" -Headers @{ "X-News-Admin-Token" = $token } -TimeoutSec 1800
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    Remove-Variable token, secureToken -ErrorAction SilentlyContinue
}
Write-Host "Wynik partii: $($result.state); przetworzone=$($result.processed); OK=$($result.succeeded); bledy=$($result.failed)" -ForegroundColor Cyan
if ($result.state -ne "OK" -or $result.failed -gt 0) {
    throw "Partia nie zakonczyla sie poprawnie. Sprawdz logi news-service, profil LLM i PostgreSQL."
}
$articles = @(Invoke-RestMethod -Method Get -Uri "$newsUrl/api/news/articles?limit=5" -TimeoutSec 15)
$articles | Select-Object -First 5 title, originalTitle, translationStatus | Format-Table -Wrap
Write-Host "W Alice Web polskie tytuly pojawiaja sie przy translationStatus=DONE." -ForegroundColor Green
