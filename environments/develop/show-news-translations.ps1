[CmdletBinding()]
param(
    [ValidateRange(1, 20)]
    [int]$Limit = 5
)

$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Brak prywatnego pliku .env w katalogu DEV."
}
$compose = @("compose", "--project-directory", $PSScriptRoot,
             "--env-file", $envFile, "-f", (Join-Path $PSScriptRoot "docker-compose.yml"))

# SQL is a fixed, read-only query. Limit is validated as an integer.
# ASCII source keeps the script compatible with Windows PowerShell 5.1.
$sql = @'
\pset pager off
\x on
SELECT enriched_at AS data_tlumaczenia,
       title AS tytul_oryginalny,
       title_pl AS tytul_polski,
       summary_pl AS streszczenie_polskie,
       importance_score AS ocena_ai,
       importance_reason AS uzasadnienie_ai
FROM news_article
WHERE language = 'en'
  AND translation_status = 'DONE'
  AND enrichment_status = 'DONE'
  AND title_pl IS NOT NULL
  AND summary_pl IS NOT NULL
ORDER BY enriched_at DESC NULLS LAST, created_at DESC
LIMIT __LIMIT__;
'@
$sql = $sql.Replace("__LIMIT__", [string]$Limit)

Write-Host ("Alice NEWS - ostatnie {0} zapisanych tlumaczen (tylko do odczytu)." -f $Limit) -ForegroundColor Cyan
# Explicit UTF-8 for Polish output where the terminal supports it.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$sql | & docker @compose exec -T postgres sh -c 'exec psql -X -v ON_ERROR_STOP=1 -U "$NEWS_DB_USERNAME" -d "$NEWS_DB_NAME" -f -'
if ($LASTEXITCODE -ne 0) {
    throw "Nie mozna odczytac tlumaczen z bazy news."
}
Write-Host "Nie wykonano tlumaczenia ani modyfikacji bazy." -ForegroundColor Green
