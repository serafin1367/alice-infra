"""Static DEV integration checks for Alice News (no Docker/DB required)."""
import unittest
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]
DEV = ROOT / "environments" / "develop"


class NewsDevContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.compose = yaml.safe_load((DEV / "docker-compose.yml").read_text(encoding="utf-8"))
        cls.services = cls.compose["services"]
        cls.env_example = (DEV / ".env.example").read_text(encoding="utf-8")
        cls.news = cls.services["news-service"]

    def test_news_uses_sibling_checkout_and_nonpublic_port(self):
        self.assertEqual("../../../microservices/news", self.news["build"]["context"])
        self.assertEqual(['127.0.0.1:${NEWS_PUBLIC_PORT:-19090}:8080'], self.news["ports"])
        self.assertEqual("news-service", self.news["hostname"])

    def test_news_uses_shared_postgres_and_rabbitmq(self):
        self.assertEqual("service_healthy", self.news["depends_on"]["postgres"]["condition"])
        self.assertEqual("service_healthy", self.news["depends_on"]["rabbitmq"]["condition"])
        self.assertIn("jdbc:postgresql://postgres:5432/", self.news["environment"]["DB_URL"])
        self.assertEqual("rabbitmq", self.news["environment"]["RABBITMQ_HOST"])
        self.assertIn("NEWS_DB_NAME", self.services["postgres"]["environment"])
        self.assertIn("NEWS_DB_USERNAME", self.services["postgres"]["environment"])
        self.assertIn("NEWS_DB_PASSWORD", self.services["postgres"]["environment"])
        self.assertEqual(
            self.news["environment"]["DB_PASSWORD"],
            self.services["postgres"]["environment"]["NEWS_DB_PASSWORD"]
        )

    def test_alice_web_uses_internal_news_gateway(self):
        web = self.services["alice-web"]
        self.assertEqual(
            "${ALICE_WEB_NEWS_UPSTREAM:-http://news-service:8080}",
            web["environment"]["NEWS_UPSTREAM"]
        )
        self.assertIn("ALICE_WEB_NEWS_UPSTREAM=http://news-service:8080", self.env_example)
        self.assertEqual(
            "${ALICE_WEB_BIND_IP:-127.0.0.1}:${ALICE_WEB_PUBLIC_PORT:-19080}:80",
            web["ports"][0]
        )
        self.assertIn("ALICE_WEB_BIND_IP=127.0.0.1", self.env_example)
        # Same private token is injected only at the trusted Nginx gateway.
        self.assertEqual("${NEWS_ADMIN_TOKEN:-}",
                         web["environment"]["NEWS_GATEWAY_ADMIN_TOKEN"])
        self.assertEqual(web["environment"]["NEWS_GATEWAY_ADMIN_TOKEN"],
                         self.news["environment"]["NEWS_ADMIN_TOKEN"])

    def test_background_tasks_require_explicit_opt_in(self):
        self.assertEqual("${NEWS_RSS_ENABLED:-false}",
                         self.news["environment"]["NEWS_RSS_ENABLED"])
        self.assertEqual("${NEWS_ENRICHMENT_ENABLED:-false}",
                         self.news["environment"]["NEWS_ENRICHMENT_ENABLED"])
        self.assertEqual("${NEWS_ENRICHMENT_BATCH_SIZE:-10}",
                         self.news["environment"]["NEWS_ENRICHMENT_BATCH_SIZE"])
        self.assertIn("NEWS_ENRICHMENT_BATCH_SIZE=2", self.env_example)
        self.assertEqual("${NEWS_ADMIN_TOKEN:-}",
                         self.news["environment"]["NEWS_ADMIN_TOKEN"])

    def test_database_bootstrap_and_dev_tools_are_registered(self):
        script = (DEV / "postgres" / "init" / "09-init-news-database.sh").read_text(encoding="utf-8")
        self.assertIn("CREATE ROLE", script)
        self.assertIn("CREATE DATABASE", script)
        self.assertIn("WHERE NOT EXISTS", script)
        self.assertIn("\\gexec", script)
        self.assertIn("NEWS_DB_PASSWORD=", self.env_example)
        self.assertIn("NEWS_PUBLIC_PORT=19090", self.env_example)
        self.assertIn("alice-news-service.git", (DEV / "pull-all.ps1").read_text(encoding="utf-8"))
        self.assertIn('"news-service"', (DEV / "rebuild-all.ps1").read_text(encoding="utf-8"))
        self.assertTrue((DEV / "rebuild-news.ps1").is_file())

    def test_news_web_smoke_targets_existing_alice_web_only(self):
        script = (DEV / "rebuild-news-web.ps1").read_text(encoding="utf-8")
        self.assertIn('Invoke-Compose -ArgsList @("build", "alice-web")', script)
        self.assertIn('"--no-deps", "--force-recreate", "--wait", "alice-web"', script)
        self.assertIn('Assert-Get "$webUrl/news/"', script)
        self.assertIn('Assert-Get "$webUrl/api/news/categories"', script)
        self.assertIn('Assert-Get "$webUrl/api/news/articles?limit=1"', script)
        self.assertIn('Assert-Get "$webUrl/api/news/sources"', script)
        self.assertIn('HTTP $postStatus', script)
        self.assertNotIn("down -v", script)
        self.assertNotIn('/api/news/admin/import', script)

    def test_news_web_verify_only_does_not_rebuild_or_restart(self):
        script = (DEV / "rebuild-news-web.ps1").read_text(encoding="utf-8")
        self.assertIn("[switch]$VerifyOnly", script)
        self.assertIn("if (-not $VerifyOnly -and -not (Test-Path -LiteralPath $webDockerfile))", script)
        # Read-only branch must not issue Compose build/up or News rebuild.
        verify_branch = script.split("if ($VerifyOnly) {", 1)[1].split("} else {", 1)[0]
        self.assertNotIn("Invoke-Compose", verify_branch)
        self.assertNotIn("rebuild-news.ps1", verify_branch)
        # Mutating operations stay solely in the alternate branch.
        rebuild_branch = script.split("} else {", 1)[1].split(
            '    $portResult = & docker @base port alice-web 80', 1)[0]
        self.assertIn('Invoke-Compose -ArgsList @("build", "alice-web")', rebuild_branch)
        self.assertIn('Invoke-Compose -ArgsList @("up", "-d", "--no-deps"', rebuild_branch)
        self.assertIn('if (-not $SkipNewsRebuild)', rebuild_branch)
        # Both paths share the same read-only HTTP validation and diagnostics.
        self.assertIn('Assert-Get "$webUrl/health"', script)
        self.assertIn('Assert-Get "$webUrl/api/news/articles?limit=1"', script)
        self.assertIn('([string]$postStatus).Trim() -ne "403"', script)
        self.assertNotIn("down -v", script)

    def test_polish_title_translation_auto_selects_translator_purpose(self):
        script = (DEV / "enrich-news.ps1").read_text(encoding="utf-8")
        self.assertIn('[switch]$ShowTranslator', script)
        self.assertIn('[Alias("ListProfiles")]', script)
        self.assertIn('api/llm/profiles/purpose/TRANSLATOR', script)
        self.assertIn('$profile.purpose -ne "TRANSLATOR"', script)
        self.assertIn('Read-Host "NEWS_ADMIN_TOKEN" -AsSecureString', script)
        self.assertIn('Wpisz TAK', script)
        self.assertIn('api/news/admin/enrichment', script)
        self.assertIn('translationStatus', script)
        self.assertNotIn("NEWS_LLM_PROFILE_ID", script)
        self.assertNotIn("NEWS_LLM_PROFILE_ID", self.env_example)
        self.assertNotIn("NEWS_LLM_PROFILE_ID", self.news["environment"])
        self.assertNotIn("NEWS_ENRICHMENT_ENABLED=true", script)
        self.assertNotIn("compose up", script)
        self.assertNotIn("rebuild-news", script)

    def test_translation_diagnostics_are_read_only_and_do_not_expose_secrets(self):
        script = (DEV / "diagnose-news-translations.ps1").read_text(encoding="utf-8")
        # Windows PowerShell 5.1 decodes UTF-8 without BOM as a legacy codepage.
        # Smart punctuation (especially a right double quote) can break parsing.
        self.assertTrue(script.isascii(), "Use ASCII-only PowerShell source for PS 5.1")
        self.assertIn('docker @compose exec -T postgres', script)
        self.assertIn('NEWS_DB_USERNAME', script)
        self.assertIn('NEWS_DB_NAME', script)
        self.assertIn('translation_status', script)
        self.assertIn('enrichment_status', script)
        self.assertIn('enrichment_attempts', script)
        self.assertIn("language IN ('und', 'auto')", script)
        self.assertIn('NEWS_ENRICHMENT_ENABLED', script)
        self.assertIn('ON_ERROR_STOP=1', script)
        self.assertNotIn('NEWS_ADMIN_TOKEN', script)
        self.assertNotIn('NEWS_DB_PASSWORD', script)
        self.assertNotIn('enrichment_error', script)
        self.assertNotIn('Read-Host', script)
        self.assertNotIn('Invoke-RestMethod', script)
        self.assertNotIn('UPDATE news_article', script)
        self.assertNotIn('DELETE FROM', script)
        self.assertNotIn('INSERT INTO', script)

    def test_reader_refresh_archive_and_retention_are_safe_on_dev(self):
        env = self.news["environment"]
        self.assertEqual("${NEWS_RSS_ENABLED:-false}", env["NEWS_RSS_ENABLED"])
        self.assertEqual("${NEWS_ACTIVE_DAYS:-7}", env["NEWS_ACTIVE_DAYS"])
        self.assertEqual("${NEWS_RETENTION_DAYS:-90}", env["NEWS_RETENTION_DAYS"])
        self.assertEqual(
            "${NEWS_RETENTION_CLEANUP_ENABLED:-false}",
            env["NEWS_RETENTION_CLEANUP_ENABLED"]
        )
        for line in (
            "NEWS_ACTIVE_DAYS=7",
            "NEWS_RETENTION_DAYS=90",
            "NEWS_RETENTION_CLEANUP_ENABLED=false",
        ):
            self.assertIn(line, self.env_example)
        self.assertIn("NEWS_RSS_ENABLED=false", self.env_example)

    def test_production_compose_not_modified_for_news(self):
        production = (ROOT / "environments" / "production" / "docker-compose.yml").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("news-service:", production)


if __name__ == "__main__":
    unittest.main()
