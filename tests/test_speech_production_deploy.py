"""Offline safety contract for targeted production Speech rollout (no real Docker)."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROD = ROOT / "environments" / "production"
TARGET = PROD / "deploy-speech-production.sh"
LEGACY = PROD / "deploy-production.sh"


class SpeechProductionDeployTests(unittest.TestCase):
    def test_targeted_scope_and_backup_before_restart(self):
        source = TARGET.read_text(encoding="utf-8")
        self.assertTrue(source.startswith("#!/usr/bin/env bash"))
        self.assertIn('MODE=check', source)
        self.assertIn('COMPOSE_PROFILES', source)
        self.assertIn('SPEECH_API_TOKEN', source)
        self.assertIn('flock -n 9', source)
        self.assertIn('docker volume inspect "$VOLUME"', source)
        self.assertIn('docker run --rm --network none --read-only', source)
        self.assertIn('-v "$VOLUME:/source:ro"', source)
        self.assertIn('compose build speech-service alice-web', source)
        self.assertIn('compose up -d --no-deps --wait --wait-timeout 120 speech-service', source)
        self.assertIn('compose up -d --no-deps --wait --wait-timeout 120 alice-web', source)
        self.assertLess(source.index('docker run --rm --network none --read-only'),
                        source.index('compose build speech-service alice-web'))
        self.assertLess(source.index('compose build speech-service alice-web'),
                        source.index('compose up -d --no-deps --wait --wait-timeout 120 speech-service'))
        self.assertNotIn('down -v', source.split('update_repo() {')[1].split('compose ps speech-service alice-web')[0])
        self.assertNotIn('compose build postgres', source)
        self.assertNotIn('compose up -d postgres', source)
        self.assertNotIn('compose up -d rabbitmq', source)
        self.assertIn('http://127.0.0.1/api/speech/tts/history?limit=1', source)

    def test_general_production_script_is_not_truncated_or_repeated(self):
        text = LEGACY.read_text(encoding="utf-8")
        self.assertEqual(text.count('Walidacja konfiguracji Docker Compose'), 1)
        self.assertEqual(text.count('for repository in "${REPOSITORIES[@]}"; do'), 1)
        self.assertIn("grep -Eq '^HEALTH_INTERNAL_TOKEN=.+$'", text)
        self.assertIn("grep -Eq '^SPEECH_API_TOKEN=.{32,}$'", text)
        self.assertIn('REPOSITORIES+=("$WORKSPACE_DIR/microservices/speech")', text)
        self.assertNotIn("'^HEALTH_INTERNAL_TOKEN=.+\\n", text)
        self.assertNotIn('down -v', text.split('for repository in "${REPOSITORIES[@]}"; do')[1])

    def test_scheduled_backup_includes_speech_history_when_worker_service_runs(self):
        backup = (PROD / "backup-production.sh").read_text(encoding="utf-8")
        self.assertIn('SPEECH_ID="$(compose ps -q speech-service', backup)
        self.assertIn('docker cp "${SPEECH_ID}:/data/."', backup)
        self.assertIn('"${STAGING_DIR}/docker/speech-data/"', backup)
        self.assertIn('speech_data', (PROD / "docker-compose.yml").read_text(encoding="utf-8"))

    @unittest.skipUnless(shutil.which("bash"), "Bash is unavailable")
    def test_syntax_and_help_are_safe_offline(self):
        for script in [TARGET, LEGACY]:
            syntax = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
            self.assertEqual(syntax.returncode, 0, syntax.stderr)
        help_result = subprocess.run(["bash", str(TARGET), "--help"], capture_output=True, text=True)
        self.assertEqual(help_result.returncode, 0, help_result.stderr)
        self.assertIn('--check', help_result.stdout)
        self.assertIn('--deploy', help_result.stdout)

    @unittest.skipUnless(shutil.which("bash"), "Bash is unavailable")
    def test_preflight_does_not_change_real_services_or_git(self):
        with tempfile.TemporaryDirectory(prefix="alice-speech-prod-test-") as temp:
            base = Path(temp)
            production = base / "infra" / "environments" / "production"
            production.mkdir(parents=True)
            dest = production / TARGET.name
            shutil.copy2(TARGET, dest)
            (production / "docker-compose.yml").write_text("services: {}\n", encoding="utf-8")
            (production / ".env").write_text(
                "COMPOSE_PROFILES=speech\nSPEECH_API_TOKEN=" + "a" * 40 + "\n",
                encoding="utf-8")
            bin_dir = base / "bin"
            bin_dir.mkdir()
            docker = bin_dir / "docker"
            docker.write_text(
                "#!/bin/sh\n"
                'printf "%s\\n" "$*" >> "$ALICE_PROD_TEST_CALLS"\n'
                'if [ "$1" = info ]; then exit 0; fi\n'
                'case " $* " in\n'
                '  *" config --quiet "*) exit 0 ;;\n'
                '  *" ps --status running --services rabbitmq "*) echo rabbitmq; exit 0 ;;\n'
                'esac\n'
                'exit 66\n', encoding="utf-8")
            docker.chmod(0o755)
            git = bin_dir / "git"
            git.write_text("#!/bin/sh\nexit 99\n", encoding="utf-8")
            git.chmod(0o755)
            called = base / "calls"
            env = {**os.environ, "PATH": str(bin_dir) + os.pathsep + os.environ.get("PATH", ""),
                   "ALICE_PROD_TEST_CALLS": str(called)}
            run = subprocess.run(["bash", str(dest), "--check"], env=env, cwd=base,
                                 capture_output=True, text=True, timeout=15)
            self.assertEqual(run.returncode, 0, run.stdout + "\n" + run.stderr)
            invoked = called.read_text(encoding="utf-8")
            self.assertIn(" config --quiet", invoked)
            self.assertIn(" ps --status running --services rabbitmq", invoked)
            self.assertNotIn(" up ", invoked)
            self.assertNotIn(" build ", invoked)
            self.assertNotIn(" volume ", invoked)
            (production / ".env").write_text("COMPOSE_PROFILES=speech\nSPEECH_API_TOKEN=bad\n",
                                              encoding="utf-8")
            failed = subprocess.run(["bash", str(dest), "--check"], env=env, cwd=base,
                                    capture_output=True, text=True, timeout=15)
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn("SPEECH_API_TOKEN", failed.stderr)


if __name__ == "__main__":
    unittest.main()
