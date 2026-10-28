# ALICE Infra

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
