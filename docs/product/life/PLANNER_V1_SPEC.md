# Alice Life — Planer V1: specyfikacja funkcjonalna i model danych

**Data opracowania:** 2026-11-10  
**Status:** specyfikacja rozwijana. Zatwierdzone: sześć źródeł danych; lokalny plan roboczy z osobną publikacją do Google Calendar; ramy pracy 08:00–17:00 od poniedziałku do piątku i elastyczne planowanie weekendów (decyzje 2026-11-10). Długości bloków, przerwy, bufory i pozostałe szczegóły algorytmu są nadal propozycjami do akceptacji.  
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

## 2a. Granica zatwierdzania i publikacji — ZATWIERDZONE 2026-11-10

**Wybrany wariant: plan lokalny z osobną publikacją do Google Calendar.**

1. Alice może automatycznie przygotować i aktualizować **roboczy szkic** harmonogramu przechowywany w AliceAI, z wersjami i historią zmian.
2. Użytkownik przegląda i zatwierdza lokalny plan roboczy. Zatwierdzenie dotyczy wyłącznie wewnętrznego planu AliceAI — nie jest poleceniem publikacji.
3. Zewnętrzny kalendarz Google pozostaje źródłem istniejących wydarzeń. Alice nie przesuwa, nie tworzy i nie usuwa wydarzeń Google wskutek wygenerowania, edycji czy zatwierdzenia planu lokalnego.
4. Publikacja **wybranych** bloków do Google Calendar wymaga oddzielnego podglądu zmian, wskazania konta i kalendarza oraz jawnego potwierdzenia przez użytkownika. Weryfikacja praw dostępu i aktualności danych następuje ponownie przed zapisem.
5. Zatwierdzenie lub publikacja planu nie aktualizują automatycznie statusów Google Tasks/JIRA ani danych Alice Health.
6. Konflikt między zatwierdzonym lokalnym planem a późniejszą zmianą kalendarza oznacza potrzebę przeplanowania lub przeglądu, a nie zgodę na nadpisanie wydarzenia.
7. Po publikacji trzeba zapisać identyfikatory utworzonych wydarzeń i dziennik wykonanych operacji, aby ponowienie nie tworzyło duplikatów.

Konsekwencja dla UI: osobne działania **„Zatwierdź plan”** i **„Publikuj do Google Calendar”**; drugie nie może być domyślnie uruchamiane przez pierwsze.

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
| Zatwierdzenie planu roboczego | Jawna akcja użytkownika; dotyczy wyłącznie lokalnego planu (ZATWIERDZONE) |
| Przeniesienie spotkania Google Calendar | Wymagana osobna zgoda na konkretną zmianę |
| Publikacja bloków do Google Calendar | Osobna zgoda z podglądem operacji (ZATWIERDZONE) |
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

1. **Rozstrzygnięte:** lokalny plan roboczy i odrębna, jawnie zatwierdzana publikacja Google Calendar (2026-11-10).
2. Czy podstawową jednostką jest dzień, a tydzień wyłącznie przeglądem (rekomendacja na V1)?
3. Jak traktować zadania bez estymacji: zaproponować domyślny czas, zapytać, czy odłożyć do backlogu?
4. Jakie są ramy pracy i odpoczynku dla dni roboczych i weekendów?
5. Jakie domyślne działania mogą być wykonane bez dodatkowej akceptacji przy ponownym planowaniu?


## 12a. Ramy pracy i weekendy — ZATWIERDZONE 2026-11-10

