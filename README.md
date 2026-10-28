# ALICE Infra

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
