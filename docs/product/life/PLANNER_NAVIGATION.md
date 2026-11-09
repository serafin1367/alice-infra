# Alice Life — decyzja nawigacyjna dla Planera dnia

**Data:** 2026-11-09  
**Status:** decyzja o lokalizacji interfejsu wdrożona w `alice-web`; zakres funkcjonalny planera pozostaje do określenia.

## Decyzja

- Planer ma **osobną stronę `/planner/`** o nazwie „Planer dnia”, ponieważ będzie potrzebować własnego miejsca na harmonogram oraz podgląd proponowanych zmian.
- **Nie dodajemy nowej pozycji do globalnego menu**, które zawiera już kilkanaście modułów. W globalnym menu punktem wejścia pozostaje **Kalendarz**.
- Planer należy do **sekcji nawigacyjnej Kalendarza**, ale jest **niezależny od aktualnie wybranego konta Google**. W Alice Web dostępny jest z bocznego panelu Kalendarza, z jego paska ikon także na telefonie oraz ze skrótu w widoku „Dzisiaj”.
- **„Dzisiaj”** nadal służy do szybkiego przeglądu i wykonywania pojedynczych akcji. **Kalendarz** pozostaje miejscem zarządzania wydarzeniami i listami Google Tasks. **Planer** otrzymuje przestrzeń do przyszłego układania roboczych planów.
- W menu globalnym podczas przeglądania `/planner/` aktywne pozostaje podświetlenie modułu „Kalendarz”.

## Uzasadnienie

Obecny moduł Kalendarza uzależnia menu widoków wybranego konta od stanu kont Google. Planowanie dnia musi docelowo działać także bez kont Google, uwzględniać zadania z różnych źródeł oraz przyszłe bloki robocze Alice Life. Wybór osobnej strony rozdziela funkcję planowania od edycji zewnętrznego kalendarza i nie rozbudowuje zatłoczonego menu głównego.

## Zakres tego etapu

Wdrożenie obejmuje wyłącznie **architekturę informacji i przejścia między ekranami**. Nowa strona `/planner/` jest jawnie oznaczona jako miejsce w przygotowaniu. Brak generowania planu, automatycznego rozstawiania zadań, edycji spotkań lub zapisu w Google Calendar. Nie udajemy gotowej funkcji.

## Decyzje funkcjonalne do wspólnego doprecyzowania

Przed implementacją planera trzeba ustalić:
1. Czy podstawową jednostką planowania jest **dzień**, z opcjonalnym przeglądem tygodnia?
2. Jakie źródła trafiają do planu roboczego: Google Calendar/Tasks, zadania Praca/JIRA, nawyki, Health, zadania własne?
3. Jak reprezentować **bloki sztywne** i **elastyczne** oraz czas trwania i priorytety?
4. Co Alice może automatycznie proponować, a co tylko po wyraźnym uruchomieniu planowania?
5. Jak wygląda **zatwierdzanie propozycji**, rozróżnienie planu roboczego od zewnętrznego kalendarza oraz cofanie zmian?
6. Gdzie zapisywać trwały plan roboczy i jego wersje, bez dublowania źródeł domenowych?

## Zgodność z dokumentacją produktu

Decyzja jest spójna z `docs/PRODUCT_VISION.md` (Alice Life, Planner V1) oraz ustaleniami o inteligentnym planowaniu dnia w `docs/PROJECT_OVERVIEW.md`. Zmiany kalendarza i publikacja planu wymagają uprzedniej zgody użytkownika. Rozwiązanie nie tworzy konkurencyjnego systemu zapisu wydarzeń.

## Warunki akceptacji nawigacji

- Planer otwiera się pod `/planner/` bez konieczności wyboru konta Google.
- Link z Kalendarza działa zarówno w układzie desktopowym, jak i mobilnym.
- Widok „Dzisiaj” zawiera bezpośredni skrót do Planera.
- Menu główne nie dostaje kolejnej pozycji.
- Nie jest sugerowane, że autonomiczne planowanie już działa.
