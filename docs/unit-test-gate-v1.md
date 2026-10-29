# ALICE Unit Test Gate v1 — jednolity próg pokrycia

Data decyzji: 2026-10-30. Zakres: repozytoria aplikacyjne AliceAI. Testy integracyjne pozostają odroczone.

## Zasada
**Minimalne wymagane pokrycie: 30% wykonywalnych linii kodu przez testy jednostkowe.** Jeden próg dla całego kodu aplikacyjnego — bez podziału na moduły krytyczne i zwykłe. To nie jest odsetek klas ani liczba testów. Pokrycie gałęzi można raportować informacyjnie, ale nie jest teraz warunkiem akceptacji.

## Wdrożenie
1. W każdym repozytorium rozdzielić jednostkowe od testów kontrolnych, integracyjnych i samego budowania aplikacji.
2. Skonfigurować wiarygodny pomiar pokrycia kodu testami jednostkowymi właściwy dla danego języka oraz udokumentować zakres pomiaru i wyłączenia, np. kod generowany lub zależności zewnętrzne.
3. W raportach CI podawać wynik pokrycia, liczbę wykonanych/pominiętych/nieudanych testów i commit. Brak wykonanych testów lub brak prawidłowego raportu nie może być traktowany jako zaliczenie bramki.
4. Po zweryfikowaniu pomiaru egzekwować **coverage >= 30%** w GitLab CI; wynik niższy powoduje niezaliczenie Unit Test Gate. Wszystkie uruchomione testy jednostkowe muszą zakończyć się sukcesem.
5. Nie uruchamiać testów integracyjnych ani nie zmieniać produkcji w ramach tego etapu.

**Stan wdrożenia:** ustalony próg jest normą dokumentacyjną. Nie oznacza to jeszcze, że wszystkie repozytoria raportują pokrycie lub że GitLab CI już blokuje wyniki poniżej 30%. Egzekwowanie wymaga osobnych, zweryfikowanych zmian w konfiguracji każdego projektu.

Wcześniejsza propozycja progów 15%, 50% i celu 80% została zastąpiona niniejszą decyzją.
