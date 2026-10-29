# ALICE GitHub → GitLab Sync v1.0

Bezpieczna, jednokierunkowa synchronizacja gałęzi `main` z GitHuba (źródło prawdy) do projektów GitLab. **Nie używa `--force`, nie usuwa gałęzi i nie nadpisuje rozbieżnej historii.** Tryb domyślny to dry-run.

## Przygotowanie

Wymaga Python 3.10+, Git, dostępu do GitHuba i GitLaba (w tym prywatnych repozytoriów) przez **Git credential helper** lub osobne, odpowiednio ograniczone klucze SSH. Skrypt nie przyjmuje tokenów w adresach. Konto GitLab musi mieć prawo push do `main`. Jeżeli gałąź jest chroniona, skonfiguruj uprawnienia zgodnie z polityką projektu; nie wyłączaj ochrony tylko dla tego skryptu.

Zweryfikuj mapowanie w [config/github-gitlab-projects.json](../config/github-gitlab-projects.json). Nazwy widoczne w interfejsie GitLab (`Media`, `Browser Extension`, `Node`) **mogą różnić się od rzeczywistych ścieżek URL (slug)**. Zanim uruchomisz `--apply`, skoryguj pola `gitlab` na podstawie **Clone → HTTPS** każdego projektu. Nie zgaduj slugów. Mapowanie jest wstępne na podstawie listy projektów; konieczna jest walidacja.

## Uruchomienie

```bash
python3 scripts/github-gitlab-sync.py
python3 scripts/github-gitlab-sync.py --only alice-microservices-smarthome
python3 scripts/github-gitlab-sync.py --apply --only alice-microservices-smarthome
python3 scripts/github-gitlab-sync.py --apply
```

Wynik zapisuje się w `reports/github-gitlab-sync.json` (ignorowane przez Git): data UTC, SHA źródła i celu, status `UP_TO_DATE`, `WOULD_UPDATE`, `UPDATED`, `DIVERGED`, `ERROR`. Wywołanie z `--apply` może uruchomić pipeline GitLaba. W razie błędu dostępu do GitHuba/GitLaba synchronizacja repozytorium jest pomijana, a proces kończy się kodem niezerowym.

## Automatyzacja

Po ręcznym sprawdzeniu mapowania, uprawnień i dry-run można uruchamiać narzędzie cyklicznie z dedykowanego hosta lub harmonogramu CI z minimalnymi uprawnieniami. Nie zapisuj tokenów w pliku JSON, URL Git ani logach. Przy automatyzacji pilnuj, by jednocześnie działał tylko jeden proces synchronizacji.

**Uwaga:** `work` jest uwzględniony jako dodatkowy, osiemnasty projekt. Mapowanie opiera się na obecnej inwentaryzacji, a nie na potwierdzonych URL Clone wszystkich projektów.
