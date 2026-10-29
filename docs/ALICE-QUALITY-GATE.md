# ALICE Quality Gate — macierz audytu 18 repozytoriów

Źródło: `alice-ci-reports/index.json` (2026-10-29T20:21:36.354214+00:00). Statusy są historycznymi wynikami pipeline'ów, nie bieżącą oceną jakości kodu.

| GitHub | GitLab | Status | Pipeline | Zadanie |
|---|---|---|---|---|
| [alice-infra](https://github.com/serafin1367/alice-infra) | `alice/infra` | unavailable | — | Zweryfikować projekt i CI |
| [alice-node](https://github.com/serafin1367/alice-node) | `alice/Node` | failed | 307 | Zdiagnozować joby i błędy |
| [alice-node-manager](https://github.com/serafin1367/alice-node-manager) | `alice/microservices/node-manager` | failed | 319 | Zdiagnozować joby i błędy |
| [alice-web](https://github.com/serafin1367/alice-web) | `alice/alice-web` | failed | 292 | Zdiagnozować joby i błędy |
| [alice-desktop](https://github.com/serafin1367/alice-desktop) | `alice/desktop` | failed | 279 | Zdiagnozować joby i błędy |
| [alice-browser-extension](https://github.com/serafin1367/alice-browser-extension) | `alice/browser-extension` | unavailable | — | Zweryfikować projekt i CI |
| [alice-microservice-dashboard](https://github.com/serafin1367/alice-microservice-dashboard) | `alice/microservices/dashboard` | failed | 316 | Zdiagnozować joby i błędy |
| [alice-microservice-budget](https://github.com/serafin1367/alice-microservice-budget) | `alice/microservices/budget` | failed | 298 | Zdiagnozować joby i błędy |
| [alice-microservices-mail](https://github.com/serafin1367/alice-microservices-mail) | `alice/microservices/mail` | failed | 328 | Zdiagnozować joby i błędy |
| [alice-microservices-llm](https://github.com/serafin1367/alice-microservices-llm) | `alice/microservices/llm` | failed | 323 | Zdiagnozować joby i błędy |
| [alice-microservices-health](https://github.com/serafin1367/alice-microservices-health) | `alice/microservices/health` | failed | 296 | Zdiagnozować joby i błędy |
| [alice-microservices-shopping](https://github.com/serafin1367/alice-microservices-shopping) | `alice/microservices/shop` | failed | 286 | Zdiagnozować joby i błędy |
| [alice-microservices-knowledge](https://github.com/serafin1367/alice-microservices-knowledge) | `alice/microservices/knowledge` | failed | 324 | Zdiagnozować joby i błędy |
| [alice-microservices-media](https://github.com/serafin1367/alice-microservices-media) | `alice/microservices/Media` | failed | 325 | Zdiagnozować joby i błędy |
| [alice-microservices-smarthome](https://github.com/serafin1367/alice-microservices-smarthome) | `alice/microservices/smarthome` | success | 315 | Zweryfikować testy i raporty |
| [alice-microservices-time_coordinator](https://github.com/serafin1367/alice-microservices-time_coordinator) | `alice/microservices/time_coordinator` | failed | 271 | Zdiagnozować joby i błędy |
| [alice-weather](https://github.com/serafin1367/alice-weather) | `alice/microservices/weather` | failed | 321 | Zdiagnozować joby i błędy |
| [alice-microservices-work](https://github.com/serafin1367/alice-microservices-work) | `alice/microservices/work` | failed | 282 | Zdiagnozować joby i błędy |

## Priorytety

1. **Runner / timeout:** Weather #321 i Node Manager #319 mają joby z `stuck_or_timeout_failure`. Sprawdzić tagi, dostępność runnera i timeouty przed zmianą testów.
2. **Java / Spring:** Mail #328 (`mail-maven-quality`) zgłasza `UnsatisfiedDependencyException` dla `mailController`; LLM #323 (`llm-maven-quality`) zgłasza `script_failure`. Odczytać pełny łańcuch przyczyn i poprawić konfigurację testów.
3. **Braki CI:** zweryfikować konfiguracje i testy w pozostałych repozytoriach, bez założenia, że brak pliku `.gitlab-ci.yml` oznacza brak pipeline'u.
4. **Raportowanie:** ustandaryzować wyniki JUnit/Surefire oraz testów Node i dodać metryki testów do raportów.
5. **Weryfikacja:** ponowić pipeline'y i potwierdzić rezultaty w centralnym `alice-ci-reports`.

## Kryteria ukończenia

- Każdy z 18 projektów ma znany status CI lub udokumentowany wyjątek.
- Każda awaria jest zaklasyfikowana jako runner, konfiguracja, zależności, kod albo test.
- Każdy uruchamialny komponent ma powtarzalny test oraz raport CI.
- Logi z potencjalnymi sekretami pozostają w repozytorium prywatnym i wymagają kontroli dostępu.
