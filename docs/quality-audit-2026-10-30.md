# AliceAI — audyt rzeczywistego zakresu testów CI (etap 1)

Data odczytu: 2026-10-30. Zakres: 16 repozytoriów ze statusem `success` w `alice-ci-reports/index.json` (odczyt `2026-10-29T23:06:05Z`).

**Metoda:** odczyt `.gitlab-ci.yml` na gałęzi domyślnej GitHub; wybrane skrypty i manifesty. Nie pobierano pełnych artefaktów JUnit, nie liczono uruchomionych testów i nie uruchamiano nowych jobów. `success` oznacza sukces pipeline, NIE potwierdza liczby testów ani jakości integracji.

| Projekt (GitLab) | Mechanizm widoczny w CI | Ocena / potrzebny dowód |
| --- | --- | --- |
| Node | Maven `test`, potem `package`, publikacja JUnit | Testy wywoływane; odczytać liczbę testów z Surefire |
| microservices/node-manager | `npm run test:ci` (Node test runner, JUnit) | Uruchamiane testy; policzyć przypadki |
| alice-web | Docker build Vite + obraz Nginx | **P1: brak jawnego test runnera w CI**; tylko walidacja build |
| desktop | `compileall`; unittest tylko przy katalogu `tests` | **P1: brak katalogu `tests` nie zatrzymuje CI**; wykazać wykonanie testów |
| microservices/dashboard | `quality/run-tests.sh` + Docker smoke | Uruchamiane skrypty; zebrać JUnit i smoke |
| microservices/budget | Maven `clean test` i `clean verify` | Testy wywoływane; liczba przypadków i testy integracyjne do sprawdzenia |
| microservices/mail | Maven `verify`, JUnit Surefire/Failsafe | Testy wywoływane; policzyć |
| microservices/llm | Maven `verify`, JUnit Surefire/Failsafe | Testy wywoływane; policzyć |
| microservices/health | Maven `clean verify` z tymczasowym PostgreSQL | Środowisko izolowane; policzyć testy integracyjne |
| microservices/shop | Maven `clean verify` z Docker/Testcontainers | Sprawdzić rzeczywiste testy i izolację |
| microservices/knowledge | Maven `verify` + konkretne testy PostgreSQL | Sprawdzić liczbę przypadków i rozdział jobów |
| microservices/Media | Maven `clean verify`, Surefire | Sprawdzić liczbę testów; Failsafe nie jest deklarowany w artefaktach |
| microservices/smarthome | `quality/run-tests.sh` + Docker smoke | Zebrać JUnit i smoke |
| microservices/time_coordinator | `scripts/ci-test.sh`, izolowane PostgreSQL i RabbitMQ | Sprawdzić JUnit, liczbę przypadków i scenariusze awarii |
| microservices/weather | Maven `test`, `package`, budowanie/push obrazu | Policzyć testy oraz smoke obrazu |
| microservices/work | Maven `clean verify` w obu etapach | Testy uruchamiane dwukrotnie; zweryfikować potrzebę redundancji |

## Wstępne priorytety
- **P1 / alice-web:** włączyć właściwe testy aplikacji (nie traktować build jako testów).
- **P1 / desktop:** jawnie oznaczać `not-tested`, kiedy nie ma testów; docelowo testy niezależne od Windows i oddzielny runner Windows do pakowania.
- **P1 / wszystkie 16:** zebrać i zweryfikować liczbę uruchomionych testów (w tym 0), błędów i pominiętych przypadków, najlepiej automatycznie przez raporty JUnit lub równoważne.
- **P2 / work:** ocenić powtórne `clean verify` i zoptymalizować CI bez obniżenia pokrycia.
- **P2 / wszystkie:** zestawić testy integracyjne, retry, timeout, healthcheck i testy odtwarzania po awarii z architekturą Proxmox + Docker.

## Następna partia dowodów
Zebrać raporty testowe konkretnych commitów, listę rzeczywistych przypadków testowych i ich wyniki. Ustalić minimalne kryteria: żaden projekt aplikacyjny nie uzyskuje pełnego `Tests Verified` bez potwierdzonych przypadków; brak testów jest raportowany oddzielnie. Dopiero po tym wprowadzać zmiany w kodzie.


## Aktualizacja po audycie — 30.10.2026

Powyższa tabela jest **historycznym stanem audytu przed naprawami**; nie należy traktować dwóch wpisów P1 jako nadal otwartych problemów konfiguracji.

- **Alice Web**: na gałęzi głównej potwierdzono etap `test` z `node --test tests/*.test.mjs`; według rozmowy wdrożono trzy testy kontrolne. Zakres nie jest jeszcze testem end-to-end ani integracją z mikroserwisami.
- **Alice Desktop**: na gałęzi głównej potwierdzono, że brak katalogu `tests` powoduje błąd, a obecny etap uruchamia `unittest discover`; według rozmowy wdrożono trzy testy kontrolne. Brakuje testów GUI Windows i potwierdzenia pakowania EXE.
- **Alice Infra**: CI sprawdza YAML oraz główne pliki Docker Compose; nie wdraża usług.
- **Status raportowany**: po synchronizacji CI wszystkie 17 repozytoriów miały `success`, ale liczba rzeczywiście wykonanych testów, pełne artefakty JUnit i scenariusze integracyjne nie zostały jeszcze niezależnie zweryfikowane w tym audycie.

**Kolejne działania:** zebrać liczbę testów z artefaktów, ustalić kontrakty i topologię, przygotować macierz testów integracyjnych, wykonywać izolowane smoke, failure/recovery i backup/restore, dokumentować dowody. Zielony pipeline oznacza `CI Passed`, nie `Integration Verified` ani `Production Ready`.


### Decyzja o kolejności testów — 30.10.2026

**Obowiązujący najbliższy etap: wyłącznie testy jednostkowe (Unit Test Gate).** Wcześniej opisany etap testów integracyjnych i odpornościowych jest **odroczony** i nie należy go uruchamiać jako następnego kroku.

Zakres bieżącego etapu: zinwentaryzować testy jednostkowe i odróżnić je od smoke, build, testów infrastrukturalnych oraz integracyjnych; zebrać raporty/liczby testów i przypadki pominięte; wskazać luki; dodać brakujące izolowane testy jednostkowe i egzekwować je w CI. Zależności zewnętrzne zastępować mockami/stubami tam, gdzie to uzasadnione. Testy nie mogą wymagać uruchomionego środowiska Proxmox ani produkcyjnych usług.

Dopiero po potwierdzeniu zakresu i wyników jednostkowych powrócić do planowania integracji. Zielony pipeline lub trzy testy kontrolne nie świadczą o kompletnym pokryciu logiki aplikacji.
