# Alice Assistant — specyfikacja produktowa V1

> Status: projekt specyfikacji do dalszego uszczegółowienia. Zatwierdzone decyzje źródłowe: [PRODUCT_DECISIONS_2026-10-30.md](../../PRODUCT_DECISIONS_2026-10-30.md). Nie jest to potwierdzenie implementacji.

## 1. Misja
Alice Assistant to jedna spójna inteligencja osobista użytkownika, działająca przez różne kanały interakcji i delegująca złożone zadania wyspecjalizowanym agentom. Pozostaje jedną rozpoznawalną osobowością, niezależnie od modeli i liczby wykonawców.

## 2. Granice odpowiedzialności
**Assistant odpowiada za:** rozmowę, rozumowanie, interpretację intencji, zarządzanie kontekstem, pamięć i uczenie, inicjatywę, planowanie celów, delegację zadań oraz syntezę wyników.

**Assistant nie odpowiada za:** bezpośrednie obchodzenie polityk dostępu, niezależny silnik wykonania automatyzacji, przechowywanie danych domenowych jako źródło prawdy ani wykonywanie krytycznych zabezpieczeń domu przez LLM.

**Flow odpowiada za:** trwałe zadania i harmonogramy, egzekwowanie uprawnień, zatwierdzenia, wykonanie, retry, idempotencję, audyt, limity i odzyskiwanie po błędach.

**Life/Home/Media odpowiadają za:** domenowe dane, walidację i dozwolone operacje udostępniane przez kontrolowane interfejsy.

## 3. Siedem zdolności logicznych
1. **Identity & Personality:** spójna, przyjazna, analityczna i krytyczna osobowość; bez udawania człowieka, manipulacji i zawstydzania.
2. **Conversation & Reasoning:** wieloetapowa analiza, wskazywanie niepewności, rozróżnienie faktów od hipotez, wyjaśnianie decyzji.
3. **Memory:** trwała pamięć preferencji, epizodów, wiedzy i decyzji; pochodzenie, datowanie, korekta, eksport, retencja i usuwanie.
4. **Learning:** aktualizacja preferencji i strategii na podstawie jawnych ocen i sprawdzalnych wyników; uczenie nie rozszerza uprawnień.
5. **Goals & Planning:** cele krótko- i długoterminowe, priorytety, proaktywne propozycje, nocne przygotowanie zadań i poranny briefing.
6. **Agent Orchestration:** delegowanie zadań do agentów domenowych z ograniczonym kontekstem, czasem, zasobami i uprawnieniami; walidacja i scalanie rezultatów.
7. **Context & Interaction:** Web/Desktop/Browser, głos, Ambient AI, Particle Identity 2D, stany prywatności, ograniczenia powiadomień.

## 4. Model hybrydowy
- Jeden punkt kontaktu i jedna tożsamość Alice.
- Agent domenowy jest wykonawcą zadania, nie osobną osobowością.
- Proste operacje są realizowane przez deterministyczne narzędzia; agenci LLM tylko gdy to uzasadnione.
- Delegacja nie może podnieść uprawnień ani ominąć Flow.
- Wynik agenta zawiera status, dowody/źródła, wykonane operacje, błędy, niepewności i identyfikator śladu audytowego.
- Wykonawca może zwrócić potrzebę doprecyzowania lub zgody, zamiast zgadywać.

## 5. Przepływ przykładowego zadania
**Cel:** przygotowanie nocnego raportu zużycia mediów.
1. Assistant rozpoznaje cel i wymagane dane.
2. Planner tworzy plan; Flow rejestruje i harmonogramuje wykonanie.
3. Flow egzekwuje uprawnienia i wywołuje dozwolone operacje Home oraz Life.
4. Dane są walidowane pod kątem aktualności i kompletności.
5. Obliczenia wykonują deterministyczne funkcje, a nie LLM.
6. Assistant interpretuje anomalie i tworzy briefing z oznaczeniem brakujących danych.
7. Flow zapisuje wynik i ślad audytowy; Alice przedstawia raport w odpowiednim czasie.

## 6. Wymagania przekrojowe
- Local-first dla pamięci i danych osobistych, z kontrolowanymi wyjątkami integracyjnymi.
- Brak domyślnego ciągłego nagrywania; fizyczne wyłączenie mikrofonów i jasne stany prywatności.
- Kontrola retencji, źródeł kontekstu, zgód, eksportu i usuwania.
- Ochrona przed prompt injection: treść maili, stron i dokumentów jest danymi, nie instrukcjami uprawniającymi do działania.
- Audyt decyzji i działań, możliwość zatrzymania, limity czasu/zasobów, tryb dry-run i rollback tam, gdzie możliwy.
- Bezpieczne autonomiczne wdrażanie automatyzacji wyłącznie w zatwierdzonym zakresie i po weryfikacji.
- Nie utożsamiać jakości odpowiedzi z samym sukcesem pipeline'u; testować scenariusze użytkownika.

## 7. Proponowane kontrakty (do zatwierdzenia technicznego)
- **TaskRequest:** id, cel, inicjator, kontekst referencyjny, uprawnienia, priorytet, deadline, budżet.
- **DelegationRequest:** taskId, agentType, zakres danych, dozwolone operacje, timeout, correlationId.
- **TaskResult:** taskId, status, rezultat, źródła, wykonane akcje, błędy, wymagane zatwierdzenia, auditRef.
- **UserFeedback:** subjectId, ocena, zakres preferencji, data, źródło; bez automatycznej eskalacji uprawnień.
To kandydaci do API, nie istniejące kontrakty.

## 8. Scenariusze akceptacyjne
1. Alice pamięta zatwierdzoną preferencję po restarcie i zmianie modelu; użytkownik może ją poprawić i usunąć.
2. Alice deleguje złożoną analizę, zbiera wyniki i prezentuje jedną odpowiedź wraz z niepewnościami.
3. Odmowa uprawnienia blokuje wykonanie również przez agenta podrzędnego.
4. Ponowienie po awarii nie duplikuje skutków ubocznych.
5. Alice przygotowuje briefing z poczty, pogody i mediów, nie wymyślając brakujących stawek i pomiarów.
6. Alice może wdrożyć bezpieczną automatyzację wyłącznie w preautoryzowanym zakresie, z audytem i testem.
7. Wyłączenie mikrofonu i ograniczenie dostępu do kontekstu są respektowane niezależnie od modelu.
8. Brak dostępnego modelu nie wyłącza krytycznych automatyzacji bezpieczeństwa domu.

## 9. Zależności i niewiadome
- Wymagany audyt kodu LLM, Knowledge, Time Coordinator, Node/Node Manager i Web/Desktop, aby przypisać odpowiedzialności bez dublowania usług.
- Do doprecyzowania: schemat pamięci, protokół delegacji, polityki zgód, modele priorytetów, metryki skuteczności, retencja danych, kanały głosowe.
- Kolejny dokument: szczegółowa specyfikacja Alice Flow i kontrakt wykonania/delegacji.
