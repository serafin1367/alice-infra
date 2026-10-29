# ALICE Infra

## AliceAI — cały ekosystem

**AliceAI** to modularna platforma osobistego asystenta: interfejs WWW, aplikacja desktopowa i rozszerzenie przeglądarki korzystają z niezależnych mikroserwisów, lokalnych modeli LLM oraz integracji z urządzeniami i usługami zewnętrznymi. Projekt obejmuje wiedzę, pocztę, kalendarz, pogodę, finanse, zdrowie, zakupy, media, SmartHome oraz zdalne węzły wykonawcze. **Alice Infra** zapewnia wspólną warstwę infrastrukturalną i dokumentację środowisk.

- **[Opis całego projektu i architektury](docs/PROJECT_OVERVIEW.md)** — role aplikacji, katalog wszystkich 17 repozytoriów, scenariusze integracyjne i zasady architektoniczne.
- **[Centralna roadmapa GitHub Issues](docs/ISSUES.md)** — etapy R0–R8, zadania mikroserwisów i dynamiczne wyszukiwanie statusów.- **[Poglądowa roadmapa AliceAI](docs/ROADMAP.md) — kolejność prac R0–R8, zadania dla usług, zależności i kryteria ukończenia.

### Przegląd obszarów

| Obszar | Komponenty |
| --- | --- |
| Interfejsy | Alice Web, Alice Desktop, Alice Browser Extension |
| Asystent i wiedza | LLM, Knowledge |
| Organizacja dnia | Time Coordinator, Mail, Weather, Dashboard |
| Dane osobiste | Budget, Health, Shopping |
| Dom i multimedia | SmartHome, Media |
| Hosty i infrastruktura | Node, Node Manager, Infra |

> Dokumenty opisują stan i zamierzenia na 28.10.2026. Sama obecność kodu lub opisu nie oznacza potwierdzenia produkcyjnej gotowości. Roadmapa jest propozycją, a nie harmonogramem zatwierdzonym terminowo.


## ALICE README v1.0 — karta projektu

> Standard dokumentacyjny v1.0 (2026-10-28). Informacje o implementacji poniżej wynikają z widocznej struktury repozytorium i istniejącej dokumentacji. Nie oznaczają wykonania testów uruchomieniowych. Szczegółowe informacje historyczne zachowano w dalszej części pliku.

### 1. Opis projektu
Współdzielona infrastruktura i układ środowisk AliceAI.

### 2. Status implementacji
Kod lub pliki konfiguracyjne są obecne w repozytorium; kompletność działania należy potwierdzić testami. Szczegółowy wykaz funkcji i planów znajduje się niżej w istniejącej dokumentacji.

### 3. Technologie
Docker Compose i konfiguracja infrastruktury zależna od środowiska

### 4. Architektura i zależności
Źródła do weryfikacji architektury: `services/`, `environments/`, `docs/`.

### 5. Wymagania
Wymagane są środowiska uruchomieniowe wynikające z powyższych technologii i dostęp do wskazanych usług zewnętrznych. Dokładne wersje zależności określają pliki manifestu projektu.

### 6. Uruchomienie
Punkt wyjścia: `README: Zakres odpowiedzialności`. Przed uruchomieniem skonfiguruj wymagane usługi i sekrety; procedury szczegółowe zachowano poniżej.

### 7. Konfiguracja
Konfigurację należy przeprowadzić zgodnie z manifestami projektu oraz opisami poniżej. Nie wpisywać haseł i tokenów do wersjonowanych plików.

### 8. API i integracje
README: Zakres odpowiedzialności. W celu weryfikacji rzeczywistego kontraktu należy porównać dokumentację z kodem odpowiednich endpointów i zdarzeń.

### 9. Trwałość danych
Jeżeli usługa korzysta z trwałego stanu, jego backup i odtwarzanie wymagają osobnej procedury. Nie zakładać, że dane przechowywane w pamięci procesu przeżyją restart.

### 10. Bezpieczeństwo
Nie wersjonować produkcyjnych sekretów ani haseł.

### 11. Testy
Przed wdrożeniem uruchomić testy zdefiniowane w repozytorium oraz sprawdzić zależności integracyjne. W ramach aktualizacji dokumentacji nie uruchamiano testów aplikacji.

### 12. Diagnostyka
Sprawdzać logi procesu, stan połączenia z zależnościami oraz dostępne endpointy diagnostyczne, jeżeli zostały zaimplementowane.

### 13. Wdrożenie
Wdrożenie środowiskowe należy uzgodnić z `alice-infra`; nie zakładać, że opisane poniżej historyczne ścieżki są nadal aktualne.

### 14. Roadmapa i wymagane weryfikacje
Zmapować rzeczywiste hosty i składniki przed opisaniem jako wdrożone.

### 15. Dokumentacja szczegółowa (zachowana)
Poniższe sekcje zawierają oryginalną dokumentację techniczną. Wszelkie historyczne instrukcje należy sprawdzić w aktualnej strukturze kodu.

---


Repozytorium przeznaczone do zarządzania współdzieloną infrastrukturą oraz konfiguracją środowisk uruchomieniowych całego systemu ALICE.

Nie jest to repozytorium mikroserwisu. Kod źródłowy poszczególnych usług powinien znajdować się w `ALICE/microservices/*`.

