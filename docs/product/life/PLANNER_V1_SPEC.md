# Alice Life — Planer V1: specyfikacja funkcjonalna i model danych

**Data opracowania:** 2026-11-10  
**Status:** specyfikacja rozwijana. Zatwierdzone: sześć źródeł danych; lokalny plan roboczy z osobną publikacją do Google Calendar; dostępność zawodowa 08:00–17:00 od poniedziałku do piątku, domyślny koniec zaplanowanej pracy o 16:00, rezerwacja obiadu 16:00–17:00 i elastyczne planowanie weekendów (decyzje 2026-11-10). Zatwierdzono także maksymalny blok skupienia 90 minut, przerwę między blokami 15 minut i dzienną rezerwę 60 minut. Zatwierdzono rezerwację obiadu 16:00–17:00 po pracy; długość faktycznego posiłku w tej godzinie, oznaczanie podzielności, szczegółowe progi wiarygodności historii i pozostałe parametry algorytmu wymagają dalszej akceptacji.  
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
- **Okno dostępności zawodowej:** **08:00–17:00** w strefie `Europe/Warsaw`; **domyślne zakończenie planowanych bloków pracy: 16:00**. Odcinek 16:00–17:00 nie jest domyślnie przydzielany nowym zadaniom zawodowym.
- **Weekendy:** planowane **elastycznie**, bez automatycznego przenoszenia na nie standardowego okna pracy zawodowej.
- Okno 08:00–17:00 oznacza granicę możliwej dostępności zawodowej, nie domyślny dziewięciogodzinny harmonogram. Planer preferuje pracę 08:00–16:00, a przedział 16:00–17:00 chroni jako prywatny czas po pracy. Nie zapełnia automatycznie godzin 16:00–17:00 pracą.
- Spotkania istniejące w kalendarzu poza tym oknem pozostają widoczne i nie podlegają automatycznemu przesuwaniu. Przydzielanie nowych bloków zawodowych poza oknem jest osobną polityką do ustalenia; nie należy domyślnie dodawać nadgodzin.
- W weekendy Alice może przygotowywać elastyczne propozycje aktywności, rutyn i zadań prywatnych, z zachowaniem terminów i wydarzeń sztywnych. Automatyczne planowanie pracy zawodowej w weekendy wymaga odrębnej decyzji.
- Zatwierdzone parametry pracy: maksymalny blok skupienia **90 min**, przerwa pomiędzy blokami **15 min**, dzienna niezaplanowana rezerwa **60 min**. **Obiad rezerwowany 16:00–17:00 po domyślnym końcu pracy o 16:00**. Nadal nie ustalono faktycznego czasu trwania posiłku w tym oknie, zasad dzielenia zadań i estymowania czasu, wieczornej pory generowania planu oraz zasad nadgodzin.

### Parametryzacja (zatwierdzone wartości, nie istniejąca konfiguracja aplikacji)

| Parametr | Wartość |
|---|---|
| `workdays` | `MON,TUE,WED,THU,FRI` |
| `workStartLocal` | `08:00` |
| `workEndLocal` | `17:00` (górna granica dostępności) |
| `preferredWorkEndLocal` | `16:00` (domyślne zakończenie pracy) |
| `lunchReservedFromLocal` | `16:00` |
| `lunchReservedToLocal` | `17:00` |
| `lunchAfterWork` | `true` |
| `timeZone` | `Europe/Warsaw` |
| `weekendPlanningMode` | `FLEXIBLE` |
| `focusBlockMinutes` | `90` (maksimum) |
| `breakMinutes` | `15` (między blokami skupienia) |
| `dailyBufferMinutes` | `60` (łącznie na dzień roboczy) |

## 12b. Bloki skupienia, krótkie przerwy i rezerwa — ZATWIERDZONE 2026-11-10