- **Dni pracy zawodowej:** poniedziałek–piątek.
- **Standardowe okno pracy zawodowej:** **08:00–17:00** w strefie `Europe/Warsaw`.
- **Weekendy:** planowane **elastycznie**, bez automatycznego przenoszenia na nie standardowego okna pracy zawodowej.
- Okno 08:00–17:00 określa domyślne ramy planowania **pracy**, a nie granice całego dnia osobistego. Nie oznacza obowiązku ciągłego zapełnienia dziewięciu godzin zadaniami.
- Spotkania istniejące w kalendarzu poza tym oknem pozostają widoczne i nie podlegają automatycznemu przesuwaniu. Przydzielanie nowych bloków zawodowych poza oknem jest osobną polityką do ustalenia; nie należy domyślnie dodawać nadgodzin.
- W weekendy Alice może przygotowywać elastyczne propozycje aktywności, rutyn i zadań prywatnych, z zachowaniem terminów i wydarzeń sztywnych. Automatyczne planowanie pracy zawodowej w weekendy wymaga odrębnej decyzji.
- Nie są jeszcze ustalone: długość bloku skupienia, częstotliwość i długość przerw, godziny posiłków, dzienny bufor, wieczorna pora generowania planu oraz zasady nadgodzin.

### Parametryzacja (zatwierdzone wartości, nie istniejąca konfiguracja aplikacji)

| Parametr | Wartość |
|---|---|
| `workdays` | `MON,TUE,WED,THU,FRI` |
| `workStartLocal` | `08:00` |
| `workEndLocal` | `17:00` |
| `timeZone` | `Europe/Warsaw` |
| `weekendPlanningMode` | `FLEXIBLE` |
| `focusBlockMinutes` | niezatwierdzone |
| `breakMinutes` | niezatwierdzone |
| `dailyBufferMinutes` | niezatwierdzone |

## 13. Szczegółowe reguły układania harmonogramu — PROPOZYCJA DO UZGODNIENIA (2026-11-10)

### A. Jednostka planowania i horyzont

- Układać **jeden dzień** w strefie `Europe/Warsaw`; tydzień służy do podglądu obciążenia i terminów, nie do automatycznego wypełniania każdej godziny.
- Planować najbliższy dzień roboczy wieczorem, również bez wydarzeń kalendarzowych (zgodnie z wcześniejszym zatwierdzonym wymaganiem). Pora generowania jest do ustalenia.
- Plan obejmuje poranek, bloki pracy, przerwy, obowiązki prywatne i odpoczynek. **Zatwierdzone okno pracy to 08:00–17:00, poniedziałek–piątek; weekendy elastyczne (sekcja 12a).** Dalszy zakres dnia osobistego i reguły obsługi wyjątków nadal wymagają ustalenia.

### B. Kolejność rozmieszczania

1. **Zablokowane godziny / wydarzenia stałe**: zajęte terminy Google Calendar, nieprzesuwalne zobowiązania i ręcznie zablokowane bloki — nie przesuwać automatycznie.
2. **Nieprzekraczalne ograniczenia**: terminy końcowe, obowiązkowe przerwy, limity długości dnia, wskazane okna niedostępności.
3. **Rutyny zaakceptowane przez użytkownika**: posiłki, spacer, siłownia i odpoczynek; jeżeli nie są sztywne, można przesuwać je w określonym oknie.
4. **Zadania terminowe i o wyższym priorytecie**: najpierw najpilniejsze w ramach możliwego zakresu czasu; priorytet nie może usuwać stałych zobowiązań.
5. **Pozostałe zadania elastyczne**: wypełniać wolne okna zgodnie z estymacją i kontekstem pracy.
6. **Rezerwy**: pozostawić wolne przedziały, nie zagospodarowywać automatycznie całej dostępności.

### C. Estymacja czasu i podział zadań

- `estimatedMinutes` pochodzi kolejno z jawnego ustawienia użytkownika, potwierdzonej historii podobnych zadań albo propozycji Alice oznaczonej jako estymacja.
- Brak czasu w źródle nie oznacza czasu zerowego. Alice nie może ukryć niepewności; rekomendacja V1: proponować wartość domyślną do korekty i oznaczać ją w UI.
- Zadanie dłuższe niż dopuszczalny blok można podzielić na sesje; nie dzielić automatycznie spotkań ani zadań oznaczonych jako niepodzielne.
- Ograniczyć przełączanie kontekstu: łączyć podobne zadania i zostawiać przejścia między blokami.

