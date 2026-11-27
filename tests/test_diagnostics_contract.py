import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class DiagnosticsContractTests(unittest.TestCase):
    def test_collector_exists_and_is_read_only(self):
        source = (ROOT / "services/diagnostics/server.js").read_text()
        self.assertIn("'/api/diagnostics/status'", source)
        self.assertIn("req.method!=='GET'", source)
        self.assertIn("'Cache-Control':'no-store'", source)
        self.assertIn("AbortSignal.timeout(2500)", source)
        self.assertIn("r.ok", source)

    def test_docker_socket_not_mounted(self):
        for environment in ("develop", "production"):
            compose = (ROOT / f"environments/{environment}/docker-compose.yml").read_text()
            self.assertIn('profiles: ["diagnostics"]', compose)
            self.assertIn("DIAGNOSTICS_UPSTREAM:", compose)
            self.assertNotIn("- /var/run/docker.sock:", compose)
            self.assertIn("context: ../../services/diagnostics", compose)

    def test_collector_has_no_browser_exposed_port(self):
        for environment in ("develop", "production"):
            compose = (ROOT / f"environments/{environment}/docker-compose.yml").read_text()
            block = compose.split("  diagnostics-service:", 1)[1].split("\n  rabbitmq:", 1)[0]
            self.assertIn("expose:", block)
            self.assertNotIn("\n    ports:", block)

    def test_collector_uses_nonroot_runtime(self):
        dockerfile = (ROOT / "services/diagnostics/Dockerfile").read_text()
        self.assertIn("USER node", dockerfile)
        self.assertIn('CMD ["node", "server.js"]', dockerfile)


if __name__ == "__main__":
    unittest.main()
