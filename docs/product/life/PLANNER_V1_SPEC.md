# Alice Life — Planer V1: specyfikacja funkcjonalna i model danych

**Data opracowania:** 2026-11-10  
**Status:** projekt do uzgodnienia. Zatwierdzone jest sześć źródeł danych; pozostałe parametry w tym dokumencie są propozycjami, dopóki użytkownik ich nie zaakceptuje.  
**Powiązania:** `docs/PRODUCT_VISION.md` (P2 / Planner V1), `docs/PROJECT_OVERVIEW.md` (Alice Life: planowanie dnia), `docs/product/life/PLANNER_NAVIGATION.md`, `docs/product/assistant/VISION.md`.

## 1. Cel i granice

Planer udostępnia jeden plan roboczy dnia: zbiera kontekst z sześciu źródeł, tworzy propozycje realistycznego harmonogramu, pokazuje konflikty, pozwala edytować wersję roboczą i ją zatwierdzić. Nie zastępuje Google Calendar, Google Tasks, JIRA ani Health. Nie publikuje automatycznie zmian do systemów zewnętrznych.

Główna strona: `/planner/`, nawigacja w sekcji Kalendarza i skrót z „Dzisiaj”. `/today/` pozostaje podsumowaniem.

## 2. Zakres źródeł — ZATWIERDZONE

| Źródło | Rola w planie | Granica zapisu |
|---|---|---|
| Google Calendar | Wydarzenia, terminy stałe, zajętość | Tylko przez Time Coordinator po osobnym zatwierdzeniu |
| Google Tasks | Zadania z terminami lub bez, status, lista | Aktualizacja Google Tasks wyłącznie na wyraźne żądanie |
| Praca/JIRA | Zadania zawodowe, terminy, priorytety, status | Synchronizacja i zapis zgodnie z kontraktem Work; Planer sam nie zmienia JIRA |
| Nawyki i rytm dnia | Typowy rozkład dnia, przerwy, posiłki, spacer, siłownia | Preferencje/hipotezy z oznaczonym źródłem i możliwością korekty |
| Alice Health | Planowane aktywności i cele, w zakresie przyznanego dostępu | Brak automatycznej modyfikacji danych zdrowotnych |
| Własne zadania Planera | Zadania nieprzypisane do usług zewnętrznych | Własne trwałe rekordy Alice Life |

Dostęp do każdej integracji musi być niezależny; awaria jednej nie ukrywa innych. Informacja o nieaktualnych danych ma być widoczna.

## 3. Jednostki planowania — PROPOZYCJA

- **Fixed commitment**: zdarzenie ze sztywnym terminem; brak automatycznego przesuwania.
- **Flexible task block**: zadanie z estymacją czasu i możliwością umieszczenia w wolnym oknie.
- **Routine block**: przyjęta preferencja (praca, posiłek, spacer, odpoczynek).
- **Buffer**: przestrzeń niezarezerwowana na nagłe sprawy i opóźnienia.

Podstawową jednostką proponowany jest **dzień**, z kontekstowym przeglądem tygodnia. Czas lokalny: `Europe/Warsaw`, a trwałe znaczniki czasu jako instant ze strefą/offsetem; całodniowe wydarzenia jako daty lokalne z wyłączną datą końcową.

Priorytet `LOW/NORMAL/HIGH/CRITICAL`; elastyczność `FIXED/MOVABLE/OPTIONAL`. Pola: `id`, `planId`, `sourceType`, `sourceId`, `sourceAccountKey`, `titleSnapshot`, `startAt`, `endAt`, `estimatedMinutes`, `priority`, `flexibility`, `status`, `reason`, `originRevision`, `sourceSyncedAt`. `titleSnapshot` jest tylko migawką prezentacyjną; źródło danych pozostaje w usłudze domenowej.

Własne zadania: `id`, `title`, `notes`, `dueAt?`, `estimatedMinutes?`, `priority`, `completedAt?`, `createdAt`, `updatedAt`; nie są kopiami Google Tasks.

## 4. Model trwałego planu — PROPOZYCJA