- **Maksymalna długość pojedynczego bloku skupienia:** **90 minut**. To limit preferowany przez generator, a nie narzucony minimalny czas ani automatyczny nakaz dzielenia każdej aktywności dokładnie co 90 minut.
- **Przerwa między kolejnymi blokami skupienia:** **15 minut**. Nie dotyczy automatycznie krótkich spotkań, już istniejących wydarzeń ani przerwy obiadowej; sposób uwzględniania takich wyjątków zostanie doprecyzowany.
- **Dzienna rezerwa na nieprzewidziane zdarzenia:** **60 minut**. Generator powinien chronić co najmniej tyle niezaplanowanego czasu w standardowym dniu pracy, rozłożonego elastycznie między dostępne okna. Rezerwa nie jest zadaniem do wykonania.
- Wszystkie trzy parametry stosują się do roboczej propozycji harmonogramu i **nie uprawniają do przesuwania spotkań ani publikacji w Google Calendar**.
- Przedziały niedostępne z powodu zobowiązań sztywnych pozostają nienaruszone. Jeżeli z powodu spotkań i pilnych terminów nie da się zachować 60-minutowej rezerwy, Alice powinna pokazać konflikt i niedobór bufora, zamiast ukrywać przeciążenie.
- **Zatwierdzono rezerwację obiadu 16:00–17:00 po zakończeniu pracy**, ale nie ustalono dokładnej długości posiłku w tym oknie. Dopuszczalne dzielenie długich zadań i polityka szacowania czasu **nie zostały jeszcze zatwierdzone**.

### Przykładowa interpretacja — bez narzucania godzin konkretnych sesji

| Reguła | Warunek akceptacyjny |
|---|---|
| Blok skupienia | Żaden automatycznie proponowany ciągły blok pracy skupionej nie przekracza 90 minut |
| Krótka przerwa | Między sąsiadującymi blokami skupienia występuje 15 minut nieprzydzielonych do pracy |
| Bufor | Standardowy dzień zawiera przynajmniej 60 minut czasu niezaplanowanego; brak możliwości jest jawnie sygnalizowany |
| Publikacja | Parametry lokalnego planu nie zmieniają wydarzeń w Google Calendar |

## 12c. Koniec pracy i obiad — ZATWIERDZONE 2026-11-10

**Decyzja użytkownika:** Alice domyślnie planuje zakończenie pracy o **16:00**, a **16:00–17:00 rezerwuje na obiad po pracy**.

- Dla dni roboczych (poniedziałek–piątek) generator preferuje zadania zawodowe od 08:00 do 16:00; 17:00 jest zachowaną górną granicą dostępności zawodowej, a nie godziną, do której należy zapełniać dzień pracą.
- Rezerwacja **16:00–17:00** jest blokiem osobistym, a nie 15-minutową przerwą między blokami skupienia, i nie jest częścią dziennej 60-minutowej niezaplanowanej rezerwy na opóźnienia.
- W domyślnych propozycjach nie umieszczać nowych zadań pracy ani spotkań w godzinach 16:00–17:00. Istniejące zobowiązania z Google Calendar, które kolidują z tym oknem, **pozostają niezmienione**; Planer zgłasza konflikt i proponuje skorygowany lokalny szkic, nie przesuwa spotkania bez osobnej zgody.
- Nie utożsamiać rezerwacji godzinnej z potwierdzeniem godzinnego posiłku: **czas faktycznego obiadu wewnątrz tego okna pozostaje do ustalenia**. Do czasu doprecyzowania blok 16:00–17:00 jest w całości chroniony.
- Weekendy są planowane elastycznie; nie narzucać im automatycznie dni roboczych 08:00–16:00 ani rezerwacji 16:00–17:00 bez kolejnej decyzji.
- Zatwierdzanie lokalnego planu nie publikuje obiadu do Google Calendar. Publikacja, również posiłku, wymaga odrębnej zgody na konkretne operacje.

### Kryteria akceptacji

1. Standardowy poniedziałek bez spotkań: ostatni proponowany blok pracy kończy się najpóźniej o 16:00, a 16:00–17:00 jest zarezerwowane jako czas prywatny na obiad.
2. Spotkanie Google Calendar 16:30–17:00: pozostaje w kalendarzu bez zmian; Planer sygnalizuje konflikt z rezerwacją obiadu i prezentuje propozycję lokalnego rozwiązania.
3. Bufor 60 minut nie jest realizowany przez utożsamienie go z godziną obiadową.
4. Potwierdzenie harmonogramu lokalnego nie tworzy wydarzenia „Obiad” w Google Calendar.

