# ALICE GitHub → GitLab Sync v1.0

Bezpieczna, jednokierunkowa synchronizacja gałęzi `main` z GitHuba (źródło prawdy) do projektów GitLab. **Nie używa `--force`, nie usuwa gałęzi i nie nadpisuje rozbieżnej historii.** Bez `--dry-run` synchronizator Python wykonuje synchronizację (apply); przed pierwszym użyciem zalecany jest dry-run.

## Przygotowanie

Wymaga Python 3.10+, Git, dostępu do GitHuba i GitLaba (w tym prywatnych repozytoriów) przez **Git credential helper** lub osobne, odpowiednio ograniczone klucze SSH. Skrypt nie przyjmuje tokenów w adresach. Konto GitLab musi mieć prawo push do `main`. Jeżeli gałąź jest chroniona, skonfiguruj uprawnienia zgodnie z polityką projektu; nie wyłączaj ochrony tylko dla tego skryptu.

Zweryfikuj mapowanie w [config/github-gitlab-projects.json](../config/github-gitlab-projects.json). Nazwy widoczne w interfejsie GitLab (`Media`, `Browser Extension`, `Node`) **mogą różnić się od rzeczywistych ścieżek URL (slug)**. Zanim uruchomisz `--apply`, skoryguj pola `gitlab` na podstawie **Clone → HTTPS** każdego projektu. Nie zgaduj slugów. Mapowanie jest wstępne na podstawie listy projektów; konieczna jest walidacja.

## Uruchomienie

```bash
python3 scripts/github-gitlab-sync.py --dry-run
python3 scripts/github-gitlab-sync.py --dry-run --only alice-microservices-smarthome
python3 scripts/github-gitlab-sync.py --apply --only alice-microservices-smarthome
python3 scripts/github-gitlab-sync.py --apply
```

Wynik zapisuje się w `reports/github-gitlab-sync.json` (ignorowane przez Git): data UTC, SHA źródła i celu, status `UP_TO_DATE`, `WOULD_UPDATE`, `UPDATED`, `DIVERGED`, `ERROR`. Wywołanie z `--apply` może uruchomić pipeline GitLaba. W razie błędu dostępu do GitHuba/GitLaba synchronizacja repozytorium jest pomijana, a proces kończy się kodem niezerowym.

## Równoległa synchronizacja

Każde repozytorium jest obsługiwane w osobnym katalogu tymczasowym przez pulę wątków. Domyślnie są to **4 równoległe zadania**; parametr `--workers N` pozwala ustawić od 1 do 16. JSON zachowuje kolejność projektów z mapy, niezależnie od kolejności zakończenia. Tryb podglądu wymaga jawnego `--dry-run`.

```bash
python3 scripts/github-gitlab-sync.py --workers 4
python3 scripts/github-gitlab-sync.py --workers 8 --apply
```

Nie uruchamiaj dwóch niezależnych procesów synchronizacji jednocześnie. Przy wielu projektach zacznij od 4 wątków, aby nie obciążać GitLaba nadmierną liczbą połączeń. Zwiększ do 8 dopiero po poprawnych testach. W raporcie JSON zapisywana jest też liczba workerów.

## Linux — skrypt `scripts/sync.sh` (2026-11-26)

Skrypt `sync.sh` jest długotrwale działającym opakowaniem
`scripts/l-github-gitlab-sync.py` (wariant **SSH do GitHuba**).
Ścieżki do programu i pliku `config/github-gitlab-projects.json`
wyznaczane są względem lokalizacji skryptu, nie bieżącego katalogu.
Wymaga Bash, `python3`, `git`, `flock`, dostępu SSH do GitHuba,
dostępu do GitLaba oraz poprawnych uprawnień repozytoriów.

Domyślnie uruchamia 8 równoległych synchronizacji, wykonuje
`--apply`, a po **zakończeniu** przebiegu czeka 100 sekund.
Nie uruchamia kolejnego przebiegu w czasie poprzedniego,
nie stosuje force-push i nie nadpisuje rozbieżnej historii.
`flock` zakłada blokadę w prywatnym katalogu runtime/cache
(`$XDG_RUNTIME_DIR` lub `$HOME/.cache/alice-infra`).
Druga instancja na tym samym koncie/hoście kończy się błędem.

Przykłady uruchomienia (z dowolnego katalogu; do pliku nie potrzeba
bitu wykonywalności):

```bash
bash scripts/sync.sh --once --dry-run
bash scripts/sync.sh --once --only alice-speech-service --only alice-web
bash scripts/sync.sh --interval 300 --workers 4
bash scripts/sync.sh --once --no-collect-ci
```

Można ustawić `ALICE_SYNC_INTERVAL_SECONDS` (co najmniej 10),
`ALICE_SYNC_WORKERS` (1–16) i `ALICE_SYNC_LOCK_FILE`.
Opcja `--dry-run` działa zawsze tylko w jednym przebiegu, bez
push i publikacji raportów. `--once` zwraca kod synchronizatora;
w pętli błąd jest logowany, po czym kolejny przebieg następuje
po interwale. Pozwala to odzyskać działanie po przejściowych
problemach z dostępem do GitHuba lub GitLaba, bez ukrywania awarii.

Mapa zawiera teraz również
`alice-speech-service` → `alice/microservices/speech`,
dzięki czemu zmiany P6 (historia nagrań) są objęte normalną
synchronizacją. Uruchomienie synchronizacji to **przesyłanie kodu
i potencjalne wyzwolenie CI, nie wdrożenie kontenerów**.

**Ochrona dostępu:** sekretów nie zapisuj w skrypcie ani w URL.
Publikacja raportów CI może wymagać `GITLAB_TOKEN`;
jeśli chcesz synchronizować tylko kod, użyj `--no-collect-ci`.
Nie uruchamiaj drugiej instancji przez cron lub systemd, gdy
pierwsza już działa. Blokada dotyczy jednego hosta/konta;
GitLab w dalszym ciągu egzekwuje reguły fast-forward.

## Automatyzacja

Po ręcznym sprawdzeniu mapowania, uprawnień i dry-run można uruchamiać narzędzie cyklicznie z dedykowanego hosta lub harmonogramu CI z minimalnymi uprawnieniami. Nie zapisuj tokenów w pliku JSON, URL Git ani logach. Przy automatyzacji pilnuj, by jednocześnie działał tylko jeden proces synchronizacji.

**Uwaga:** mapa obejmuje obecnie 20 projektów, w tym `work`, `news` i `alice-speech-service`. Przed pierwszą synchronizacją nowej instalacji zweryfikuj pozostałe adresy GitLab na podstawie Clone URL.