- `day_plan`: `id`, `localDate`, `zoneId`, `status(DRAFT/PROPOSED/APPROVED/ARCHIVED)`, `revision`, `generatedAt`, `approvedAt`, `sourceSnapshotAt`.
- `plan_block`: elementy z pkt 3, powiązane z wersją planu.
- `plan_revision`: audyt zmian, autor (Alice/użytkownik), komentarz i diff.
- `plan_approval`: decyzja, zakres, czas i rewizja planu; oddzielne zgody dla operacji zewnętrznych.
- `plan_source_status`: stan integracji (`OK/STALE/ERROR/NOT_CONNECTED`) oraz czas ostatnich danych.

Trwałość najlepiej ulokować w istniejącej usłudze odpowiedzialnej za planowanie/koordynację po audycie schematów Time Coordinator i Life. **Nie przesądzać nowego mikroserwisu** bez tego audytu. Alice Web jest klientem, nie źródłem prawdy.

## 5. Generowanie harmonogramu — PROPOZYCJA

1. Zebrać dane z sześciu źródeł; dla każdego zwrócić aktualność i ewentualne błędy.
2. Znormalizować termin, szacowanie, priorytet, źródło i elastyczność; zidentyfikować duplikaty.
3. Ułożyć zobowiązania sztywne, nie zmieniając ich godzin.
4. Nałożyć zatwierdzone ramy dnia, przerwy, aktywność i bufory.
5. Rozmieścić zadania elastyczne w wolnych przedziałach, uwzględniając deadline i priorytet.
6. Zweryfikować konflikty, przeciążenie, czas odpoczynku i brak miejsca na zadania.
7. Wytworzyć propozycję wraz z wyjaśnieniami; nadmiar obowiązków pokazać jako backlog, nie jako nierealistyczne bloki.
8. Zatwierdzenie zapisuje wybraną rewizję planu roboczego. Osobny jawny workflow pozwala opublikować wybrane elementy do Google Calendar.

Algorytm V1 powinien być deterministyczny, testowalny i niezależny od dostępności LLM; Alice Assistant może proponować estymacje i interpretować konflikty, ale decyzje muszą być walidowane regułami.

## 6. Akcje, zatwierdzanie i uprawnienia — PROPOZYCJA zgodna z istniejącymi ograniczeniami

| Działanie | Domyślne uprawnienie |
|---|---|
| Odczyt danych z wybranych źródeł | W ramach uprawnień integracji |
| Wygenerowanie propozycji planu | Dozwolone automatycznie |
| Modyfikacja szkicu planu roboczego | Dozwolona, wersjonowana |
| Zatwierdzenie planu roboczego | Jawna akcja użytkownika |
| Przeniesienie spotkania Google Calendar | Wymagana osobna zgoda na konkretną zmianę |
| Publikacja bloków do Google Calendar | Osobna zgoda z podglądem operacji |
| Zmiana statusów Google Tasks/JIRA | Odrębna akcja użytkownika, nie skutek zatwierdzenia planu |
| Nadpisanie danych Health/nawyków | Nie wykonywać automatycznie |

Przed operacją zewnętrzną sprawdzić aktualną rewizję danych, uprawnienia, idempotencję i wynik zapisu. Zapewnić audyt, bezpieczne ponowienie i czytelną obsługę częściowych błędów. W V1 nie obiecywać pełnego cofnięcia zmian poza własnym planem.

## 7. Proponowany ekran `/planner/`

**Nagłówek:** wybór daty, poprzedni/następny dzień, odśwież, status źródeł.  
**Główna kolumna:** oś czasu, oznaczenia `FIXED/MOVABLE/ROUTINE/BUFFER`, podgląd konfliktów, ręczne przesuwanie bloków w szkicu.  
**Panel boczny:** zadania do zaplanowania ze wszystkich dozwolonych źródeł, filtrowanie wg źródła i priorytetu, opcja dodania własnego zadania.  
**Panel propozycji:** „Zaproponuj plan”, różnice względem aktualnej wersji, „Zatwierdź plan roboczy”, „Odrzuć”, „Przywróć poprzednią wersję”.  
**Operacje zewnętrzne:** osobne „Publikuj do kalendarza” z listą konkretnych zmian i potwierdzeniem.