## 12d. Automatyczne dzielenie podzielnych zadań — ZATWIERDZONE 2026-11-10

**Decyzja:** Alice samodzielnie dzieli **zadania oznaczone jako podzielne** na sesje robocze nieprzekraczające **90 minut**, bez potrzeby odrębnej akceptacji każdego podziału w lokalnym szkicu.

### Reguły obowiązujące

1. Podział dotyczy tylko zadań z `splittable=true` (lub równoważnym jawnie ustalonym atrybutem). Nie wolno przyjmować, że każde długie zadanie jest podzielne. Sposób domyślnego ustawiania tego atrybutu wymaga osobnej decyzji.
2. Podział tworzy **bloki planu**, a nie osobne zadania źródłowe. Wszystkie sesje odnoszą się do jednego `sourceType/sourceId` lub `personalTaskId` i do wspólnej estymacji czasu zadania.
3. Każda sesja mieści się w przyjętych granicach pracy i ma długość do 90 min. Między kolejnymi blokami skupienia zapewnić ustaloną przerwę 15 min; nie zużywać w ten sposób 60-minutowej niezaplanowanej rezerwy.
4. Dopuszczalne jest rozmieszczenie sesji w kilku dniach, jeżeli wymagają tego wolne okna lub termin zadania. Planer wskazuje nieschedulowaną resztę, a nie udaje ukończenia pracy.
5. Zachować jeden status zadania i łączny postęp, bazując na zweryfikowanym wykonaniu sesji. Rozmieszczenie sesji w szkicu nie oznacza wykonania zadania.
6. Spotkania stałe oraz zadania oznaczone jako niepodzielne nie są dzielone automatycznie. Przy braku informacji o podzielności Planer oznacza zadanie jako wymagające decyzji; nie wymusza podziału.
7. Podział i przesuwanie sesji są **lokalnymi operacjami szkicu**. Nie zmieniają JIRA, Google Tasks ani Google Calendar i nie obchodzą oddzielnego zatwierdzenia publikacji.

### Model danych — uzupełnienie propozycji

- Zadanie: `splittable` (wartość jawna; nieznane dopóki nieustalone), `estimatedMinutes`, `remainingMinutes` (gdy dane dostępne).
- Sesja: `taskRef`, `sessionOrdinal`, `scheduledMinutes`, `startAt`, `endAt`, `planRevision`, `executionState`.
- Inwariant: suma minut zaplanowanych aktywnych sesji nie przekracza świadomie przyjętej pozostałej estymacji, chyba że UI pokazuje powód i korektę oszacowania.

### Przykład akceptacyjny

Podzielne zadanie na 240 minut -> proponowane sesje 90 + 90 + 60 minut, z 15-minutowymi przerwami pomiędzy sąsiadującymi sesjami skupienia. Jeżeli w bieżącym dniu jest tylko 90 minut dostępności, pozostałe 150 minut trzeba przenieść do kolejnych wolnych okien lub do kolejki niezaplanowanych.

### Do doprecyzowania podczas estymacji

- Źródło i pewność oszacowania całkowitego oraz pozostałego czasu.
- Postępowanie z zadaniami bez estymacji.
- Domyślne oznaczenie `splittable` dla nowych zadań; możliwość ręcznego przełączenia i obsługa zadań niepodzielnych dłuższych niż 90 min.

## 12e. Estymacja i uczenie na rzeczywistym czasie — ZATWIERDZONE 2026-11-10

### Hierarchia estymowania

