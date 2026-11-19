[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Brak prywatnego pliku .env w katalogu DEV."
}
$composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
$compose = @("compose", "--project-directory", $PSScriptRoot,
    "--env-file", $envFile, "-f", $composeFile)

# SQL contains no mutations and does not print headlines, URLs, passwords or tokens.
$sql = @'
\pset pager off
\echo === ALICE NEWS: STATUS TLUMACZEN ===
SELECT COALESCE(NULLIF(language, ''), '(brak)') AS jezyk,
       translation_status AS tlumaczenie,
       enrichment_status AS wzbogacanie,
       COUNT(*) AS artykuly
FROM news_article
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

\echo === ALICE NEWS: OSTATNIE 7 DNI ===
SELECT COUNT(*) AS lacznie,
       COUNT(*) FILTER (WHERE language = 'en') AS angielski,
       COUNT(*) FILTER (WHERE language IN ('und', 'auto') OR language IS NULL) AS jezyk_nieustalony,
       COUNT(*) FILTER (WHERE language = 'en' AND translation_status = 'DONE') AS en_przetlumaczone,
       COUNT(*) FILTER (WHERE language = 'en' AND enrichment_status IN ('PENDING', 'FAILED')
                         AND enrichment_attempts < 3) AS en_oczekujace_lub_retry,
       COUNT(*) FILTER (WHERE language = 'en' AND enrichment_status = 'FAILED'
                         AND enrichment_attempts >= 3) AS en_wyczerpane_proby,
       COUNT(*) FILTER (WHERE language = 'en' AND enrichment_status = 'PROCESSING') AS en_w_trakcie
FROM news_article
WHERE created_at >= now() - INTERVAL '7 days';

\echo === ALICE NEWS: ZRODLA Z NIEUSTALONYM JEZYKIEM (7 DNI) ===
SELECT s.name AS zrodlo, s.language AS konfiguracja_jezyka,
       COUNT(*) AS artykuly_z_nieustalonym_jezykiem
FROM news_article a JOIN news_source s ON s.id = a.source_id
WHERE a.created_at >= now() - INTERVAL '7 days'
  AND (a.language IN ('und','auto') OR a.language IS NULL)
GROUP BY s.id, s.name, s.language
ORDER BY artykuly_z_nieustalonym_jezykiem DESC, s.name
LIMIT 20;
'@

Write-Host "Alice NEWS — diagnostyka tylko do odczytu (DEV)." -ForegroundColor Cyan
Write-Host "Kontrola konfiguracji kontenera (bez sekretow):"
$flags = & docker @compose exec -T news-service sh -c 'printf "NEWS_ENRICHMENT_ENABLED=%s\nNEWS_ENRICHMENT_BATCH_SIZE=%s\n" "$NEWS_ENRICHMENT_ENABLED" "$NEWS_ENRICHMENT_BATCH_SIZE"'
if ($LASTEXITCODE -ne 0) { throw "Nie mozna odczytac flag kontenera news-service." }
$flags | ForEach-Object { Write-Host $_ }

Write-Host "Statystyki bazy (bez tytulow artykulow):" -ForegroundColor Cyan
$sql | & docker @compose exec -T postgres sh -c 'exec psql -X -v ON_ERROR_STOP=1 -U "$NEWS_DB_USERNAME" -d "$NEWS_DB_NAME" -f -'
if ($LASTEXITCODE -ne 0) {
    throw "Nie udalo sie odczytac statystyk alice_news. Sprawdz kontener PostgreSQL i migracje Flyway."
}
Write-Host "Gotowe: nie wykonano UPDATE, importu RSS ani wywolania LLM." -ForegroundColor Green
