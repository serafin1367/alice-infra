# AliceAI — opis systemu i katalog komponentów

> Stan katalogu: 2026-10-28. Opisy opracowano na podstawie README i struktury 17 repozytoriów `serafin1367/alice-*`. Wskazanie funkcji oznacza ich deklarowany zakres lub istnienie kodu, nie potwierdza testów end-to-end ani gotowości produkcyjnej.

## Wizja produktu

**AliceAI** to rozwijany modułowy system osobistego asystenta, łączący interfejs WWW, aplikację desktopową i rozszerzenie przeglądarki z niezależnymi usługami domenowymi. Projekt ma porządkować codzienne informacje i zadania oraz ułatwiać dostęp do wiedzy, automatyzacji, mediów, finansów i inteligentnego domu. Warstwa LLM wspomaga rozmowy i korzystanie z narzędzi, lecz operacje zewnętrzne muszą podlegać odpowiedniej autoryzacji i walidacji.

System nie jest jednym monolitem. Każdy mikroserwis posiada własne repozytorium i odpowiedzialność, a integrację zapewniają **HTTP REST**, w wybranych funkcjach **WebSocket** i komunikacja **RabbitMQ**. Trwałe dane są przechowywane zależnie od usługi, np. w PostgreSQL lub wolumenach danych. Szczegóły wdrożenia muszą być potwierdzane w odpowiednich konfiguracjach.

## Model logiczny

```text
UŻYTKOWNIK
  ├── Alice Web (główny interfejs)
  ├── Alice Desktop (lokalny interfejs)
  └── Alice Browser Extension (kontekst strony przeglądarki)
             │
             ▼
    REST / brama Alice Web / API usług
             │
  ┌──────────┼──────────────────────────────┐
  │          │                              │
  ▼          ▼                              ▼
Alice LLM   Usługi osobiste i domenowe    Usługi systemowe
            Weather, Calendar/Tasks,      Dashboard,
            Mail, Knowledge, Health,      Node Manager
            Budget, Shopping, SmartHome,
            Media
  │                                         │
  └─────────────── RabbitMQ ────────────────┤
                                           ▼
                                        Alice Node
                                     (hosty i pliki)
  
Zaplecze: alice-infra (konfiguracje środowisk,
RabbitMQ, bazy danych, routing, monitoring i operacje)
```

Diagram przedstawia **logiczne role**, a nie zweryfikowaną topologię produkcyjną. Nie każda usługa używa RabbitMQ; bezpośrednie połączenia HTTP są zależne od implementacji konkretnego modułu.

## Katalog wszystkich 17 repozytoriów

### Interfejsy i kanały dostępu

