# AliceAI — rejestr decyzji produktowych (2026-10-30)

> Status: zatwierdzone założenia docelowe, nie potwierdzenie implementacji. Dokument uzupełnia [PRODUCT_VISION.md](PRODUCT_VISION.md) i [ROADMAP.md](ROADMAP.md).

## Charakter i relacja z użytkownikiem
- Alice to osobista asystentka jednego użytkownika: naturalna, przyjazna, analityczna, krytyczna i niepotakująca.
- Pełni rolę wymagającej mentorki: pomaga realizować cele, reaguje na prokrastynację bez manipulacji, zawstydzania i nieuzasadnionej presji.
- Aktywnie inicjuje przeglądy dnia i tygodnia, proponuje zmiany planów i cele; użytkownik może ograniczać inicjatywę.
- Nie udaje człowieka ani nie przedstawia wygenerowanej ekspresji jako ludzkich emocji.

## Kontekst i Ambient AI
- Szeroka świadomość kontekstu komputera i domu wyłącznie w granicach jawnych uprawnień; wyłączenia źródeł i aplikacji, kontrola retencji i natychmiastowy stop.
- Dostępność głosowa na komputerze i w domu, lokalne wykrywanie słowa wybudzającego, możliwość inicjowania krótkich rozmów.
- Fizyczne odłączanie mikrofonów, widoczne stany prywatności; brak domyślnego ciągłego nagrywania.

## Alice Particle Identity 2D
- Abstrakcyjna reprezentacja bez twarzy i ciała, złożona z drobnych świetlnych punktów; lekki renderer 2D.
- Płynny, organiczny ruch; dowolne kolory, kształty, symbole, fale, spirale i transformacje (morphing).
- Swobodna autonomia estetyczna: Alice eksperymentuje, rozwija rozpoznawalny styl, samodzielnie nazywa i opisuje kompozycje.
- Może porównywać nową i poprzednią formę oraz pytać użytkownika o preferencje; oceny pozytywne i negatywne wspierają uczenie.
- Zaplanowane sesje kreatywne o niskim priorytecie, ograniczone czasowo i zasobowo; estetyka nie jest głównym zadaniem Alice.
- Historia i wersjonowanie kompozycji, cofanie zmian, dostępność (ograniczenie ruchu/migania), ochrona czytelności UI.
- LLM proponuje deklaratywne parametry, lokalny silnik je waliduje i renderuje; bez wykonywania dowolnego kodu animacji.

## Produktywne działania w tle i nocą
- Nocny czas i wolne zasoby mają przede wszystkim służyć realnym zadaniom, nie generowaniu sztuki.
- Poczta: wykrywanie spamu, klasyfikacja, streszczenia, przygotowanie szkiców odpowiedzi.
- Home: raporty zużycia prądu, wody i innych dostępnych mediów, wykrywanie anomalii, obliczanie kosztów z taryfami podanymi przez użytkownika.
- Life: raport pogodowy, plan dnia, kalendarz, podsumowanie zdarzeń z nocy/dnia.
- Infrastructure: analiza logów, monitoringu, backupów i wyników CI/CD, rekomendacje napraw.
- Brakujące informacje (np. cena za kWh, zakres opłat) Alice ustala pytaniem; nie wymyśla stawek. Rozróżnia koszt zmienny od całego rachunku.
- Zadania są priorytetyzowane i wykonywane według dostępnych zasobów; jeśli nie ma użytecznej pracy, oszczędzanie energii ma pierwszeństwo.
- Poranny briefing podsumowuje działania, wyniki, anomalie i decyzje oczekujące na użytkownika.

## Rozszerzona autonomia i bezpieczne automatyzacje
- Alice może samodzielnie planować i wykonywać złożone, wieloetapowe zadania w ramach przyznanych uprawnień, z audytem i kontrolą ryzyka.
- Zatwierdzona decyzja: Alice **może samodzielnie projektować, testować i wdrażać nowe bezpieczne automatyzacje** w granicach wcześniej przyznanych uprawnień i limitów.
- Uprawnienia są szczegółowe: zasób, operacja, warunki, limity, czas obowiązywania i sposób zatwierdzenia; pozytywna ocena nie rozszerza uprawnień.
- Działania wrażliwe, nieodwracalne lub wykraczające poza politykę wymagają osobnej autoryzacji; bez domyślnego samodzielnego wysyłania wiadomości, płatności, trwałego usuwania danych i zmian krytycznych.
- Wymagane: audyt, idempotencja, kolejka zatwierdzeń, dry-run, rollback gdy możliwy, limity zasobów, izolacja wykonania, odzyskiwanie po awarii i kill switch.
- Krytyczne zabezpieczenia domu nie mogą zależeć od dostępności LLM lub internetu.
- Uczenie na podstawie wyników i opinii użytkownika dotyczy skuteczności i preferencji, ale nie samodzielnego przyznawania sobie nowych praw.

## Priorytety
1. Bezpieczeństwo i sytuacje krytyczne.
2. Zadania terminowe i zobowiązania.
3. Produktywne raporty, analizy, przygotowanie odpowiedzi i automatyzacje.
4. Utrzymanie pamięci i wiedzy.
5. Rozwój estetyczny i sesje kreatywne.

## Otwarte parametry implementacyjne
- Harmonogram, budżet zasobów i częstotliwość sesji kreatywnych.
- Konkretne role, polityki uprawnień, procedury zatwierdzania i kryteria klasyfikacji ryzyka.
- Lista istniejących komponentów AliceAI, które mogą przejąć nowe odpowiedzialności, do potwierdzenia audytem kodu.
- Mierniki skuteczności nocnych zadań, testy bezpieczeństwa i polityka retencji logów.

## Architektura inteligencji — decyzja zatwierdzona
- Model **hybrydowy**: jedna rozpoznawalna osobowość Alice i centralna koordynacja rozmów, celów, pamięci oraz decyzji.
- Wyspecjalizowani agenci są uruchamiani na potrzeby złożonych zadań domenowych (np. Mail, Home, Life, Media, infrastruktura), a nie jako niezależne osobowości.
- Centralny koordynator deleguje zadania z ograniczonym zakresem danych, uprawnień, czasu i zasobów; odbiera wyniki i przedstawia je użytkownikowi spójnym głosem Alice.
- Każdy agent podlega wspólnej polityce autoryzacji, audytu, limitów i zatwierdzeń. Delegacja nie może zwiększać uprawnień.
- Preferowane są zwykłe deterministyczne narzędzia do prostych operacji; dodatkowy agent/LLM jest uruchamiany tylko, gdy złożoność zadania to uzasadnia.
- Pięć filarów (Assistant, Life, Home, Media, Flow) pozostaje logicznym podziałem produktu, nie wymusza pięciu agentów ani mikroserwisów.
- Szczegóły protokołu delegacji, izolacji, pamięci agentów i przyporządkowania do istniejących usług pozostają do zaprojektowania i zweryfikowania w kodzie.
