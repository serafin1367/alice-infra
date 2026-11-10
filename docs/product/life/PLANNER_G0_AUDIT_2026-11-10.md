# Alice Life — Planer V1: audyt G0 (kod GitHub)

**Data:** 2026-11-10  
**Status:** audyt statyczny potwierdzonych plików na gałęziach `main`; bez uruchamiania usług, bez testów integracyjnych, bez weryfikacji danych środowiska developerskiego i dostępu OAuth.  
**Decyzja 2026-11-10:** hybrydowy pomiar rzeczywistego czasu: odczyt wiarygodnych pomiarów istniejących usług oraz licznik ręczny Planera, bez podwójnego liczenia.

## 1. Weryfikowane repozytoria

- [alice-microservices-time_coordinator](https://github.com/serafin1367/alice-microservices-time_coordinator): Google Calendar, Google Tasks, czas, powiadomienia, cykliczne harmonogramy, PostgreSQL + Flyway.
- [alice-microservices-work](https://github.com/serafin1367/alice-microservices-work): lokalne zadania, JIRA, projekty i sesje pracy projektu.
- [alice-microservices-health](https://github.com/serafin1367/alice-microservices-health): nawyki, aktywności, dane Lifestyle, tygodniowe plany.
- [alice-microservices-llm](https://github.com/serafin1367/alice-microservices-llm): Assistant, narzędzia i integracja kontekstu Health.
- [alice-web](https://github.com/serafin1367/alice-web): UI Planera, Kalendarza, Dzisiaj, Work, Health i routing Nginx.
- [alice-infra](https://github.com/serafin1367/alice-infra): Docker Compose środowiska develop, założenia produktu, dokumenty Planera.

Ponadto przejrzano drzewo [alice-microservices-knowledge](https://github.com/serafin1367/alice-microservices-knowledge); nie wykazano domenowej odpowiedzialności za kalendarz czy pomiar czasu. Nie przeprowadzono pełnego przeglądu implementacji wszystkich serwisów ani inspekcji rzeczywistej bazy.

## 2. Macierz źródeł i możliwości — weryfikacja kodu

| Źródło | Istniejący interfejs lub model | Stan G0 | Brak / ograniczenie |
|---|---|---|---|
| Google Calendar | `GoogleCalendarController`: `GET /api/google/calendar/events`, `GET /api/google/calendar/accounts`; `GoogleCalendarEventDto` zawiera start/end, accountKey, status | Zweryfikowane | Normalizacja wydarzeń wielodniowych, całodniowych i zajętości; aktualność cache i synchronizacja |
| Google Tasks | `GoogleTasksController`: `GET /api/google/tasks`, `GET /lists`; `GoogleTaskDto`: id, accountKey, taskListId, dueAt, completed | Zweryfikowane | Brak czasu estymowanego i podzielności w potwierdzonym DTO; wielokontowość i deduplikacja |
| Work/JIRA | `TaskController`: `GET /api/tasks/search`, `GET /api/tasks/{id}`; `TaskResponse` zawiera id, projectId, priority, jiraIssueKey, origin, status, updatedAt | Zweryfikowane | Brak `estimatedMinutes`, `splittable` i `dueAt` w potwierdzonym DTO TaskResponse; nie zakładać istnienia tych pól w JIRA bez dodatkowego adaptera |
| Nawyki i rytm dnia | `HealthLifestyleController`: `GET /api/health/lifestyle?date=...`, `GET /api/health/meal-templates`; `HabitController`: `GET /api/health/habits?date=...` | Zweryfikowane częściowo | Dzienna aktywność i zwyczaje nie są jeszcze jednorodnym modelem powtarzalnych okien czasowych Planera; skonfigurowane preferencje 08:00/16:00/17:00 mają należeć do Planera |
| Alice Health | `WeeklyPlanController`: `GET /api/health/weekly-plans/current`; `DayCompletionController`: `GET /api/health/day-completion`; `HabitController` | Zweryfikowane | Odczyt zaplanowanych aktywności i wykonania wymaga osobnego mappera; status ukończenia to nie rzeczywisty czas pracy |
| Własne zadania Planera | `/planner/` w Alice Web obecnie informacyjna strona bez generatora | Brak backendu | Potrzebny model personal-task, CRUD i migracje, bez kopiowania Google/JIRA |

## 3. Pomiar czasu — najważniejsze odkrycie

**Work ma istniejący trwały pomiar czasu projektu**, zatem nie należy go zastępować duplikatem:

- `ProjectWorkSessionController` pod `/api/projects/{projectId}/work-sessions`: odczyt, tworzenie, edycja, zakończenie aktywnej sesji, usunięcie.
- `WorkSessionReportController`: `GET /api/work-sessions?projectId=&from=&to=`.
- `ProjectWorkSessionRequest`: `startedAt`, `endedAt`, `description`; odpowiedź dodaje `id`, `projectId`, `projectName`.
- Migracja `V8__create_project_work_sessions.sql`: `project_id`, `started_at`, `ended_at`; unikatowa aktywna sesja **w ramach projektu**.
- `ProjectWorkSessionService` potrafi rozpocząć sesję z czasem aktualnym, zatrzymać aktywną i weryfikuje kolejność dat.

**Istotna luka:** potwierdzony model sesji Work wiąże zapis z projektem, **nie z zadaniem (`taskId`)**. Takiego czasu nie można automatycznie przypisać do konkretnego zadania JIRA bez dodatkowego, zweryfikowanego powiązania. Sesje Work dają wiarygodny pomiar czasu *projektu*, ale niekoniecznie *zadania*. Wyszukiwanie po opisie nie jest wiarygodnym mapowaniem.

**Rekomendacja:** znormalizować źródła sesji jako `time_observation` zawierające `sourceSystem`, `sourceSessionId`, `projectRef?`, `taskRef?`, `startedAt`, `endedAt`, `verification`, `overlapGroup`. Brak `taskRef` oznacza, że pomiar może służyć raportom projektowym, ale **nie** uczeniu czasu pojedynczego zadania. Ręczny licznik Planera zapisuje `taskRef` i rejestruje pauzy. Dla pracy projektowej należy rozważyć integrację z sesjami Work z jednoznacznym `taskId` lub mechanizmem uzgadniania, aby nie tworzyć podwójnych odcinków czasu. Nie wolno samoczynnie dopisywać sesji do JIRA.

## 4. Wybór właściciela domeny Planera

**Rekomendacja techniczna G0: rozszerzyć istniejący `time-coordinator-service` o odrębny moduł domenowy `planner` z własnymi tabelami Flyway**, na początek bez nowego mikroserwisu.

Podstawa: serwis już ma PostgreSQL, Flyway, integracje Calendar/Tasks, mechanizmy cyklicznego wykonywania oraz powiadomienia; nie jest źródłem prawdy Work ani Health. Implementacja modułu Planera powinna zawierać wyłącznie jego plany, sesje własne, estymacje, reguły i referencje do źródeł. Integracje Work/Health przez kontrolowane API, nie przez bezpośrednie odczyty ich tabel.

**Ryzyka i warunki:** rozszerzenie Time Coordinator o wielodomenową logikę nie może nadmiernie związać generatora z Google/OAuth. Wydzielić niezależny interfejs adapterów i testować bez Google; jeżeli zakres lub obciążenie modułu przekroczy granice serwisu, rozważyć osobny Alice Life Planner na podstawie pomiarów, nie na podstawie samej nazwy domeny. Przed G1 potwierdzić warunki autoryzacji i komunikacji pomiędzy usługami w bieżącym develop/production.

## 5. Routing i UI

- Alice Web zawiera `public/planner/index.html` i `styles.css`, ale **nie ma jeszcze backendowego API planera**.
- `nginx/default.conf.template` ma routingi `/api/time/google/*`, `/api/work/tasks*`, `/api/work/work-sessions`, `/api/health/*`. **Nie ma** potwierdzonego `/api/planner/*` — trzeba dodać dedykowany proxy routing przy implementacji G1.
- W Planerze pozostają odrębne działania: „Zatwierdź plan lokalny” i „Publikuj do Google Calendar”. Druga operacja nadal wymaga wyraźnego zatwierdzenia.

## 6. Braki i priorytety implementacji

| Priorytet | Zadanie | Właściciel sugerowany |
|---|---|---|
| P0 | Model `planner_day/plan_revision/plan_block/personal_task`, referencje do źródeł, migracje | Time Coordinator / planner |
| P0 | Adaptery Calendar/Tasks, Work/JIRA, Health, nawyki z informacją o aktualności | Time Coordinator / planner, przez API |
| P0 | Własne sesje Start/Pauza/Wznów/Zakończ z deduplikacją i prawidłowym `taskRef` | Time Coordinator / planner |
| P0 | Odmowa przypisywania pomiarów Work do tasków bez jednoznacznego powiązania | Planner i Work |
| P0 | Algorytm estymacji USER→HISTORY→CONTEXT→DEFAULT(60 min, low confidence) | Planner |
| P0 | Generator deterministyczny z priorytetem wydarzeń stałych, przerw i bufora | Planner |
| P1 | Opcjonalne wzbogacenie sesji Work o referencję do zadania i migrację danych | Work |
| P1 | Kontrakty monitorowania aktualności źródeł, audyt rewizji i idempotencja | Planner |
| P1 | UI osi czasu i rejestrowania wykonania w `/planner/` | Alice Web |
| P2 | Nocny szkic i poranny briefing; publikacja Google osobno | Planner / Time Coordinator |

**Nieimplementowane w ramach G0:** baza danych, REST planera, licznik, generator, publikacja i UI. To audyt kodu i decyzja rekomendacyjna przed G1.

## 7. Bramka G0 → G1

Przed rozpoczęciem G1 potwierdzić:
1. Dostępność odczytu Work i Health przez serwis Planera, uprawnienia i zachowanie przy niedostępności.
2. Unikalne `sourceRef` dla różnych kont i usług; rozdzielenie planu od źródłowego zapisu.
3. Wersjonowanie i idempotencję operacji na własnych sesjach.
4. Decyzję, czy licznik dla zadania Work tworzy lokalną sesję Planera, czy rozszerza sesję Work z `taskId` (bez duplikowania minut).
5. Strukturę migracji i limit uprawnień do publikacji Google.

## 8. Referencje do kodu (zweryfikowane pliki)

- [Calendar Controller](https://github.com/serafin1367/alice-microservices-time_coordinator/blob/main/src/main/java/alice/time/coordinator/controller/GoogleCalendarController.java), [Tasks Controller](https://github.com/serafin1367/alice-microservices-time_coordinator/blob/main/src/main/java/alice/time/coordinator/controller/GoogleTasksController.java), [Timer Controller](https://github.com/serafin1367/alice-microservices-time_coordinator/blob/main/src/main/java/alice/time/coordinator/controller/TimerController.java), [Google Task DTO](https://github.com/serafin1367/alice-microservices-time_coordinator/blob/main/src/main/java/alice/time/coordinator/controller/dto/GoogleTaskDto.java).
- [Work Task Controller](https://github.com/serafin1367/alice-microservices-work/blob/main/src/main/java/alice/work/controller/TaskController.java), [Work Task DTO](https://github.com/serafin1367/alice-microservices-work/blob/main/src/main/java/alice/work/controller/dto/TaskResponse.java), [Project Work Sessions Controller](https://github.com/serafin1367/alice-microservices-work/blob/main/src/main/java/alice/work/controller/ProjectWorkSessionController.java), [Project Work Session DTO](https://github.com/serafin1367/alice-microservices-work/blob/main/src/main/java/alice/work/controller/dto/ProjectWorkSessionResponse.java), [Session Database Migration](https://github.com/serafin1367/alice-microservices-work/blob/main/src/main/resources/db/migration/V8__create_project_work_sessions.sql).
- [Health Habits](https://github.com/serafin1367/alice-microservices-health/blob/main/src/main/java/alice/health/HabitController.java), [Lifestyle](https://github.com/serafin1367/alice-microservices-health/blob/main/src/main/java/alice/health/HealthLifestyleController.java), [Weekly Plans](https://github.com/serafin1367/alice-microservices-health/blob/main/src/main/java/alice/health/WeeklyPlanController.java).
- [Alice Web Nginx](https://github.com/serafin1367/alice-web/blob/main/nginx/default.conf.template), [Planner Page](https://github.com/serafin1367/alice-web/blob/main/public/planner/index.html).