1. **Ręczna estymacja użytkownika ma bezwarunkowe pierwszeństwo.** Alice nie nadpisuje jej podczas automatycznego przeliczania, synchronizacji ani uczenia; może jedynie zaproponować korektę do osobnego zaakceptowania.
2. **Wiarygodna historia porównywalnych zadań:** Alice może estymować czas z rzeczywistych, zweryfikowanych pomiarów podobnych ukończonych prac oraz danych zadania (typ, zakres, złożoność). Wykorzystane przykłady i ich aktualność muszą być możliwe do wyjaśnienia.
3. **Estymacja na podstawie kontekstu zadania:** gdy historia jest niewystarczająca, Alice może wyprowadzić propozycję z opisu i innych dozwolonych informacji, oznaczając jej pochodzenie i niepewność. Ocena LLM nie zastępuje walidacji.
4. **Wartość domyślna:** gdy danych nadal nie wystarcza, przyjąć **60 minut**, ze stanem **`LOW_CONFIDENCE_DEFAULT`**, nie przedstawiając tej wartości jako sprawdzonego faktu. Użytkownik może ją poprawić.

### Uczenie z wykonania

- **ZATWIERDZONE:** po wykonaniu zadania Alice zestawia zatwierdzony szacunek z rzeczywistym czasem pochodzącym z wiarygodnych pomiarów sesji (start/stop lub inne jawnie dostępne dane). Samo zaplanowanie sesji albo jej odhaczenie **nie stanowi potwierdzenia czasu wykonania**.
- Rozróżnić `estimatedMinutes` (całość), `actualMinutes` (potwierdzony czas), `remainingMinutes` (pozostały czas, jeśli da się go określić), `estimateOrigin` (`USER/HISTORY/CONTEXT/DEFAULT`), `estimateConfidence` i `estimatedAt`.
- Dla zadań dzielonych na sesje sumować faktycznie zarejestrowany czas bez podwójnego liczenia wznowień, zachowując powiązanie z jednym zadaniem nadrzędnym.
- Nie uczyć się z niepełnych, nienadzorowanych lub niejednoznacznych próbek tak, jakby były potwierdzonymi pomiarami. Pokazywać brak wystarczającej historii zamiast deklarować wysoką pewność.
- Uczenie poprawia **przyszłe propozycje**, ale nigdy nie nadpisuje ręcznego oszacowania użytkownika ani nie zmienia terminów w Google/JIRA/Health.
- Umożliwić korektę błędnego pomiaru i pominięcie go w statystykach; nie tworzyć historii czasu pracy z wymyślonych wartości.

### Model i testy — wymagania do implementacji

- Rekord pochodzenia estymacji: `estimateOrigin`, `estimateConfidence`, `estimatedMinutes`, `estimateEvidenceRefs`, `estimatedAt`, `userOverride`; opcjonalny `sampleCount` dla historii.
- Sesja pomiarowa: `sessionId`, `taskRef`, `startedAt`, `stoppedAt`, `actualMinutes`, `source`, `verificationState`, `excludedFromLearning`.
- Testy: (a) ręczne 120 min nie zostaje nadpisane przez wyliczenie 80 min; (b) brak danych skutkuje 60 min oznaczonymi niepewnie; (c) potwierdzone sesje wpływają na przyszłe sugestie; (d) same bloki w harmonogramie nie zwiększają `actualMinutes`; (e) niepełne i zduplikowane pomiary nie zniekształcają historii.
- **Do doprecyzowania technicznego:** liczba i podobieństwo próbek wymagane do uznania historii za wiarygodną, metoda odporna na wartości odstające, minimalna dokładność pomiaru, retencja oraz sposób potwierdzania rzeczywistego wykonania.

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

- **ZATWIERDZONE:** `estimatedMinutes` pochodzi w pierwszej kolejności z ręcznej estymacji użytkownika (której Alice nie nadpisuje), następnie z wiarygodnej historii podobnych ukończonych zadań, a przy braku wystarczających danych z oszacowania Alice na podstawie dostępnego opisu i kontekstu zadania.
- **ZATWIERDZONE:** gdy historia i kontekst nie pozwalają wiarygodnie oszacować czasu, Alice stosuje **60 minut jako niepewną estymację domyślną**, widoczną i edytowalną w UI. Brak estymacji nie usuwa zadania z planowania; nie oznacza również zerowego czasu. Jeśli użytkownik skoryguje estymację, jego wartość staje się nadrzędna.
- **ZATWIERDZONE:** zadania wyraźnie oznaczone jako podzielne Alice może automatycznie rozdzielać na sesje o długości do 90 minut, także na różne dni. Zachować jedno zadanie nadrzędne, identyfikator źródła i sumaryczny postęp; nie tworzyć niezależnych zadań ani duplikatów w JIRA lub Google Tasks. Spotkań i zadań niepodzielnych nie dzielić automatycznie. Sposób domyślnego określania podzielności wymaga jeszcze ustalenia.
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