## Zakres odpowiedzialności

Repozytorium służy do przechowywania i zarządzania:

- Współdzielonymi komponentami infrastruktury, takimi jak RabbitMQ, reverse proxy, monitoring oraz inne wspólne usługi uruchomieniowe.
- Topologią środowisk oraz podziałem i grupowaniem hostów.
- Przykładowymi konfiguracjami współdzielonymi przez różne usługi.
- Dokumentacją operacyjną dotyczącą infrastruktury i jej utrzymania.

**Nie należy umieszczać w tym repozytorium kodu źródłowego mikroserwisów.**

## Początkowa struktura katalogów

- `services/` – współdzielone komponenty infrastruktury.
- `environments/` – definicje środowisk oraz rozmieszczenie hostów.
- `docs/` – dokumentacja operacyjna, notatki techniczne oraz decyzje architektoniczne.

## Aktualny kierunek rozwoju

Na obecnym etapie repozytorium celowo zachowuje minimalistyczną strukturę.

Pierwszym planowanym komponentem współdzielonej infrastruktury jest **RabbitMQ**, ponieważ korzysta z niego wiele mikroserwisów ALICE i nie powinien być przypisany do repozytorium pojedynczej usługi.

## Kolejne kroki

1. Zdefiniować rozmieszczenie hostów dla środowisk lokalnego, testowego (stage) oraz produkcyjnego.
2. Dodać konfigurację uruchomieniową współdzielonego RabbitMQ.
3. Przygotować dokumentację przypisania poszczególnych usług do hostów.
4. Przenieść zasoby wdrożeniowe specyficzne dla poszczególnych środowisk z repozytoriów mikroserwisów do repozytorium infrastruktury.


## Status stabilizacji i testów — 30.10.2026

**Etap dokumentacji i podstawowego CI/CD:** zakończony według centralnego raportu omawianego 30.10.2026: 17 repozytoriów raportowano jako `success`, łącznie z Alice Web, Alice Desktop i Alice Infra. To stan raportowany, a nie niezależne potwierdzenie poprawności funkcjonalnej całej platformy.

**Zamknięte luki CI (po audycie z 30.10):**
- Alice Web: osobny etap `test` (`node --test tests/*.test.mjs`) przed budowaniem obrazu; początkowo trzy testy kontrolne.
- Alice Desktop: etap `test` uruchamia `unittest discover` i kończy się błędem, gdy brakuje katalogu `tests`; początkowo trzy testy kontrolne. Nie obejmuje uruchomienia GUI ani pakowania EXE dla Windows.
- Alice Infra: walidacja składni YAML i głównych plików Docker Compose w CI; brak operacji wdrożeniowych. Walidacja Dockerfile i skan sekretów wymagają osobnej weryfikacji — nie są potwierdzone obecnym plikiem CI.

**Następny etap: ALICE Stability Gate v2 — testy integracyjne i odpornościowe.** Środowisko docelowe: Proxmox z usługami Docker; Alice Web i Alice Desktop jako interfejsy wspólnego zaplecza, wraz z Alice Node, RabbitMQ, bazami i mikroserwisami. Rozpocząć od inwentaryzacji zależności, adresów usług, kontraktów API, kolejek i healthchecków. Następnie zweryfikować scenariusze komunikacji, niedostępności zależności, restartów, ponownych połączeń, trwałości danych, backup/restore oraz obserwowalności. Testy prowadzić najpierw w izolowanym środowisku; nie modyfikować produkcji bez osobnej decyzji.

**Kryteria statusów:** `CI Passed` = poprawny pipeline; `Integration Verified` = udokumentowane, zakończone sukcesem scenariusze pomiędzy usługami; `Production Ready` = dodatkowo potwierdzone odporność, bezpieczeństwo, monitorowanie, odtwarzanie i procedura wdrożenia. Obecne zielone CI **nie oznacza** dwóch ostatnich statusów. Dla każdej próby zapisywać wersję/commit, środowisko, wynik, logi/artefakty i zgłoszenia usterek.

**Zakres:** `browser-extension` pozostaje poza obowiązkową bramką stabilizacji do decyzji o dalszym rozwoju. Aktualny plan i wyniki audytu: [audyt testów](docs/quality-audit-2026-10-30.md).


### Decyzja o kolejności testów — 30.10.2026

**Obowiązujący najbliższy etap: wyłącznie testy jednostkowe (Unit Test Gate).** Wcześniej opisany etap testów integracyjnych i odpornościowych jest **odroczony** i nie należy go uruchamiać jako następnego kroku.

Zakres bieżącego etapu: zinwentaryzować testy jednostkowe i odróżnić je od smoke, build, testów infrastrukturalnych oraz integracyjnych; zebrać raporty/liczby testów i przypadki pominięte; wskazać luki; dodać brakujące izolowane testy jednostkowe i egzekwować je w CI. Zależności zewnętrzne zastępować mockami/stubami tam, gdzie to uzasadnione. Testy nie mogą wymagać uruchomionego środowiska Proxmox ani produkcyjnych usług.

Dopiero po potwierdzeniu zakresu i wyników jednostkowych powrócić do planowania integracji. Zielony pipeline lub trzy testy kontrolne nie świadczą o kompletnym pokryciu logiki aplikacji.