| Repozytorium | Odpowiedzialność |
| --- | --- |
| [alice-web](https://github.com/serafin1367/alice-web) | Główny responsywny interfejs WWW; dashboard, widoki usług, integracja komunikacji z backendami i brama HTTP. |
| [alice-desktop](https://github.com/serafin1367/alice-desktop) | Aplikacja desktopowa Python/pywebview z integracjami lokalnymi i interfejsem HTML/JavaScript. |
| [alice-browser-extension](https://github.com/serafin1367/alice-browser-extension) | Rozszerzenie Chrome/Brave Manifest V3 pobierające kontekst strony i komunikujące się z REST API Alice LLM. |

### Usługi AI, danych i funkcji użytkownika

| Repozytorium | Odpowiedzialność |
| --- | --- |
| [alice-microservices-llm](https://github.com/serafin1367/alice-microservices-llm) | Warstwa asystentów i profili LLM, dostawcy Ollama/LM Studio, konwersacje oraz wywołania dozwolonych narzędzi. |
| [alice-microservices-knowledge](https://github.com/serafin1367/alice-microservices-knowledge) | Projekty i dokumenty, edycja, wyszukiwanie i integracja pytań z LLM. |
| [alice-microservices-health](https://github.com/serafin1367/alice-microservices-health) | Profil zdrowotny, cele, odżywianie, aktywność, pomiary i funkcje planowania; zakres MVP zależy od etapu realizacji. |
| [alice-microservice-budget](https://github.com/serafin1367/alice-microservice-budget) | Konta, transakcje, kategorie, cele, zestawienia i podstawy budżetu; import bankowy wymaga weryfikacji funkcjonalnej. |
| [alice-microservices-shopping](https://github.com/serafin1367/alice-microservices-shopping) | Listy zakupów, pozycje, ceny planowane, katalog i synchronizacja zmian dla interfejsów. |
| [alice-microservices-mail](https://github.com/serafin1367/alice-microservices-mail) | Konta pocztowe, wiadomości, wysyłka, historia, tagi i funkcje zarządzania pocztą. |
| [alice-microservices-time_coordinator](https://github.com/serafin1367/alice-microservices-time_coordinator) | Kalendarz, Google Tasks, powiadomienia, timery i mechanizmy autoryzacji OAuth. |
| [alice-weather](https://github.com/serafin1367/alice-weather) | Dane pogodowe, prognozy, ostrzeżenia, jakość powietrza, informacje astronomiczne i radiacyjne. |
| [alice-microservices-smarthome](https://github.com/serafin1367/alice-microservices-smarthome) | Integracja Home Assistant, odczyt encji, bezpieczne sterowanie i konfiguracja modelu budynku 3D. |
| [alice-microservices-media](https://github.com/serafin1367/alice-microservices-media) | Katalogowanie bibliotek audio/wideo, metadane, playlisty, streaming i rozpoznawanie anime; rozwój etapowy. |

### Zarządzanie węzłami i infrastruktura

| Repozytorium | Odpowiedzialność |
| --- | --- |
| [alice-node](https://github.com/serafin1367/alice-node) | Agent instalowany na hostach: heartbeat, zdarzenia, odczyt dozwolonych plików, operacje systemowe i Git zgodnie z polityką dostępu. |
| [alice-node-manager](https://github.com/serafin1367/alice-node-manager) | Rejestr węzłów i ich dostępności, telemetria oraz REST API dla zarządzania agentami. |
| [alice-microservice-dashboard](https://github.com/serafin1367/alice-microservice-dashboard) | Trwała konfiguracja zakładek, grup, linków i ikon dashboardu oraz monitorowanie dostępności odnośników. |
| [alice-infra](https://github.com/serafin1367/alice-infra) | Współdzielone konfiguracje uruchomieniowe, środowiska, dokumentacja infrastrukturalna i procedury operatorskie. |

**Uwaga nazewnicza:** repozytoria stosują zarówno prefiks `alice-microservice-`, jak i `alice-microservices-`. Nie zmieniać nazw bez oddzielnej migracji odwołań CI/CD, kontenerów, skryptów i zależności.

## Główne scenariusze integracyjne

1. **Rozmowa z asystentem:** użytkownik → Alice Web lub rozszerzenie → LLM → dozwolone narzędzie/usługa → odpowiedź.
2. **Media na komputerze:** Alice Web → Media → RabbitMQ / Alice Node → indeks plików lub strumień, zgodnie z aktualną implementacją.
3. **Dzień użytkownika:** Alice Web → Calendar/Tasks, Weather, Mail, Health i powiadomienia → wspólny widok.
4. **Inteligentny dom:** Alice Web → SmartHome → Home Assistant → odczyt stanu albo autoryzowane sterowanie.
5. **Operacje na hostach:** LLM lub panel administracyjny → kontrolowane komendy przez Node Manager / RabbitMQ → Alice Node.

Scenariusze opisują kierunek integracji. Dokładne kontrakty, zakresy uprawnień oraz dostępność w poszczególnych wersjach wynikają z README mikroserwisów i testów.

## Zasady architektoniczne

- Rozdzielaj kod domenowy usług od konfiguracji hostów i środowisk.
- Unikaj współdzielenia sekretów w Git; używaj dedykowanych konfiguracji i mechanizmów przechowywania poświadczeń.
- Dokumentuj właściciela danych, sposób migracji i backupu każdej usługi.
- Dla interfejsów REST i zdarzeń utrzymuj jednoznaczne kontrakty oraz zachowanie w przypadku błędów.
- W operacjach LLM → narzędzia wymagaj jawnej polityki uprawnień; sama treść promptu nie stanowi autoryzacji.
- Nie przedstawiaj wpisów w roadmapie jako funkcji ukończonych bez testów i weryfikacji.

Zobacz również [poglądową roadmapę](ROADMAP.md) i README poszczególnych repozytoriów.


## Zatwierdzone wymagania Alice Assistant i nocnego rozwoju (2026-11-02)

> Status: wymagania projektowe, nie potwierdzona implementacja.

### Osobowość, proaktywność i pamięć Alice Assistant
- Jedna osobowość Alice, centralna koordynacja i wyspecjalizowani agenci; system dla jednego użytkownika. Osobowość naturalna, przyjazna, analityczna i krytyczna, bez manipulacji.
- Alice może samodzielnie inicjować rozmowy, proponować usprawnienia i cele oraz przygotowywać przeglądy dnia i tygodnia; użytkownik może ograniczyć inicjatywę.
- Godziny ciszy **00:00–08:00 Europe/Warsaw**, domyślnie z możliwością zmiany. Bez zwykłych inicjowanych rozmów i podsumowań; dozwolone zatwierdzone zadania w tle i krytyczne alarmy (szczegóły wyjątków do ustalenia).
- Alice samodzielnie wybiera istotne informacje do zapamiętania, zapamiętuje też na wyraźne polecenie („zapamiętaj”) i samodzielnie aktualizuje wspomnienia przy zmianie nawyków. Ma pamiętać własne błędy, analizować przyczyny i wykorzystywać wnioski. Należy zapewnić możliwość korekty/usunięcia pamięci i audyt źródeł.

### Autonomiczny rozwój nocny — wymagania
- Alice może analizować i modyfikować własny kod, przygotowywać poprawki oraz testować je w **istniejącym środowisku testowym**, z izolacją usług i danych stosownie do ryzyka.
- W **każdym repozytorium AliceAI** ma mieć **stałą gałąź `alice-dev`**; nie modyfikuje bezpośrednio `main`. Użytkownik **sam ręcznie wykonuje merge do `main`** i kontroluje wdrożenie produkcyjne; Alice nie scala ani nie wdraża zmian produkcyjnych samodzielnie.
- Autonomiczny rozwój wyłącznie **nocą, 00:00–08:00**. O 08:00 Alice przestaje rozpoczynać nowe kroki, bezpiecznie kończy lub wstrzymuje aktualny etap, zapisuje checkpoint i wznawia zadanie w następnym oknie. Operacji niebezpiecznych do przerwania nie wolno gwałtownie zabijać.
- Rano Alice przedstawia dziennik/raport wykonanych prac, testów, problemów, zmian i zadań oczekujących na decyzję.
- **Jedna wspólna lista zadań rozwojowych** dla użytkownika i Alice. Oboje mogą tworzyć i edytować zadania; Alice może samodzielnie wykrywać problemy w logach/testach, proponować funkcje, dodawać zadania i **zmieniać priorytety również zadań użytkownika**. Historia i uzasadnienie zmian oraz możliwość cofnięcia; opcja zablokowania priorytetu przez użytkownika.
- Zadania są **wykonywane kolejno, jedno naraz**, bez dynamicznego planowania obciążenia CPU/GPU; podstawowe limity bezpieczeństwa pozostają wskazane. Alice może rozbijać zadania na kroki i utrwalać checkpointy.
- **Osobny mikroserwis** nocnych zadań rozwojowych, z **trwałą listą/kolejką w bazie danych** (status, priorytet, historia, kroki, checkpointy). **RabbitMQ pozostaje mechanizmem komunikacji między usługami**, a nie magazynem tej listy.
- Na tym etapie **bez interfejsu w `alice-web`**. Zarządzanie listą przez **API**, dostępne także ręcznie ze skryptów użytkownika z komputera w LAN. Użytkownik nie wymaga uwierzytelniania API ani ograniczenia do jednego adresu IP; **nie wystawiać API publicznie do internetu**. API kolejki **nie daje możliwości zatwierdzania merge ani wdrożeń produkcyjnych**.
- Uprawnienia, audyt i możliwość natychmiastowego zatrzymania pozostają wymaganiami bezpieczeństwa; samo dodanie zadania nie oznacza zgody na produkcję.


### Dalsza realizacja
- Implementacja mikroserwisu i mechanizmów nocnej pracy pozostaje do wykonania.