- **Zatwierdzono:** dostępność zawodową 08:00–17:00, domyślny koniec pracy o 16:00, rezerwację obiadu 16:00–17:00 po pracy, poniedziałek–piątek, weekendy elastyczne. Do ustalenia pozostają wyjątki i nadgodziny.
- **Zatwierdzono:** maksymalny blok skupienia 90 minut i 15-minutową krótką przerwę między kolejnymi blokami skupienia. Pozostają do ustalenia wyjątki i długość przerwy obiadowej.
- **Zatwierdzono:** dzienny bufor 60 minut. Pozostaje do ustalenia sposób rozmieszczenia rezerwy i postępowanie przy jej niedoborze.
- **Zatwierdzono:** automatyczny podział zadań oznaczonych jako podzielne na sesje maksymalnie 90-minutowe; automatyczną estymację z hierarchią źródeł i niepewną wartością domyślną 60 min; uczenie na rzeczywistym czasie pracy. Do ustalenia pozostają progi wiarygodności i sposób oznaczania podzielności nowych zadań.
- Czy wolno automatycznie nadpisywać roboczy **szkic** po zmianie źródeł; zatwierdzone wersje pozostają historyczne.
- **Zatwierdzono:** weekendy planowane elastycznie; do ustalenia szczegółowe zasady planowania obowiązków w weekend oraz godzina wieczornego generowania.

### H. Testy akceptacyjne reguł

- Trzy spotkania przecinają preferowany blok pracy: generator nie przesuwa spotkań, lecz rozkłada pracę w pozostałym czasie.
- Dwa pilne zadania konkurują o jeden wolny slot: generator pokazuje konflikt i nie planuje obu na tę samą godzinę.
- Zadania bez czasu trwania otrzymują czytelną propozycję estymacji lub trafiają na listę wymagającą decyzji, a nie znikają.
- Aktualizacja JIRA/Google po zatwierdzeniu dnia oznacza plan jako wymagający przeglądu, nie publikuje ani nie przesuwa automatycznie wydarzeń.
- Plan bez połączonego Google Calendar nadal można przygotować na bazie pozostałych źródeł; UI wskazuje brakujące dane.
- Żadna operacja tworzenia czy zatwierdzania lokalnego planu nie wywołuje zapisów do Google Calendar.

## 14. Plan implementacji generatora — KOLEJNE ETAPY (propozycja wykonawcza)

### Etap G0 — inwentaryzacja i kontrakty integracji

- Zweryfikować istniejące API i schematy sześciu źródeł (Time Coordinator / Google, Work/JIRA, Health, nawyki, zadania lokalne), uprawnienia, czasy synchronizacji i identyfikatory źródeł.
- Osobno zweryfikować, czy istnieje zaufany pomiar rzeczywistego czasu pracy i gdzie można go odczytać; brak takiej integracji wymaga jawnego mechanizmu rejestracji wykonania.
- Wybrać właściciela trwałego planu po sprawdzeniu aktualnych mikroserwisów, a nie z góry tworzyć nowy.
- **Odbiór:** macierz źródło → API → model → aktualność → dostępność → ograniczenia, plus diagram odpowiedzialności i lista braków.

### Etap G1 — model danych i kontrolowane API roboczego planu

- Trwałe encje planu dziennego, rewizji, bloków, referencji do zadań i sesji, pomiaru rzeczywistego czasu oraz źródeł estymacji.
- API odczytu, tworzenia szkicu i lokalnej edycji, blokady rewizji (`If-Match`) i operacji idempotentnych; migracje PostgreSQL i testy repozytorium.
- **Odbiór:** po restarcie zachowują się bloki, wersje i ręczne estymacje; żadna operacja nie zapisuje danych do Google/JIRA/Health.

### Etap G2 — normalizacja danych sześciu źródeł

