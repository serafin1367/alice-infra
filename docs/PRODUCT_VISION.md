# AliceAI — wizja produktu i roadmapa proaktywnego asystenta

> Decyzja produktowa: 2026-10-30. Status: zatwierdzony kierunek docelowy; funkcjonalności i terminy nie są deklaracją wdrożenia.
> Dokument uzupełnia techniczną [roadmapę R0–R8](ROADMAP.md), nie zastępuje jej.

## Wizja i zakres
AliceAI to **osobisty asystent dla dokładnie jednej osoby**. Zna jej jawnie przekazane preferencje, utrzymuje długoterminową pamięć, rozpoznaje nawyki na podstawie uprawnionych źródeł danych, przypomina i proaktywnie proponuje działania. Nie projektujemy kont rodzinnych, współdzielonej pamięci ani administracji wieloma profilami. Jednoosobowość nie oznacza rezygnacji z uwierzytelniania, ochrony sekretów czy uprawnień narzędzi.

## Pięć filarów
1. **Alice Assistant** — rozmowa, modele LLM, kontekst, pamięć, analiza dokumentów i narzędzia.
2. **Alice Life** — kalendarz, zadania, poczta, budżet, zakupy, pogoda i dane zdrowotne.
3. **Alice Home** — Home Assistant, czujniki, sceny i bezpieczne sterowanie.
4. **Alice Media** — własne biblioteki filmów, anime i muzyki, metadane, odtwarzanie.
5. **Alice Flow** — automatyzacje i koordynacja zdarzeń pomiędzy modułami.

## Architektura logiczna
- **Alice Core**: orkiestracja rozmów, kontekstu i narzędzi; nie jest źródłem prawdy o faktach.
- **Memory**: pamięć tożsamości/preferencji, epizodyczna, semantyczna, behawioralna i operacyjna; trwałe przechowywanie niezależne od modelu LLM.
- **Learning**: wykrywanie wzorców z uwzględnieniem pochodzenia, daty, liczby obserwacji, pewności i możliwości odrzucenia hipotezy.
- **Planner**: zadania, cele, przypomnienia, harmonogramy, deduplikacja i ograniczenia częstotliwości powiadomień.
- **Flow**: wykonanie działań z kontrolą uprawnień, idempotencją, logiem audytowym i potwierdzeniami.
- **Life/Home/Media**: moduły domenowe udostępniające kontrolowane API i zdarzenia.

To **granice odpowiedzialności**, nie decyzja o tworzeniu pięciu nowych mikroserwisów. Najpierw mapujemy je na istniejące repozytoria LLM, Knowledge, Node, Time Coordinator i pozostałe usługi.

## Zasady bezpieczeństwa i prywatności
- Local-first: dane profilu i pamięć na infrastrukturze użytkownika, z udokumentowanymi wyjątkami dla integracji zewnętrznych.
- Kontrola źródeł danych, zakresów zgód, retencji, eksportu, edycji i usuwania pamięci.
- Oddzielenie faktów potwierdzonych od hipotez i wniosków; datowanie i możliwość wycofania wniosków.
- Brak samodzielnego wysyłania wiadomości, zakupów, usuwania danych, płatności i krytycznych zmian SmartHome bez odrębnej autoryzacji.
- Proaktywne powiadomienia respektują ciszę nocną, limity, priorytety i możliwość wyłączenia.
- Historia działań i wyjaśnienie „dlaczego Alice to zaproponowała”.

## Roadmapa produktowa (kolejność zależności, bez terminów)
| Faza | Cel | Kryterium akceptacji |
| --- | --- | --- |
| P0 — Inwentaryzacja | Mapowanie istniejących usług, schematów danych, API i pokrycia pięciu filarów | Macierz istnieje / brakuje / wymaga poprawy z odnośnikami do kodu |
| P1 — Memory V1 | Trwała pamięć rozmów, preferencji i decyzji; wyszukiwanie, edycja, usuwanie | Pamięć działa po restarcie i zmianie modelu; użytkownik kontroluje wpisy |
| P2 — Planner V1 | Przypomnienia i terminy na podstawie jawnych poleceń i danych Calendar/Tasks | Brak zgubionych i podwójnych przypomnień, działające strefy czasowe |
| P3 — Learning V1 | Ostrożne wykrywanie nawyków, hipotezy, potwierdzenia | Można sprawdzić źródła i odrzucić błędny wzorzec |
| P4 — Proactivity V1 | Sugestie i powiadomienia oparte na pamięci i kontekście | Konfigurowalne reguły, limity i ślad wyjaśniający sugestię |
| P5 — Flow V1 | Bezpieczne akcje między Assistant, Life, Home i Media | Polityki uprawnień, potwierdzenia, audyt, obsługa błędów |
| P6 — Rozszerzenia | Więcej źródeł danych, adaptacja i optymalizacja | Testy scenariuszy użytkownika i mierzalna użyteczność |

## Zależności od R0–R8
- R0–R2: wymagane fundamenty bezpieczeństwa, danych i infrastruktury.
- R3: stabilne kontrakty i integracje; testy integracyjne są obecnie odroczone i nie są warunkiem rozpoczęcia analizy/implementacji Memory V1.
- R4: Assistant, Memory, Learning i Planner.
- R5: Alice Life.
- R6: Alice Home i Alice Media.
- R7: interfejsy i wydania.
- R8: Alice Flow i rozwinięta proaktywność.

## Najbliższy backlog
1. Zinwentaryzować istniejącą pamięć i mechanizmy kontekstu w LLM/Knowledge.
2. Zaprojektować schemat pamięci z pochodzeniem, pewnością, aktualnością i retencją.
3. Zdefiniować API zapisu, odczytu, korekty, eksportu i usunięcia pamięci.
4. Ustalić politykę zapisywania informacji (jawne fakty vs automatyczne hipotezy).
5. Przygotować testy jednostkowe logiki pamięci i plan późniejszych testów integracyjnych.
6. Rozpisać Issues po weryfikacji kodu i zależności.
