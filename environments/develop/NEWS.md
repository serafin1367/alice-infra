# Alice News Service — wdrożenie DEV

**Zakres:** wyłącznie `environments/develop`. Środowisko produkcyjne nie jest zmieniane. Kod aplikacji: [alice-news-service](https://github.com/serafin1367/alice-news-service). GitHub jest źródłem kodu; GitLab wykonuje CI po synchronizacji.

## Architektura

- `news-service` (Java 21, Spring Boot, kontener `alice-dev-news-service`), wewnętrznie `news-service:8080`
- wspólny `postgres:5432`, **oddzielna baza** `alice_news` i konto `alice_news`
- wspólny `rabbitmq:5672`, vhost `alice`
- dostęp z hosta **tylko** `127.0.0.1:19090` (port można zmienić przez `NEWS_PUBLIC_PORT`)
- Flyway `V1`–`V3` uruchamia się wraz z aplikacją
- `/actuator/health/readiness` — kontrola gotowości kontenera, bez instalacji curl/wget w obrazie

`NEWS_RSS_ENABLED=false` i `NEWS_ENRICHMENT_ENABLED=false` są domyślnie ustawione na DEV. Nie następuje automatyczne pobieranie RSS ani wywoływanie LLM przed ich świadomym włączeniem.

## Przygotowanie

Uruchom PowerShell w katalogu `alice-infra/environments/develop`.

1. Aktualizuj `alice-infra` i uruchom `./pull-all.ps1`. Skrypt sklonuje brakujące `alice-news-service` do `microservices/news` (ten sam poziom co `microservices/media`, `microservices/health`). Nie nadpisuje lokalnych zmian.
2. Uzupełnij prywatny plik `.env` na podstawie `.env.example` (bez commitowania haseł). Jeśli `.env` już istnieje, **dopisz tylko zmienne NEWS_**, nie zastępuj całego pliku. Dla lokalnego DEV użyj własnego hasła `NEWS_DB_PASSWORD` oraz długiego losowego `NEWS_ADMIN_TOKEN` (pusty token blokuje administracyjne API).
3. Upewnij się, że działają Docker Desktop/Engine i Compose v2.

Najważniejsze parametry:

```dotenv
NEWS_DB_NAME=alice_news
NEWS_DB_USERNAME=alice_news
NEWS_DB_PASSWORD=ustaw-wlasne-haslo-tylko-w-prywatnym-env
NEWS_PUBLIC_PORT=19090
NEWS_ADMIN_TOKEN=ustaw-dlugi-losowy-token-tylko-w-prywatnym-env
NEWS_RSS_ENABLED=false
NEWS_ENRICHMENT_ENABLED=false
NEWS_LLM_BASE_URL=http://llm-service:8084
NEWS_LLM_PROFILE_ID=0
```

Nie używaj przykładowych haseł w środowisku produkcyjnym. Zmiana hasła w `.env` **nie zmienia automatycznie hasła istniejącej roli PostgreSQL** — wymaga osobnej kontrolowanej rotacji.

## Jednorazowe wdrożenie / aktualizacja News

```powershell
./pull-all.ps1
./rebuild-news.ps1
```

`rebuild-news.ps1` wykonuje:

1. Uruchamia `postgres` i `rabbitmq` DEV i czeka na ich healthchecki.
2. W istniejącym kontenerze PostgreSQL uruchamia `09-init-news-database.sh`. Skrypt tworzy rolę i bazę **tylko jeśli nie istnieją**.
3. Buduje obraz `news-service`, uruchamia go bez restartowania innych mikroserwisów i oczekuje stanu `healthy`.
4. Sprawdza `/actuator/health/readiness`, `/api/news/categories` i `/api/news/articles` przez lokalny port z Compose.

**Nie usuwaj wolumenu `postgres_data` ani nie wykonuj `docker compose down -v`.** Skrypty `docker-entrypoint-initdb.d` nie uruchamiają się automatycznie na już istniejącym wolumenie; właśnie dlatego dedykowany skrypt wykonuje inicjalizację jawnie.

Alternatywa ręczna:

```powershell
docker compose --env-file .env up -d --wait postgres rabbitmq
docker compose --env-file .env exec -T postgres bash /docker-entrypoint-initdb.d/09-init-news-database.sh
docker compose --env-file .env up -d --build --no-deps --wait news-service
docker compose --env-file .env ps news-service
curl.exe --fail http://127.0.0.1:19090/actuator/health/readiness
curl.exe --fail http://127.0.0.1:19090/api/news/categories
curl.exe --fail http://127.0.0.1:19090/api/news/articles
```

Nie używaj `--no-deps` podczas pierwszego uruchomienia zależności. Powyższy wariant ręczny najpierw uruchamia bazę i RabbitMQ.

## Kontrolowany pierwszy import RSS (kolejny etap DEV)

Import uruchamiamy **po** poprawnym wdrożeniu News i przejściu
`/api/news/articles`. Ten etap nie włącza harmonogramu RSS ani LLM.

Skrypt `news_rss_smoke.py` działa w Pythonie 3 (standard library, bez instalacji
pakietów). Wymaga lokalnego API `127.0.0.1:19090` i tokenu administratora
w prywatnym `.env` uruchomionego kontenera.

W PowerShell, w `alice-infra/environments/develop`:

```powershell
./pull-all.ps1
./rebuild-news.ps1
py -3 ./news_rss_smoke.py --list
py -3 ./news_rss_smoke.py
```

Przy braku launchera `py`, użyj `python` zamiast `py -3`.

1. `--list` **tylko odczytuje** readiness, listę artykułów i aktywne źródła.
   Nie potrzebuje tokenu ani nie zmienia danych.
2. Druga komenda wyświetla aktywne źródła, prosi o wybranie **jednego**
   przez numer i jawne wpisanie `TAK`.
3. Token `NEWS_ADMIN_TOKEN` jest pobierany niewidocznie z terminala
   (`getpass`), **nie** podawaj go jako parametr CLI ani nie zapisuj
   polecenia z tokenem w historii PowerShell.
4. Skrypt wykonuje **jeden** `POST /api/news/admin/import/{sourceId}`,
   sprawdza `seen`, `inserted`, `error` i ponowny odczyt artykułów.
   Nie przełącza `NEWS_RSS_ENABLED` ani `NEWS_ENRICHMENT_ENABLED`.
5. Odmowa potwierdzenia, błąd readiness / odczytu artykułów lub nieprawidłowy
   token **przerywa** import. W razie problemu sprawdź
   `docker compose --env-file .env logs --tail 120 news-service`.

Można również wskazać pojedyncze źródło jawnie:

```powershell
py -3 ./news_rss_smoke.py --source-id 00000000-0000-0000-0000-000000000000
```

Zamień przykładowy UUID na identyfikator z `--list`. Nadal wymagane jest
potwierdzenie i token. Skrypt **nie obsługuje importu wszystkich źródeł na raz**.

### Kryteria akceptacji

- `/actuator/health/readiness` zwraca `UP`, a `/api/news/articles`
  poprawną listę (również pustą przed importem).
- Wybrane źródło jest aktywne i import kończy się z `error = null`.
- `seen > 0`; `inserted > 0` potwierdza nowe artykuły.
  Jeśli `inserted = 0`, wpisy mogły już istnieć — to nie jest
  dowód nowego importu; sprawdź stan bazy i historię importów.
- Odczyt artykułów po imporcie zwraca poprawną listę.
- `news_import_run` odnotowuje wynik; częściowe błędy zapisu artykułów
  są zgłaszane jako `FAILED` zamiast pozornego sukcesu.
- `NEWS_RSS_ENABLED=false` i `NEWS_ENRICHMENT_ENABLED=false` pozostają
  bez zmian.

Interpretacja kodu zakończenia skryptu: `0` — brak błędów raportowanych przez
API (również przy deduplikacji), `1` — błąd, `2` — `seen=0` lub brak
widocznych artykułów mimo `inserted>0` — import niepotwierdzony. Zbieranie i pełna weryfikacja na lokalnym Dockerze wymagają
uruchomienia polecenia na hoście DEV; zielone CI samo nie potwierdza importu.

### Potwierdzenie w bazie (opcjonalnie)

Na istniejącym wolumenie PostgreSQL:

```powershell
docker compose --env-file .env exec -T postgres psql -U postgres -d alice_news -c "SELECT status,items_seen,items_inserted,finished_at FROM news_import_run ORDER BY id DESC LIMIT 5;"
docker compose --env-file .env exec -T postgres psql -U postgres -d alice_news -c "SELECT COUNT(*) AS total_articles FROM news_article;"
```

Jeśli dostosowałeś `NEWS_DB_NAME` lub `POSTGRES_SUPERUSER` w `.env`,
użyj odpowiadających im wartości. Zapytania są tylko do odczytu.

## Alice Web — wspólny panel boczny i brama API (DEV)

Alice Web ma już widok `/news/` i pozycję **Aktualności** we wspólnym menu
bocznym. Frontend używa `GET /api/news/categories`,
`GET /api/news/articles` oraz `GET /api/news/sources`, które Nginx
przekazuje do `http://news-service:8080` wewnątrz sieci Docker.
Połączenie jest konfigurowane zmienną
`ALICE_WEB_NEWS_UPSTREAM=http://news-service:8080` (w Compose jest też
taki sam bezpieczny domyślny adres).

Nie publikujemy nowego portu do Alice Web ani administracyjnego API RSS.
Brama odrzuca metody inne niż GET dla prefiksu `/api/news/`. Token
`NEWS_ADMIN_TOKEN` pozostaje wyłącznie w mikroserwisie News.

Zaktualizuj kod, następnie w PowerShell uruchom:

```powershell
cd alice-infra/environments/develop
.\pull-all.ps1
.\rebuild-news-web.ps1
```

Jeśli News został już niedawno przebudowany i jest gotowy, można ograniczyć
odtwarzanie do samego Alice Web:

```powershell
.\rebuild-news-web.ps1 -SkipNewsRebuild
```

Skrypt buduje tylko Alice Web, odtwarza jego kontener oraz sprawdza:
- `GET /health` — gotowość Nginx;
- `GET /news/` — istniejący widok i wspólna nawigacja;
- `GET /api/news/categories`, `articles?limit=1` i `sources` —
  rzeczywistą trasę od przeglądarki przez Nginx do News;
- `POST /api/news/categories` — HTTP 403 (zablokowane zapisy).

Prawidłowy wynik oznacza, że moduł jest dostępny pod
**http://127.0.0.1:19080/news/** (lub lokalnym portem z `.env`).
Widok prezentuje nazwy kategorii, karty z miniaturkami, opcjonalną ocenę AI,
priorytet kategorii i odsyłacze do oryginalnych materiałów.

**Ważne:** kategorie mają priorytet 1–3, ale ocena ważności AI 0–100
zostanie wypełniona dopiero po uruchomieniu przetwarzania LLM. Sortowanie
w interfejsie obejmuje tylko pobraną pulę maksymalnie 100 artykułów.

Potwierdzony wcześniej kontrolowany import Ars Technica zapisał 20 nowych
artykułów na DEV. Nie dowodzi to dostępności innych źródeł RSS ani działania
automatycznego harmonogramu. Ten etap nie dotyka produkcji.

## Diagnostyka

```powershell
docker compose --env-file .env config --quiet
docker compose --env-file .env ps news-service postgres rabbitmq
docker compose --env-file .env logs --tail 150 news-service
docker compose --env-file .env exec -T postgres pg_isready -U postgres -d postgres
```

Przed ponownym `rebuild-all.ps1` zaktualizuj kod News (skrypt `pull-all.ps1` klonuje brakujące repozytoria). `rebuild-all.ps1` zawiera teraz News i idempotentny bootstrap jego bazy.

## Ograniczenia

Routing `/api/news` i widok Aktualności istnieją już w Alice Web; konfiguracja DEV wymaga wdrożenia przez `rebuild-news-web.ps1`. Port serwisu News pozostaje dostępny tylko z hosta DEV, natomiast żądania z przeglądarki obsługuje brama Alice Web. Zapis na GitHubie oraz pozytywny GitLab CI nie zastępują testu na lokalnym Dockerze.