- Adaptery zamieniające dane Calendar, Tasks, JIRA, rutyn, Health i lokalnych zadań na jednolity model dostępności, terminów i zadań.
- Zachowanie `sourceRef`, statusu synchronizacji, identyfikacji duplikatów i czasu ostatniej aktualizacji; odporność na częściowe błędy.
- **Odbiór:** plan da się utworzyć także przy niedostępnym jednym źródle; dane nie są domyślnie uznawane za aktualne.

### Etap G3 — silnik estymacji, pomiar wykonania i zasady podziału

- Wprowadzić hierarchię **USER → HISTORY → CONTEXT → DEFAULT(60 min, niska pewność)**.
- Rejestrować faktyczne sesje pracy, tak aby uczenie korzystało tylko z weryfikowalnych pomiarów; zastosować deduplikację sesji i ochronę ręcznych estymacji.
- Podzielne zadania dzielić automatycznie na bloki maksymalnie 90-minutowe, z zachowaniem nadrzędnego zadania.
- **Odbiór:** testy z sekcji 12d i 12e, w tym brak fałszywego „rzeczywistego czasu” na podstawie planu.

### Etap G4 — deterministyczny generator harmonogramu

- Najpierw sztywne wydarzenia i chronione okna (preferowane 08:00–16:00 na pracę; 16:00–17:00 obiad), potem przerwy i rutyny, zadania pilne i elastyczne, a także niezaplanowana rezerwa 60 minut.
- Umieszczać sesje pracy maksymalnie 90 minut, z przerwami 15 minut pomiędzy sąsiadującymi blokami skupienia; pilnować strefy `Europe/Warsaw`, DST oraz końca wyłącznego wydarzeń całodniowych.
- Konflikty i niemożliwe ograniczenia zwracać wprost (np. zadania w backlogu), nie naruszać spotkań i ręcznych blokad.
- **Odbiór:** deterministyczne testy przypadków skrajnych; zero niezamierzonych kolizji, zero automatycznych zapisów do usług zewnętrznych.

### Etap G5 — interfejs i zatwierdzanie lokalnego planu

- W `/planner/`: oś czasu, panel niezaplanowanych zadań, pochodzenie i pewność estymacji, edycja i blokowanie sesji, konflikty, historia zmian oraz diff propozycji.
- Osobny przycisk zatwierdzenia rewizji lokalnej; odrębny przyszły proces publikacji Google.
- **Odbiór:** użytkownik może poprawić 60-minutową niepewną estymację, przeplanować bloki i zatwierdzić wyłącznie lokalną wersję.

### Etap G6 — automatyczne przygotowanie kolejnego dnia

- Wieczorne generowanie nowego szkicu i poranne podsumowanie w ramach istniejącego systemu koordynacji, z audytem i respektowaniem godzin ciszy.
- Nie nadpisywać milcząco zatwierdzonego planu; przy zmianach źródeł tworzyć nową propozycję i pokazywać różnice.
- **Odbiór:** po ponowieniu zadań nie powstają zdublowane plany; poranny raport nie przedstawia nieaktualnych danych jako aktualnych.

### Etap G7 — osobna publikacja Google Calendar (odrębny zakres)

- Podgląd planowanych operacji, wybór docelowego konta/kalendarza, jawne potwierdzenie, kontrola konfliktów i uprawnień, identyfikatory utworzonych wydarzeń, idempotencja oraz raport z częściowych błędów.
- **Odbiór:** samo zatwierdzenie lokalnego planu nie publikuje niczego; publikacja działa jedynie po osobnej zgodzie.

### Kolejność prac i bramki jakości

- Rozpocząć od G0 i decyzji o odpowiedzialności serwisu; następnie G1 → G2 → G3 → G4 → G5 → G6. G7 dopiero po osobnej akceptacji zakresu.
- Równolegle do etapów prowadzić testy jednostkowe reguł, testy kontraktowe adapterów i migracji; testy integracyjne ze źródłami uruchamiać w środowisku z wymaganymi zgodami.
- Nie wdrażać uczenia na podstawie symulowanych pomiarów, nie przedstawiać propozycji API jako istniejących endpointów i nie uznawać dokumentu za implementację.
