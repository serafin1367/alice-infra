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
4. Sprawdza `/actuator/health/readiness` przez lokalny port z Compose.

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

## Pierwszy import RSS — osobny, świadomy test

Wykonaj dopiero po sprawdzeniu bazy, gotowości i ustawieniu prywatnego `NEWS_ADMIN_TOKEN` (wartość nie może być pusta). Import ręczny działa nawet przy wyłączonym harmonogramie RSS:

```powershell
# Zastap <token> swoim sekretem (nie zapisuj sekretu w historii polecen).
curl.exe -X POST -H "X-News-Admin-Token: <token>" http://127.0.0.1:19090/api/news/admin/import
```

Pole `error` w wyniku powinno być puste dla poprawnie odczytanych źródeł, a `inserted` może wynosić `0`, jeżeli wiadomości już znajdują się w bazie. Nie traktuj samego HTTP 200 jako dowodu, że wszystkie zewnętrzne źródła RSS działały.

Po udanym teście możesz ustawić `NEWS_RSS_ENABLED=true` w `.env` i odtworzyć tylko kontener News. Przetwarzanie przez LLM aktywuj dopiero po skonfigurowaniu istniejącego profilu i sprawdzeniu klienta LLM; samo `NEWS_LLM_PROFILE_ID=0` nie gwarantuje istnienia profilu.

## Diagnostyka

```powershell
docker compose --env-file .env config --quiet
docker compose --env-file .env ps news-service postgres rabbitmq
docker compose --env-file .env logs --tail 150 news-service
docker compose --env-file .env exec -T postgres pg_isready -U postgres -d postgres
```

Przed ponownym `rebuild-all.ps1` zaktualizuj kod News (skrypt `pull-all.ps1` klonuje brakujące repozytoria). `rebuild-all.ps1` zawiera teraz News i idempotentny bootstrap jego bazy.

## Ograniczenia

Ten etap nie dodaje jeszcze routingu `/api/news` przez Alice Web ani widoku Wiadomości. Port serwisu jest dostępny tylko z lokalnego hosta DEV; interfejs w Alice Web jest kolejnym etapem. Zapis konfiguracji w GitHubie i pozytywny pipeline GitLaba nie są dowodem wdrożenia ani działania usługi na lokalnym Dockerze.