### D. Przerwy, praca i zdrowie

- Preferować bloki skupienia w ustalonych godzinach pracy; nie narzucać pracy poza zadeklarowanym zakresem.
- Wstawiać przerwy i czas na posiłki zgodnie z zatwierdzonym rytmem; ich długość i elastyczność do ustalenia.
- Aktywności Health są sugestiami i ograniczeniami osobistymi, a nie automatyczną diagnozą ani poleceniem zmiany danych zdrowotnych.
- Nadmiar zadań pozostawić w widocznym backlogu z informacją, dlaczego nie trafiły do harmonogramu.

### E. Konflikty i ponowne planowanie

- Konflikt stałych zdarzeń zgłosić jako problem wejściowy; nie przesuwać ich bez zgody.
- Konflikt propozycji elastycznych: najpierw przesuwać najmniej pilne, ewentualnie skracać lub dzielić tylko wtedy, gdy użytkownik dopuścił taką zmianę.
- W razie nowego spotkania lub zmiany deadline'u odświeżyć stan źródeł, porównać rewizję i utworzyć **nową propozycję lokalnego planu**, bez modyfikowania Google.
- Zabezpieczyć ręczne bloki zablokowane przez użytkownika przed automatycznym przeplanowaniem.
- Nie zmieniać zatwierdzonej rewizji po cichu; proponowane aktualizacje mają widoczny diff i uzasadnienie.

### F. Kryteria optymalizacji — proponowana kolejność

1. Zero naruszeń zablokowanych zdarzeń i granic uprawnień.
2. Jak najwięcej zadań terminowych ukończonych przed deadline'ami.
3. Realistyczna długość dnia, przerwy i wystarczające bufory.
4. Mniej przełączeń kontekstu i mniej rozdrobnionych bloków.
5. Dopasowanie do potwierdzonych preferencji oraz przewidywanego poziomu energii.

### G. Parametry do zatwierdzenia przed implementacją generatora

- **Zatwierdzono:** standardowe ramy pracy 08:00–17:00, poniedziałek–piątek, weekendy elastyczne. Do ustalenia pozostaje zakres dnia prywatnego i nadgodziny.
- Dopuszczalny czas pojedynczego bloku skupienia i przerwy między blokami.
- Minimalny dzienny bufor i sposób traktowania nadmiaru zadań.
- Polityka zadań bez estymacji i możliwość automatycznego dzielenia dużych zadań.
- Czy wolno automatycznie nadpisywać roboczy **szkic** po zmianie źródeł; zatwierdzone wersje pozostają historyczne.
- **Zatwierdzono:** weekendy planowane elastycznie; do ustalenia szczegółowe zasady planowania obowiązków w weekend oraz godzina wieczornego generowania.

### H. Testy akceptacyjne reguł

- Trzy spotkania przecinają preferowany blok pracy: generator nie przesuwa spotkań, lecz rozkłada pracę w pozostałym czasie.
- Dwa pilne zadania konkurują o jeden wolny slot: generator pokazuje konflikt i nie planuje obu na tę samą godzinę.
- Zadania bez czasu trwania otrzymują czytelną propozycję estymacji lub trafiają na listę wymagającą decyzji, a nie znikają.
- Aktualizacja JIRA/Google po zatwierdzeniu dnia oznacza plan jako wymagający przeglądu, nie publikuje ani nie przesuwa automatycznie wydarzeń.
- Plan bez połączonego Google Calendar nadal można przygotować na bazie pozostałych źródeł; UI wskazuje brakujące dane.
- Żadna operacja tworzenia czy zatwierdzania lokalnego planu nie wywołuje zapisów do Google Calendar.
