# AliceAI — polityka CI/CD i źródeł prawdy

> Status: obowiązująca decyzja projektowa, 2026-11-08. Właściciel zasad: Alice Infra.

## 1. Podział odpowiedzialności

| System | Odpowiedzialność |
| --- | --- |
| GitHub | Hostowanie kodu źródłowego oraz historia commitów; bez wykonywania CI/CD dla AliceAI. |
| GitLab (gitlab.mbb.net.pl) | **Jedyna platforma wykonująca CI/CD**: pipeline, build, testy, walidacja, kontrola jakości, raportowanie i uprawnione wdrożenia. |
| `alice-ci-reports` | **Jedyne źródło prawdy dla audytów wyników CI/CD**: metryki, wyniki testów, pokrycie, statusy i historia zapisane w raportach z GitLaba. |
| GitLab Issues | Docelowy system zadań; roadmapa R0–R8 w `alice/infra`, zadania komponentów w odpowiednich projektach. |

## 2. Zakaz uruchamiania CI/CD w GitHub

1. Nie uruchamiać GitHub Actions, workflow testowych, buildów, publikacji artefaktów ani deploymentów dla repozytoriów AliceAI — ręcznie, przez API ani automatycznie po `push` lub Pull Request.
2. Administrator każdego repozytorium powinien **wyłączyć Actions w Settings → Actions → General → Actions permissions → Disable actions**. Ustawienie należy sprawdzić i udokumentować; sam niniejszy dokument **nie blokuje** mechanizmu technicznie.
3. Nie dodawać nowych workflow w `.github/workflows/`, nie włączać istniejących i nie konfigurować zewnętrznych workflow uruchamiających CI na GitHubie.
4. Przed zmianami w repozytorium, w którym mogą istnieć aktywne workflow, upewnić się, że Actions są wyłączone; w przeciwnym razie modyfikacja może automatycznie uruchomić workflow.
5. Weryfikacja konfiguracji GitHuba nie zastępuje kontroli innych integracji i webhooków mogących uruchamiać systemy CI.

## 3. Zasady dowodowe audytu

- Odczytywać najnowszy `index.json` w `alice-ci-reports` i — dla problemów — właściwe raporty historyczne.
- Przy każdym wyniku podawać projekt GitLab, commit SHA, datę, pipeline ID, status i pochodzenie metryk.
- `success` oznacza sukces danego pipeline'u, **nie** gotowość produkcyjną ani pełną weryfikację integracji.
- Brak metryk oznaczać `N/A`, nie `0%`; odróżniać błędy testów od błędów infrastruktury.
- Kod źródłowy, README oraz Issues mogą wyjaśniać przyczynę problemu, ale nie zastępują raportu GitLaba jako dowodu wyniku CI.
- Testy integracyjne i odpornościowe pozostają odroczone, zgodnie z decyzją Unit Test Gate z 2026-10-30, dopóki nie zostanie podjęta odrębna decyzja.

## 4. Migracja Issues

1. Eksportować zadania GitHub Issues do odpowiadających im projektów GitLab; centralne R0–R8 do `alice/infra`.
2. Zachować tytuł, treść, etykiety, możliwą do przeniesienia historię, komentarze i URL źródłowy.
3. Wykonać `dry-run`, zweryfikować uprawnienia i kontrolę duplikatów; dopiero potem import.
4. Dopiero po potwierdzeniu kompletności migracji zamknąć źródłowe Issues z linkiem do nowego zadania. Usuwanie bezpowrotne wymaga odrębnego zatwierdzenia.
5. Zaktualizować `docs/ISSUES.md` i odnośniki w dokumentacji po realnej migracji. Do tego momentu dotychczasowe linki są historycznymi odsyłaczami, nie oficjalnym źródłem bieżących statusów.

## 5. Warunek uznania polityki za wdrożoną

Polityka zostaje **technicznie wdrożona** dopiero po sprawdzeniu dla każdego repozytorium: Actions disabled, brak uruchomień GitHub CI, poprawne wykonywanie zadań CI w GitLab oraz udokumentowany właściciel konfiguracji. Brak potwierdzenia oznacza `NIEZWERYFIKOWANE`.
