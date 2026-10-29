# ALICE Unit Test Gate v1 — progi przejściowe

Data decyzji: 2026-10-30. Zakres: repozytoria aplikacyjne AliceAI; testy integracyjne są odroczone.

## Przyjęte cele
- **15% pokrycia linii** — początkowy minimalny próg dla zwykłego kodu aplikacyjnego, po uruchomieniu poprawnego pomiaru.
- **30% pokrycia linii** — cel kolejnej iteracji dla zwykłego kodu; na razie nie blokuje CI.
- **50% pokrycia linii** — docelowe minimum dla wyodrębnionych modułów logiki krytycznej (np. uwierzytelnianie, operacje finansowe, integralność danych). Zanim będzie egzekwowane, właściciel modułu musi wskazać jego zakres i sposób pomiaru.
- **80%** — możliwy cel długoterminowy, nieobowiązujący obecnie.

Procenty odnoszą się do **pokrycia wykonywalnych linii kodu przez testy jednostkowe**, a nie do odsetka klas, liczby testów ani powodzenia pipeline. Pokrycie gałęzi raportować informacyjnie, bez minimalnego progu na tym etapie.

## Wdrażanie bez fałszywie zielonych i fałszywie czerwonych wyników
1. Zinwentaryzować istniejące przypadki testowe oraz mierzalne moduły, w tym Alice Desktop.
2. Włączyć narzędzie pomiarowe właściwe dla języka; oddzielić unit od integracyjnych i smoke; ujawniać zero testów, brak raportu lub błąd instrumentacji jako „brak wiarygodnego pomiaru”, a nie 0% czy sukces.
3. Zebrać wartość bazową dla każdego repozytorium i oznaczyć moduły krytyczne; udokumentować uzasadnione wyłączenia kodu generowanego, GUI i platformowego.
4. Dopiero po weryfikacji raportów uruchomić blokowanie CI dla minimalnych 15% zwykłego kodu oraz 50% modułów krytycznych, etapowo i bez ignorowania istniejących testów. Do tego czasu progi są przyjętym standardem, **nie są jeszcze technicznie egzekwowane**.
5. Każdy wykonany test musi przejść; nowe zmiany nie powinny zmniejszać pokrycia względem ustalonej bazy. Cel 30% jest następny, a późniejsze podniesienie do 80% wymaga osobnej decyzji.

Wyniki dokumentować dla konkretnego commita: liczba testów wykonanych / pominiętych / błędnych, pokrycie linii, zakres pomiaru, narzędzie i artefakty. Testy integracyjne pozostają na późniejszy etap.
