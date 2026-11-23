"""Kontrakt wdrożeniowy Alice Speech bez wykonywania zmian na serwerze."""
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


class SpeechComposeContractTest(unittest.TestCase):
    def test_dev_and_prod_have_opt_in_secured_speech_service(self):
        for env in ("develop", "production"):
            with self.subTest(env=env):
                basedir = ROOT / "environments" / env
                stack = yaml.safe_load((basedir / "docker-compose.yml").read_text(encoding="utf-8"))
                services = stack["services"]
                speech = services["speech-service"]
                web = services["alice-web"]
                self.assertEqual(speech["profiles"], ["speech"])
                self.assertEqual(speech["build"]["context"], "../../../microservices/speech")
                self.assertEqual(speech["hostname"], "speech-service")
                self.assertIn("speech_data:/data", speech["volumes"])
                self.assertNotIn("ports", speech, "Speech HTTP port must remain Compose-private")
                self.assertEqual(speech["environment"]["SPEECH_HTTP_HOST"], "0.0.0.0")
                self.assertEqual(speech["environment"]["SPEECH_DATA_DIR"], "/data/jobs")
                self.assertIn("SPEECH_API_TOKEN", speech["environment"])
                self.assertIn("RABBITMQ_USERNAME", speech["environment"])
                self.assertIn("RABBITMQ_PASSWORD", speech["environment"])
                self.assertIn("rabbitmq", speech["depends_on"])
                self.assertIn("healthcheck", speech)
                self.assertIn("speech_data", stack["volumes"])
                self.assertEqual(web["environment"]["SPEECH_UPSTREAM"],
                                 "${ALICE_WEB_SPEECH_UPSTREAM:-http://speech-service:8098}")
                self.assertEqual(web["environment"]["SPEECH_GATEWAY_TOKEN"],
                                 "${SPEECH_API_TOKEN:-}")
                dotenv = (basedir / ".env.example").read_text(encoding="utf-8")
                self.assertIn("# COMPOSE_PROFILES=speech", dotenv)
                self.assertIn("SPEECH_API_TOKEN=", dotenv)

    def test_production_script_only_provisions_speech_when_enabled(self):
        source = (ROOT / "environments/production/deploy-production.sh").read_text(encoding="utf-8")
        self.assertIn('speech_enabled=0', source)
        self.assertIn('COMPOSE_PROFILES', source)
        self.assertIn('SPEECH_API_TOKEN', source)
        self.assertIn('REPOSITORIES+=("$WORKSPACE_DIR/microservices/speech")', source)
        self.assertIn('https://github.com/serafin1367/alice-speech-service.git', source)
        commands = [line.strip() for line in source.splitlines()
                    if line.strip().startswith("docker compose")]
        self.assertFalse(any("down -v" in command for command in commands))


if __name__ == "__main__":
    unittest.main()
