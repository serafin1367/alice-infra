# ALICE Stability & Production Readiness v2.0

Status: plan przyjęty do realizacji, **nie** deklaracja gotowości produkcyjnej.
Data: 2026-10-30.

## Architektura docelowa
Proxmox jako host infrastruktury, usługi backendowe w Dockerze, Alice Node oraz Alice Web i Alice Desktop jako klienci wspólnych usług. Integracje obejmują m.in. REST, RabbitMQ i bazy danych. Przed wdrożeniem należy potwierdzić rzeczywistą topologię i lokalizację danych.

## Punkt wyjścia
Ostatni znany zbiorczy odczyt `alice-ci-reports` wskazał 16 projektów ze statusem CI `success`; nie jest to dowód pokrycia testami ani gotowości produkcyjnej.
`alice/infra`: kontrola konfiguracji zamiast testów jednostkowych aplikacji.
`alice/browser-extension`: rozwój niepotwierdzony; status planistyczny `on-hold`, bez archiwizacji repo.

## Etapy i kryteria akceptacji
1. **Audyt 16 projektów**: inwentaryzacja aktywnych testów, pokrycia (jeśli mierzone), braków, zależności i ryzyk P0/P1/P2. Testy nieobecne oznaczać `not-tested`, nie `passed`.
2. **Infrastruktura**: walidacja YAML i Docker Compose, przegląd Dockerfile, healthchecków, sieci, sekretów, wolumenów, polityk restartu oraz planu backup/restore. Walidacja składni nie zastępuje uruchomienia.
3. **Integracje**: potwierdzenie Web/Desktop ↔ backend, Node ↔ Node Manager, RabbitMQ i baz danych oraz zachowania przy awarii pojedynczej usługi i reconnect.
4. **Odporność**: restart kontenerów i hosta, utrata RabbitMQ, ochrona danych trwałych, odtwarzanie backupu i pomiary czasu powrotu.
5. **Odbiór produkcyjny**: pełne wyniki testów, jawne wyjątki, instrukcja wdrożenia i wycofania zmian, monitoring i alerty.

## Definicje statusów
- `CI Passed`: wskazany commit ma zakończony sukcesem pipeline.
- `Integration Verified`: udokumentowane scenariusze integracyjne przeszły w określonym środowisku.
- `Production Ready`: spełnione kryteria testów, bezpieczeństwa, odtwarzania i operacyjne, z zatwierdzonymi wyjątkami.

## Zasady pracy
Najpierw audyt bez zmian produkcyjnych. Każdą naprawę powiązać z testem regresyjnym, commitem, pipeline ID i wynikiem. Raporty wykonania przechowywać w `alice-ci-reports` lub w wersjonowanych dokumentach; nie publikować sekretów i logów z danymi prywatnymi.

## Ograniczenia obecnego pipeline infra
`.gitlab-ci.yml` sprawdza składnię plików YAML oraz pliki Compose znalezione w katalogu głównym. Nie dowodzi poprawności Dockerfile, konfiguracji w innych katalogach, bezpiecznego wdrożenia ani działania usług. Kontrole te wymagają dalszej rozbudowy po inwentaryzacji.
