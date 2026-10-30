# AliceAI — weryfikacja dokumentacji mikroserwisów z kodem i CI

**Data:** 2026-10-30. **Zakres:** LLM, Knowledge, Mail, Time Coordinator i Alice Web. Badanie statyczne plików `README.md`, `.gitlab-ci.yml`, manifestów zależności (`pom.xml` / `package.json`) i wybranych kontrolerów Java z gałęzi `main`. Bez wykonania aplikacji, skanowania podatności ani audytu wszystkich klas.

## Ustalenia potwierdzone

| Repozytorium | Dokumentacja | Dowód w kodzie/konfiguracji | Ocena |
| --- | --- | --- | --- |
| LLM | Dostawcy modeli, HTTP API asystenta; Java 17 i Spring Boot 3.5.15 | `pom.xml` definiuje Java 17 / Spring Boot 3.5.15, `AssistantController.java` ma `@RequestMapping("/api/llm/assistant")`; CI uruchamia `mvn verify` i publikuje JUnit/JaCoCo | Zgodność wybranych deklaracji potwierdzona, inne wymagają przeglądu |
| Knowledge | Projekty i dokumenty, Java/Spring, ograniczenia bezpieczeństwa | `KnowledgeProjectController.java` udostępnia `/api/knowledge/projects`; `pom.xml` nie deklaruje zależności Spring Security; CI uruchamia Maven i oddzielne testy bazodanowe w Docker | Wybrane deklaracje potwierdzone; autoryzacja na brzegu sieci niezweryfikowana |
| Mail | Spring Boot, AMQP, SMTP, PostgreSQL, JaCoCo | `pom.xml` zawiera Spring Mail, AMQP, JDBC i JaCoCo; CI wywołuje `mvn verify` i publikuje raporty | Zależności i bramka CI potwierdzone; rzeczywiste przepływy SMTP/IMAP i autoryzacja NIEZWERYFIKOWANE |
| Time Coordinator | Calendar / konta Google, Java 17 i usługi zewnętrzne | `GoogleCalendarController.java` ma `/api/google/calendar` i endpoint `/accounts`; `pom.xml` zawiera biblioteki Google, Spring AMQP i JDBC; CI publikuje JUnit/JaCoCo | Część kontraktu i zależności potwierdzona; rzeczywiste OAuth/Google API NIEZWERYFIKOWANE |
| Alice Web | Aplikacja WWW, model 3D, testy Node | `package.json` ma `three`, `vite` i `build:model-3d`; CI testuje `tests/*.test.mjs` i publikuje JUnit; buduje obraz Docker | Przebieg CI potwierdzony; pełna mapa API, autoryzacja i wdrożenie NIEZWERYFIKOWANE |

## Ważne granice dowodów

- Istnienie zależności Spring Security lub jej brak w `pom.xml` **nie dowodzi** skuteczności lub braku ochrony całego systemu. Trzeba zweryfikować ingress, proxy, kontrolery i mechanizmy uwierzytelniania.
- W repozytorium Knowledge CI zawiera osobne zadania testów wymagających izolowanej bazy PostgreSQL. Nie należy oznaczać wszystkich testów z pipeline jako wyłącznie jednostkowych bez klasyfikacji testów.
- `mvn verify` w LLM i Mail oraz `scripts/ci-test.sh` w Time Coordinator mogą uruchamiać różne rodzaje testów; obecność raportu JUnit lub JaCoCo sama nie przesądza o charakterze testów.
- Stwierdzenia README o „braku potwierdzonych uruchomień” opisują zakres historycznego audytu dokumentacji, a nie aktualny stan CI. Bieżące statusy pobierać z `alice-ci-reports/index.json`.
- Nie przeprowadzono pełnej analizy implementacji ani skanowania CVE. Nie deklarować statusu „kompletna dokumentacja”, „bezpieczne” albo „production ready”.

## Kolejna partia weryfikacji (bez uruchamiania testów integracyjnych)

1. **P0: kontrakty API:** dla każdego serwisu zestawić faktyczne `@RequestMapping`, `@GetMapping`, `@PostMapping`, itd. z rozdziałem API w README. Weryfikować ścieżkę, metodę, wymagane parametry i deklarowane błędy.
2. **P0: bezpieczeństwo:** sprawdzić uwierzytelnianie i autoryzację na poziomie kontrolerów, filtrów, reverse proxy oraz politykę tokenów; nie przyjmować istnienia ochrony na podstawie samej dokumentacji.
3. **P1: konfiguracja:** porównać zmienne środowiskowe z `application.yml`, Compose i plikami startowymi; nie kopiować do audytu rzeczywistych wartości sekretów.
4. **P1: klasyfikacja testów:** oznaczyć testy jednostkowe, bazodanowe i integracyjne, zachować decyzję o odroczeniu rozszerzania testów integracyjnych.
5. **P2: dokumentacja operacyjna:** potwierdzić monitoring, backup/restore, migracje i rollback w realnych manifestach i procedurach.

## Status

**PARTIAL / statycznie potwierdzone wybrane deklaracje.** Audyt pozwala przejść do szczegółowej macierzy kontraktów i bezpieczeństwa, ale nie zamyka oceny kompletności. Żadnych funkcji ani testów nie dodawano na siłę.
