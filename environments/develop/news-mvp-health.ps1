[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path -LiteralPath $envFile)) { throw "Brak prywatnego pliku .env w DEV." }
$base = @("compose", "--project-directory", $PSScriptRoot,
    "--env-file", $envFile, "-f", (Join-Path $PSScriptRoot "docker-compose.yml"))
$sql = @'
\pset pager off
\echo === ALICE NEWS MVP: RSS OSTATNIE 24H ===
SELECT status, COUNT(*) AS uruchomienia,
       COALESCE(SUM(items_seen),0) AS przegladane,
       COALESCE(SUM(items_inserted),0) AS nowe_wiadomosci
FROM news_import_run WHERE started_at >= now() - INTERVAL '24 hours'
GROUP BY status ORDER BY status;

\echo === ALICE NEWS MVP: TLUMACZENIA OSTATNIE 24H ===
SELECT COUNT(*) FILTER (WHERE language='en' AND enrichment_status='DONE'
                         AND enriched_at >= now() - INTERVAL '24 hours') AS en_przetlumaczone_24h,
       COUNT(*) FILTER (WHERE language='en' AND enrichment_status='PENDING') AS en_oczekujace,
       COUNT(*) FILTER (WHERE language='en' AND enrichment_status='FAILED') AS en_bledy,
       COUNT(*) FILTER (WHERE language='en' AND enrichment_status='PROCESSING') AS en_w_trakcie,
       COUNT(*) FILTER (WHERE language='en' AND enrichment_status='FAILED'
                         AND enrichment_attempts >= 3) AS en_wyczerpane_proby
FROM news_article;

\echo === ALICE NEWS MVP: STATUS ZRODEL RSS ===
SELECT name AS zrodlo, refresh_minutes AS interwal_minut,
       last_fetch_status AS status,
       fetch_failures AS kolejne_bledy,
       last_fetched_at AS ostatnie_pobranie,
       next_fetch_at AS nastepna_proba
FROM news_source
WHERE enabled AND archived_at IS NULL AND source_type='RSS'
ORDER BY name;
'@
Write-Host "Alice NEWS MVP - podsumowanie 24h (tylko do odczytu)." -ForegroundColor Cyan
foreach ($name in @("NEWS_RSS_ENABLED", "NEWS_ENRICHMENT_ENABLED",
                    "NEWS_ENRICHMENT_BATCH_SIZE", "NEWS_ENRICHMENT_INTERVAL_MS",
                    "NEWS_RETENTION_CLEANUP_ENABLED")) {
    $value = & docker @base exec -T news-service printenv $name
    if ($LASTEXITCODE -ne 0) { throw "Nie mozna odczytac $name z News." }
    Write-Host ("{0}={1}" -f $name, ([string](@($value)[-1])).Trim())
}
$sql | & docker @base exec -T postgres sh -c 'exec psql -X -v ON_ERROR_STOP=1 -U "$NEWS_DB_USERNAME" -d "$NEWS_DB_NAME" -f -'
if ($LASTEXITCODE -ne 0) { throw "Nie udalo sie pobrac statystyk z PostgreSQL." }
Write-Host "Kontrola zakonczona bez modyfikacji danych." -ForegroundColor Green