Mobile: kolumny jako kolejno przełączane widoki bez utraty danych szkicu. Stany empty/loading/error i nawigacja klawiaturą.

## 8. Kontrakty API — propozycja do walidacji z istniejącym kodem

- `GET /api/planner/days/{date}` — aktualna wersja planu, bloki, status źródeł.
- `POST /api/planner/days/{date}/proposals` — utworzenie nowej propozycji.
- `PATCH /api/planner/plans/{planId}/blocks/{blockId}` — korekta z kontrolą rewizji (`If-Match`).
- `POST /api/planner/plans/{planId}/approve` — zatwierdzenie wskazanej rewizji planu.
- `POST /api/planner/plans/{planId}/publication-preview` — przegląd zmian zewnętrznych.
- `POST /api/planner/plans/{planId}/publish` — publikacja zatwierdzonego zakresu zmian (idempotency key).
- `GET/POST/PATCH /api/planner/personal-tasks` — własne zadania planera.

**To kandydaci, nie istniejące endpointy.** Przed implementacją ustalić routing Nginx, hosting API i migracje DB.

## 9. Harmonogram — decyzja istniejąca + parametry otwarte

Zatwierdzony jest **automatyczny wieczorny plan kolejnego dnia roboczego**, także przy pustym kalendarzu. Domyślny start dnia, okno robocze, godzina nocnego generowania, minimalne przerwy, długość bloków i rezerwa czasu wymagają osobnego potwierdzenia. Godziny ciszy `00:00–08:00 Europe/Warsaw` obowiązują zwykłe powiadomienia, nie bezpieczne zatwierdzone zadania w tle.

## 10. Testy i kryteria akceptacji

- Harmonogram powstaje również bez Google Calendar lub po częściowej awarii integracji, z widoczną informacją o niekompletności.
- Nie tworzy nakładających się elastycznych bloków ani nie przestawia sztywnych wydarzeń.
- Poprawnie obsługuje zmianę czasu, strefy, wydarzenia całodniowe z końcem wyłącznym i zadania bez terminu.
- Nie gubi zadań bez oszacowanego czasu: trafiają do kolejki z informacją o potrzebnej estymacji.
- Plan po restarcie odtwarza rewizję, historię i decyzję zatwierdzenia.
- Zmiana źródła po wygenerowaniu szkicu wywołuje ostrzeżenie o nieaktualnym planie.
- Zatwierdzenie planu lokalnego **nie wykonuje żadnego zapisu w Google/JIRA/Health**.
- Publikacja Google wymaga osobnej zgody, ma podgląd skutków, audyt i zapobiega duplikatom.
- Ręczne cofanie dotyczy lokalnych rewizji; zewnętrzne zmiany wymagają osobnego kontrolowanego workflow.

## 11. Etapy realizacji po zatwierdzeniu funkcjonalności

1. Audyt kontraktów sześciu źródeł i decyzja o właścicielu trwałego planu.
2. Model DB + migracje + REST tylko do odczytu i zapisu szkicu.
3. UI osi czasu, listy źródeł i własnych zadań.
4. Deterministyczny generator propozycji + testy konfliktów.
5. Wersjonowanie, ręczna korekta i zatwierdzanie lokalnego planu.
6. Nocne generowanie, briefing, powiadomienia.
7. Oddzielna publikacja do Google Calendar po zgodzie (etap późniejszy).

## 12. Otwarte decyzje dla użytkownika

1. Czy zaaprobowany plan roboczy ma **pozostać wyłącznie w AliceAI**, a publikacja Google być oddzielną operacją (rekomendacja)?
2. Czy podstawową jednostką jest dzień, a tydzień wyłącznie przeglądem (rekomendacja na V1)?
3. Jak traktować zadania bez estymacji: zaproponować domyślny czas, zapytać, czy odłożyć do backlogu?
4. Jakie są ramy pracy i odpoczynku dla dni roboczych i weekendów?
5. Jakie domyślne działania mogą być wykonane bez dodatkowej akceptacji przy ponownym planowaniu?
