# AliceAI — poglądowa roadmapa rozwoju

> Data opracowania: 2026-10-28. **Propozycja kolejności prac**, a nie zobowiązanie terminowe ani potwierdzenie ukończonych wydań. Stan funkcji należy weryfikować w kodzie, testach, Issues i roadmapach poszczególnych usług.

## Założenia

W pierwszej kolejności ustabilizować platformę, bezpieczeństwo i integracje. Następnie dopracować ścieżki użytkownika oraz rozwijać automatyzację i kolejne funkcje. Zadania są pogrupowane według zależności, nie według dat.

| Etap | Priorytet | Rezultat / kryterium zakończenia |
| --- | --- | --- |
| **R0 — Inwentaryzacja** | P0 | Lista usług, rzeczywistych endpointów i zależności; potwierdzona macierz uruchomień i README bez sprzecznych instrukcji. |
| **R1 — Fundament infrastruktury** | P0 | Powtarzalne środowisko develop, konfiguracja RabbitMQ i baz, healthchecki, centralne logi, backup i restore sprawdzone testowo. |
| **R2 — Bezpieczeństwo i tożsamość** | P0 | Autoryzacja w Alice Web/API, ochrona tokenów, polityki dostępu Alice Node i narzędzi LLM, kontrola operacji wrażliwych. |
| **R3 — Stabilizacja funkcji podstawowych** | P1 | Testy integracyjne Web ↔ usługi, obsługa błędów, spójny stan aplikacji, stabilne API. |
| **R4 — Spójny asystent i wiedza** | P1 | Konwersacje LLM, kontekst dokumentów, ustandaryzowane narzędzia i możliwość audytu wywołań. |
| **R5 — Moduły życia codziennego** | P1 | Uporządkowane scenariusze Calendar, Mail, Weather, Health, Shopping i Budget z trwałością danych. |
| **R6 — Automatyka i media** | P2 | Solidna integracja Home Assistant, monitoring węzłów i streaming multimediów; rozwój funkcji anime. |
| **R7 — Wielourządzeniowość i wydania** | P2 | Ujednolicenie Desktop/Web/Browser Extension, proces publikacji, testy regresji i aktualizacji. |
| **R8 — Rozszerzenia** | P3 | Zaawansowane automatyzacje, spersonalizowane podpowiedzi, dodatkowe integracje i optymalizacja wydajności. |

## Backlog według komponentów

| Obszar | Najbliższe prace |
| --- | --- |
| **Alice Infra** | Mapowanie hostów i środowisk, monitoring, procedury awaryjne, backup/restore, CI. |
| **Alice Web / Desktop / Extension** | Wspólna autoryzacja, spójne nawigowanie, obsługa błędów, panel konwersacji. |
| **LLM / Knowledge** | Kontrola uprawnień narzędzi, solidne konteksty dokumentów, testy scenariuszy asystenta. |
| **Node / Node Manager** | Polityki komend, raportowanie kondycji węzłów, timeouty i audyt działań. |
| **Dashboard** | Uprawnienia per użytkownik, eksport/import, trwałość i odtwarzanie konfiguracji. |
| **Weather** | Odporność na awarie dostawców, limity zapytań, walidacja synchronizacji. |
| **Time Coordinator** | Stabilność OAuth, synchronizacja Calendar/Tasks, powiadomienia i integracja widoku dnia. |
| **Mail** | Ochrona poświadczeń, stabilne kolejki i mechanizmy retry, retencja wiadomości. |
| **Budget** | Weryfikacja sald i importu CSV, odporność na duplikaty, uzgadnianie transakcji. |
| **Health** | Dokończenie rzeczywiście brakujących elementów MVP; ochrona danych wrażliwych i historia pomiarów. |
| **Shopping** | Integracja z Alice Web, kontrola dostępu, synchronizacja i dane katalogowe. |
| **SmartHome** | Bezpieczne sceny i sterowanie, model 3D, testy integracji z Home Assistant. |
| **Media** | Domknięcie testów V0.7/V0.8, metadane anime, kontrola dostępu i streaming. |

## Definicja ukończenia etapu

Etap uznajemy za zrealizowany dopiero po spełnieniu odpowiednich kryteriów:

1. Kod został scalony do właściwego repozytorium i ma możliwą do odtworzenia konfigurację.
2. Testy jednostkowe i integracyjne dla zmiany kończą się powodzeniem.
3. Kontrakty i konfiguracja zostały zaktualizowane w dokumentacji.
4. Uwzględniono bezpieczeństwo, obsługę błędów, logowanie i migrację danych.
5. Zmiana została zweryfikowana w docelowym środowisku.
6. Dla danych trwałych istnieje przetestowany sposób ich odzyskania.

## Zależności i ryzyka

- Bez stabilnej komunikacji i bezpieczeństwa nie należy rozbudowywać autonomicznych operacji narzędzi LLM.
- Bez trwałych danych i backupów nie warto automatyzować modyfikacji budżetu, poczty i ustawień inteligentnego domu.
- Integracje z dostawcami zewnętrznymi podlegają ich limitom, zgodom OAuth i dostępności.
- Historyczne ścieżki GitLab i starsze układy repozytoriów należy zweryfikować przed zmianami we wdrożeniach.

## Zarządzanie roadmapą

To dokument orientacyjny. Konkretne zadania powinny być rozpisywane jako Issues z właścicielem, priorytetem, akceptacją i powiązanym PR. Aktualizuj stan etapów po weryfikacji, a nie tylko po dopisaniu funkcji do README.

[Powrót do katalogu komponentów](PROJECT_OVERVIEW.md).

## Śledzenie prac w GitHub Issues

[Centralny indeks etapów i zadań wykonawczych](ISSUES.md) zawiera odnośniki do 9 etapów w `alice-infra` i 17 Issues w repozytoriach komponentów. Status realizacji należy sprawdzać w GitHub Issues, a nie ręcznie w tej roadmapie.
