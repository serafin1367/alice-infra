[CmdletBinding()]
param(
    [switch]$ListProfiles
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

# Inspect existing Alice LLM profiles without changing any data.
$llmPort = Get-LocalComposePort "llm-service" 8084
$profiles = @(Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$llmPort/api/llm/profiles" -TimeoutSec 15)
Write-Host "Dostepne profile Alice LLM:" -ForegroundColor Cyan
$profiles | Select-Object id, name, model, providerId | Format-Table -AutoSize
if ($ListProfiles) {
    Write-Host "Tryb tylko odczyt: nie uruchomiono tlumaczenia." -ForegroundColor Green
    return
}

$newsPort = Get-LocalComposePort "news-service" 8080
$newsUrl = "http://127.0.0.1:$newsPort"
$readiness = Invoke-RestMethod -Method Get -Uri "$newsUrl/actuator/health/readiness" -TimeoutSec 15
if ($readiness.status -ne "UP") {
    throw "Alice News nie jest gotowy. Nie uruchamiam przetwarzania."
}
$rawId = & docker @compose exec -T news-service printenv NEWS_LLM_PROFILE_ID
if ($LASTEXITCODE -ne 0) { throw "Nie moge odczytac identyfikatora profilu News." }
$profileId = 0L
if (-not [long]::TryParse(([string](@($rawId)[-1])).Trim(), [ref]$profileId) -or $profileId -le 0) {
    throw "NEWS_LLM_PROFILE_ID nie jest skonfigurowany. Wybierz id profilu z listy, ustaw je w prywatnym .env, odtworz tylko news-service i ponow test."
}
$selected = @($profiles | Where-Object { $_.id -eq $profileId })
if ($selected.Count -ne 1) {
    throw "Profil LLM id=$profileId nie zostal znaleziony. Nie uruchamiam przetwarzania."
}
Write-Host "Profil: $($selected[0].name) (id=$profileId), model: $($selected[0].model)"
Write-Host "Jedno wywolanie przetworzy najwyzej NEWS_ENRICHMENT_BATCH_SIZE artykulow."
if ((Read-Host "Przetworzyc jedna partie tytulow i streszczen? Wpisz TAK") -cne "TAK") {
    Write-Host "Anulowano. Bez zmian." -ForegroundColor Yellow
    return
}

# The admin token is entered securely and never placed in CLI args or history.
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
    throw "Partia nie zakonczyla sie poprawnie. Sprawdz logi news-service, profil LLM i stan PostgreSQL."
}
$articles = @(Invoke-RestMethod -Method Get -Uri "$newsUrl/api/news/articles?limit=5" -TimeoutSec 15)
$articles | Select-Object -First 5 title, originalTitle, translationStatus | Format-Table -Wrap
Write-Host "Tytuly po polsku sa dostepne w Alice Web, jesli dla artykulow ustawiono translationStatus=DONE." -ForegroundColor Green
