# AliceAI — audyt kontraktów API i kontroli dostępu (etap 1)

Data: 2026-10-30. **Metoda:** statyczny odczyt kodu wybranych kontrolerów w gałęziach domyślnych; bez wysyłania żądań HTTP, bez testów integracyjnych i bez oceny konfiguracji reverse proxy. Zakres nie stanowi audytu penetracyjnego ani potwierdzenia braku autoryzacji w całej instalacji.

## Macierz kontraktów potwierdzonych kodem

| Repozytorium | Kontroler | Zidentyfikowane endpointy (przykłady) | Dowód |
| --- | --- | --- | --- |
| LLM | AssistantController | `GET /api/llm/assistant/bootstrap`; `GET,POST /api/llm/assistant/conversations`; `DELETE,PATCH /api/llm/assistant/conversations/{id}`; `POST /api/llm/assistant/conversations/{id}/messages`; `POST .../messages/stream` | `src/main/java/alice/llm/controller/AssistantController.java` |
| Knowledge | KnowledgeProjectController | `GET,POST /api/knowledge/projects`; `GET,PUT,DELETE /api/knowledge/projects/{id}`; `GET,PUT /api/knowledge/projects/{id}/files`; `GET .../{id}/archive`; `POST .../{id}/uploads`; `DELETE .../{id}/resources` | `src/main/java/alice/knowledge/controller/KnowledgeProjectController.java` |
| Mail | MailController | `POST /api/mail/send`; `GET,POST /api/mail/accounts`; `POST /api/mail/accounts/{accountId}/sync`; `DELETE /api/mail/accounts/{accountId}/messages/{messageId}/server`; `DELETE /api/mail/queues`; `GET /api/mail/accounts/{accountId}/attachments/{attachmentId}/download` | `src/main/java/alice/mail/controller/MailController.java` |
| Time Coordinator | GoogleCalendarController | `GET,POST /api/google/calendar/accounts`; `GET /api/google/calendar/oauth/start`; `GET /api/google/calendar/oauth/callback`; `GET,POST /api/google/calendar/events`; `DELETE /api/google/calendar/events/{eventId}`; `POST /api/google/calendar/sync` | `src/main/java/alice/time/coordinator/controller/GoogleCalendarController.java` |
| Alice Web | Bez kompletnej mapy tras | Potwierdzono konfigurację `node --test` w CI, ale **nie** potwierdzono wszystkich tras HTTP/proxy w tym etapie | `.gitlab-ci.yml`, `package.json` |

Przykłady nie są kompletną listą wszystkich endpointów, nawet w obrębie wskazanych kontrolerów. Wymagane parametry, statusy błędów i warunki uprawnień należy zweryfikować osobno, zanim powstanie pełny kontrakt API.

## Ustalenia bezpieczeństwa — wymagające weryfikacji

1. **Operacje zmieniające stan:** w odczytanych kontrolerach występują operacje usuwania konwersacji, zasobów Knowledge, wiadomości na serwerze pocztowym, zadań w kolejkach i wydarzeń kalendarza. Należy sprawdzić, czy każda operacja wymaga odpowiedniego uwierzytelnienia i autoryzacji, w szczególności izolacji zasobów między użytkownikami.
2. **Brak widocznych adnotacji method-level:** we wskazanych czterech kontrolerach nie wystąpiły adnotacje `@PreAuthorize`, `@Secured` ani `@RolesAllowed` w odczytanej treści. **Nie oznacza to braku zabezpieczeń** — mogą działać filtry, konfiguracja sieci, API gateway lub własne mechanizmy.
3. **Knowledge:** `pom.xml` nie deklaruje zależności `spring-boot-starter-security`; konieczne jest osobne potwierdzenie ochrony API na poziomie całej ścieżki wejścia. Szczególny priorytet: odczyt, eksport i modyfikacja plików.
4. **Time Coordinator:** endpointy OAuth i manipulacji kalendarzem wymagają przeglądu weryfikacji `state`, zakresów dostępu, odświeżania tokenów i zabezpieczenia rejestru kont.
5. **Mail:** endpointy wysyłania i usuwania wiadomości oraz zarządzania kontami wymagają przeglądu autoryzacji, ograniczeń wywołań oraz bezpiecznego przechowywania poświadczeń.
6. **LLM:** operacje na rozmowach i strumieniach odpowiedzi wymagają sprawdzenia izolacji konwersacji, uprawnień do narzędzi i ograniczeń zasobów.

## Status i dalsze czynności

- **P0 — przegląd kontroli dostępu:** odczytać konfiguracje Spring Security / filtry / reverse proxy dla każdej usługi, zweryfikować ścieżkę wejścia oraz ewentualne wyjątki; nie przesądzać podatności bez dowodu.
- **P0 — pełna macierz API:** odczytać wszystkie kontrolery i trasy proxy, zestawić z dokumentacją parametrów i odpowiedzi.
- **P1 — autoryzacja obiektowa:** skontrolować dostęp do `id`, `accountId`, plików i konwersacji; weryfikować ograniczenia po stronie serwera.
- **P1 — walidacja i obsługa błędów:** sprawdzić wejścia, limity załączników, sanitizację błędów i bezpieczeństwo logowania.
- **P2 — aktualizacja README:** poprawiać tylko potwierdzone rozbieżności, zachować historyczne zapisy z oznaczeniem dat.

**Stan:** `PARTIAL / STATIC_VERIFICATION`. Brak potwierdzonych exploitów, brak skanowania podatności i brak podstaw do stwierdzenia gotowości produkcyjnej.
