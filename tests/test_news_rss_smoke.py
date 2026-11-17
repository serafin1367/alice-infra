"""Contract tests for a safe, one-source Alice News RSS smoke import."""
import contextlib
import importlib.util
import io
import unittest
import uuid
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "environments" / "develop" / "news_rss_smoke.py"
spec = importlib.util.spec_from_file_location("news_rss_smoke", SCRIPT)
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)
FEED_ID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
SOURCES = [{"id": FEED_ID, "enabled": True, "name": "BBC Technology",
            "category": "technology", "url": "https://example.com"},
           {"id": str(uuid.uuid4()), "enabled": False, "name": "Disabled",
            "category": "world"}]


class FakeAPI:
    def __init__(self, *, readiness="UP", article_response=None, result=None):
        self.calls = []
        self.readiness = readiness
        self.article_response = [] if article_response is None else article_response
        self.result = result if result is not None else {
            "sourceId": FEED_ID, "source": "BBC Technology", "seen": 3,
            "inserted": 2, "error": None}

    def __call__(self, base, path, *, method="GET", token=None):
        self.calls.append((method, path, token))
        if path == "/actuator/health/readiness":
            return {"status": self.readiness}
        if path.startswith("/api/news/articles"):
            return self.article_response
        if path == "/api/news/sources":
            return SOURCES
        if path == "/api/news/admin/import/" + FEED_ID:
            return self.result
        raise AssertionError((method, path))

    @property
    def posts(self):
        return [call for call in self.calls if call[0] == "POST"]


def call(api, *, answers=("1", "TAK"), secret="local-secret", **kwargs):
    prompts = iter(answers)
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        return smoke.run(input_fn=lambda msg: next(prompts),
                         secret_fn=lambda msg: secret, request_fn=api, **kwargs)


class NewsRssSmokeTest(unittest.TestCase):
    def test_accepts_only_loopback_http_with_explicit_port(self):
        self.assertEqual("http://127.0.0.1:19090",
                         smoke.validate_base_url("http://127.0.0.1:19090/"))
        for url in ("https://127.0.0.1:19090", "http://example.com:19090",
                    "http://127.0.0.1", "http://user:pass@localhost:19090",
                    "http://localhost:19090/proxy", "http://localhost:19090?token=secret"):
            with self.subTest(url=url), self.assertRaises(smoke.SmokeError):
                smoke.validate_base_url(url)

    def test_redirects_are_not_followed_with_admin_token(self):
        self.assertIsNone(smoke.NoRedirect().redirect_request(None, None, 302,
                                                               "moved", {}, "https://elsewhere/"))

    def test_list_is_readonly_and_does_not_request_token(self):
        api = FakeAPI()
        self.assertEqual(0, call(api, list_only=True, answers=()))
        self.assertEqual([], api.posts)

    def test_imports_exactly_one_explicitly_confirmed_source(self):
        api = FakeAPI()
        self.assertEqual(0, call(api))
        self.assertEqual([("POST", "/api/news/admin/import/" + FEED_ID, "local-secret")], api.posts)
        self.assertTrue(all(token is None for method, path, token in api.calls if method == "GET"))

    def test_cannot_import_before_articles_endpoint_is_healthy(self):
        api = FakeAPI(article_response={"error": "HTTP 500"})
        with self.assertRaises(smoke.SmokeError):
            call(api)
        self.assertEqual([], api.posts)

    def test_cannot_import_when_readiness_is_down(self):
        api = FakeAPI(readiness="DOWN")
        with self.assertRaises(smoke.SmokeError):
            call(api)
        self.assertEqual([], api.posts)

    def test_requires_confirmation(self):
        api = FakeAPI()
        with self.assertRaises(smoke.SmokeError):
            call(api, answers=("1", "nie"))
        self.assertEqual([], api.posts)

    def test_rejects_unknown_source_uuid(self):
        api = FakeAPI()
        with self.assertRaises(smoke.SmokeError):
            call(api, source_id=str(uuid.uuid4()), answers=())
        self.assertEqual([], api.posts)

    def test_rejects_blank_token(self):
        api = FakeAPI()
        with self.assertRaises(smoke.SmokeError):
            call(api, secret="  ")
        self.assertEqual([], api.posts)

    def test_feed_errors_return_failure_code(self):
        api = FakeAPI(result={"sourceId": FEED_ID, "source": "BBC", "seen": 3,
                              "inserted": 1, "error": "Failed to persist 2 of 3 articles"})
        self.assertEqual(1, call(api))

    def test_no_items_returns_incomplete_code(self):
        api = FakeAPI(result={"sourceId": FEED_ID, "source": "BBC", "seen": 0,
                              "inserted": 0, "error": None})
        self.assertEqual(2, call(api))

    def test_dedup_is_not_reported_as_failure(self):
        api = FakeAPI(result={"sourceId": FEED_ID, "source": "BBC", "seen": 3,
                              "inserted": 0, "error": None})
        self.assertEqual(0, call(api))

    def test_invalid_counters_are_rejected(self):
        api = FakeAPI(result={"sourceId": FEED_ID, "source": "BBC", "seen": 2,
                              "inserted": 9, "error": None})
        with self.assertRaises(smoke.SmokeError):
            call(api)

    def test_import_id_must_match_selected_source(self):
        api = FakeAPI(result={"sourceId": str(uuid.uuid4()), "seen": 3,
                              "inserted": 2, "error": None})
        with self.assertRaises(smoke.SmokeError):
            call(api)


if __name__ == "__main__":
    unittest.main()
