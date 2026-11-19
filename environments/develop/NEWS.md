> **Rzeczywisty wynik DEV — 2026-11-19:** jedna ręczna partia EN→PL (`./enrich-news.ps1`) zakończyła się `processed=10, succeeded=10, failed=0`. PostgreSQL wykazuje 10 angielskich artykułów `DONE/DONE` oraz 273 `PENDING/PENDING`, bez błędów. Automatyczne wzbogacanie pozostaje wyłączone. Pusta tabela podglądu w starszej wersji `enrich-news.ps1` wynikała z pobierania pierwszych pięciu ogólnych artykułów API zamiast ostatnich przetłumaczonych. Nowa wersja uruchamia tylko odczytowy `./show-news-translations.ps1 -Limit 5`, pokazujący oryginalny i polski tytuł, polskie streszczenie oraz ocenę AI. Polecenie można uruchomić samodzielnie bez wywoływania modelu. Sprawdź jakość tekstu przed włączeniem automatycznego harmonogramu.

> **Windows PowerShell 5.1 (poprawka 2026-11-19):** pierwsza wersja `diagnose-news-translations.ps1` miała znak typograficzny w pliku UTF-8 bez BOM, co mogło powodować `ParserError: The string is missing the terminator`. Poprawiona wersja jest zapisana wyłącznie znakami ASCII. Po `./pull-all.ps1` ponów `./diagnose-news-translations.ps1`. Samo `./enrich-news.ps1 -ShowTranslator` sprawdza tylko dostępność profilu `TRANSLATOR`; **nie dowodzi wykonania żadnego tłumaczenia**. Wyświetlanie nazwy `Tłumacz` jako błędnych znaków może być osobnym problemem kodowania terminala lub danych API, który wymaga odrębnej weryfikacji.

> **Diagnostyka tłumaczeń (2026-11-19):** z tego katalogu uruchom `./diagnose-news-translations.ps1`. Skrypt wyświetla na standardowym wyjściu wyłącznie zagregowane statystyki bazy `alice_news` i flagi wzbogacania działającego kontenera. Nie wymaga tokenu administratora, nie wywołuje LLM ani nie zmienia danych. Wynik `und` oznacza brak ustalonego języka artykułu; nie należy automatycznie traktować go jako angielskiego. Dla źródeł o znanym języku można ustawić język w panelu RSS na przyszłe importy. **Zmiana języka źródła nie naprawia już zapisanych rekordów**; ewentualną korektę danych należy przygotować i zatwierdzić osobno po przeglądzie wyników. Sprawdzenie profilu tłumacza: `./enrich-news.ps1 -ShowTranslator` (tylko odczyt).

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

Nie publikujemy dodatkowego portu administracyjnego. Brama odrzuca metody
inne niż GET dla zwykłego prefiksu `/api/news/`. Do zarządzania źródłami RSS
Nginx ma osobne, ściśle ograniczone trasy. Przeglądarka wysyła tylko
`X-Alice-News-Action: 1` (znacznik żądania AJAX, **nie sekret**);
Nginx dołącza `X-News-Admin-Token` odczytany po stronie serwera z
`NEWS_GATEWAY_ADMIN_TOKEN`. W Compose jest to **ta sama prywatna wartość**
`NEWS_ADMIN_TOKEN`, której wymaga mikroserwis News.
Sekret nie pojawia się w HTML/JS, localStorage, cookies ani żądaniu
przeglądarki. Przy pustym `NEWS_ADMIN_TOKEN` żądania administracyjne
pozostają zablokowane (HTTP 503) i należy ustawić sekret raz w `.env`
oraz odtworzyć kontenery Alice Web i News.

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

Jeśli oba kontenery już działają i chcesz **tylko potwierdzić integrację**
bez przebudowy, restartu, importu ani zmian w bazie danych, uruchom:

```powershell
.\rebuild-news-web.ps1 -VerifyOnly
```

Tryb `-VerifyOnly` korzysta z aktualnej konfiguracji Compose i prywatnego
`.env`, odczytuje opublikowany port istniejącego kontenera Alice Web,
sprawdza podane poniżej endpointy oraz odmowę niezapisującego żądania
`POST /api/news/categories`. W przypadku błędu wyświetla ostatnie logi,
ale **nie uruchamia** `rebuild-news.ps1`, `docker compose build` ani
`docker compose up`. Wymaga działających kontenerów i Dockera; nie jest
testem w pamięci podręcznej ani potwierdzeniem samej konfiguracji.


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

## Tłumaczenie tytułów — wspólny profil Alice LLM „Tłumacz”

Alice LLM udostępnia jedno ogólne przeznaczenie `TRANSLATOR` dla News i Anime.
Migracja Flyway `V101` w `alice-microservices-llm` zmienia istniejące
przypisania `MEDIA_TRANSLATOR` na `TRANSLATOR`. Nie kasuje profilu, modelu,
promptów ani jego ID. Dawne wywołania `MEDIA_TRANSLATOR` mają przejściowy
alias w LLM. Alice Media i Alice News docelowo korzystają z `TRANSLATOR`.

**Nie ustawiaj `NEWS_LLM_PROFILE_ID`** — zmienna nie jest już wykorzystywana.
Alice News automatycznie odczytuje istniejący profil przez
`GET /api/llm/profiles/purpose/TRANSLATOR` i generuje przez
`POST /api/llm/profiles/purpose/TRANSLATOR/generate`.
Jeżeli profil nie istnieje, wzbogacanie zwraca `LLM_NOT_CONFIGURED`
zamiast korzystać z przypadkowego modelu.

Wymagana kolejność wdrożenia na DEV (bez zmian bazy News i automatycznego RSS):

1. Pobierz aktualne repozytoria przez `./pull-all.ps1`.
2. **Najpierw zaktualizuj i uruchom `llm-service`**, aby wykonała się migracja
   `V101` i dostępne były endpointy według przeznaczenia:
   ```powershell
   docker compose --env-file .env up -d --build --no-deps --force-recreate --wait llm-service
   ```
3. Wyświetl aktualnie przypisany profil tłumacza:
   ```powershell
   .\enrich-news.ps1 -ShowTranslator
   ```
   Polecenie jest tylko do odczytu. Pokazuje nazwę, model i dostawcę —
   **bez proszenia o numer profilu**. Starszy przełącznik `-ListProfiles`
   nadal działa jako alias i pokazuje ten sam profil. Jeśli profil nie
   istnieje, przypisz mu przeznaczenie „Tłumacz” w konfiguracji Alice LLM.
4. Zostaw w `.env`:
   ```dotenv
   NEWS_ENRICHMENT_ENABLED=false
   NEWS_ENRICHMENT_BATCH_SIZE=2
   NEWS_LLM_BASE_URL=http://llm-service:8084
   ```
   Dla ręcznego testu nie trzeba włączać harmonogramu ani podawać ID.
5. Zbuduj i odtwórz **tylko News**:
   ```powershell
   docker compose --env-file .env up -d --build --no-deps --force-recreate --wait news-service
   ```
6. Świadomie uruchom pojedynczą partię:
   ```powershell
   .\enrich-news.ps1
   ```
   Skrypt sprawdza profil i gotowość News, wymaga `TAK`, następnie
   bezpiecznie pobiera `NEWS_ADMIN_TOKEN`. Nie zmienia harmonogramu.
7. Sprawdź `/news/`: przetłumaczone nagłówki są oznaczone jako AI,
   a oryginalny tytuł można rozwinąć. Polskie tytuły trafiają do
   `news_article.title_pl`; oryginały w `news_article.title` pozostają.

Przy współdzieleniu dawnego profilu anime z News upewnij się, że jego
**system prompt jest ogólnym poleceniem tłumaczenia**, a nie instrukcją
wyłącznie do opisów anime. Migracja celowo nie nadpisuje tego promptu
ani innych prywatnych ustawień profilu.

Po akceptacji jakości tłumaczeń można osobno zaplanować automatyczne
przetwarzanie (`NEWS_ENRICHMENT_ENABLED=true`). Nie włączamy go w tym kroku.

## Zarządzanie źródłami, stany artykułów i archiwum (DEV)

**Źródła RSS**: w Alice Web wejdź w **Aktualności → Źródła RSS**.
Subskrypcje pobierają się automatycznie; **nie ma pola na token**.
Wszystkie czynności są dostępne z interfejsu, o ile serwerowy token
`NEWS_ADMIN_TOKEN` został wcześniej skonfigurowany w prywatnym `.env`:
- **Pobierz subskrypcje** — sprawdzenie URL kanałów, kategorii, czasu i błędów
  ostatniego pobrania;
- **Nowa subskrypcja / Edytuj / Włącz / Wyłącz** — zapis do `news_source`;
- **Pobierz teraz** — pojedynczy import wskazanego kanału; poświadczenie jest dodawane przez Nginx, nie przez przeglądarkę;
- **Usuń subskrypcję** — miękka archiwizacja i wyłączenie źródła. Już pobrane
  artykuły **zostają**, a subskrypcję można reaktywować.

Źródła RSS wymagają publicznego HTTPS (port 443). Odrzucane są przekierowania
i niepubliczne adresy wykryte przez klienta pobierającego. Nowy kanał
nie uruchamia automatycznego importu, jeśli harmonogram globalnie jest
wyłączony.

**Automatyczny import**: na DEV `NEWS_RSS_ENABLED=false`, więc harmonogram
jest wyłączony. Aby go włączyć, po pierwszym udanym ręcznym imporcie ustaw
w prywatnym `.env`:

```dotenv
NEWS_RSS_ENABLED=true
NEWS_RSS_INTERVAL_MS=1800000
NEWS_RSS_INITIAL_DELAY_MS=60000
```

Odtwórz tylko News:

```powershell
docker compose --env-file .env up -d --no-deps --force-recreate --wait news-service
```

Włączenie harmonogramu oznacza próbę pobrania RSS po około 60 sekundach od
uruchomienia, a potem około 30 minut **od końca poprzedniego cyklu**.
Alice Web osobno **odświeża listę z bazy co 60 sekund**, gdy karta
przeglądarki jest aktywna. Przycisk **Odśwież** nie wywołuje importu RSS;
do jednorazowego pobrania służy **Pobierz teraz** na panelu źródeł.
W pasku informacyjnym widać rzeczywisty stan harmonogramu, liczbę
aktywnych źródeł i datę ostatniego pobrania.

**Stany i personalizacja**:
- **Bieżące** — artykuły z ostatnich 7 dni, również przeczytane. Przeczytane
  **nie znikają**, tylko zostają lekko przygaszone. Zmianę można cofnąć.
- **Nieprzeczytane** — tylko nieprzeczytane artykuły z bieżącego okresu.
- **Zapisane** — przechowywane niezależnie od wieku.
- **Nie interesuje mnie** — przenosi artykuł do widoku **Ukryte**,
  z możliwością przywrócenia.
- **Archiwum** — wiadomości starsze niż `NEWS_ACTIVE_DAYS=7`;
  bez usuwania z PostgreSQL.
- **Wszystkie** — wszystkie nieukryte wiadomości, również przeczytane
  i historyczne, do limitu 100 odpowiedzi API.
- **Dla mnie** — ranking kategorii wyliczany z jawnych sygnałów:
  przeczytane +1, zapisane +3, ukryte −3. To **deterministyczne
  dopasowanie**, nie wynik generowania LLM i nie model zainteresowań
  politycznych czy prywatnych cech użytkownika.

**Retencja**: starsze artykuły przechodzą do archiwum automatycznie już na
etapie filtrowania. Fizyczne czyszczenie nie jest uruchamiane domyślnie:

```dotenv
NEWS_ACTIVE_DAYS=7
NEWS_RETENTION_DAYS=90
NEWS_RETENTION_CLEANUP_ENABLED=false
```

Jeśli świadomie ustawisz `NEWS_RETENTION_CLEANUP_ENABLED=true`, zadanie
o 03:15 czasu polskiego usunie niezapisane artykuły dodane co najmniej
90 dni wcześniej. **Zapisane artykuły są zawsze wyłączone z usuwania**.
Nie uruchamiaj tego na DEV bez wcześniejszej kopii bazy i akceptacji retencji.

**Bezpieczeństwo bramy**: Alice Web dopuszcza zapisy jedynie do
`PATCH /api/news/articles/{UUID}/state`, zarządzania źródłami
`/api/news/admin/sources` i ręcznego importu wybranego źródła
`/api/news/admin/import/{UUID}`. Token administracyjny nadal
weryfikuje **News**, a Nginx wstrzykuje go tylko dla tych dwóch
administracyjnych ścieżek. Znacznik `X-Alice-News-Action: 1` jest
wymagany, aby ograniczyć ataki CSRF przez zwykłe formularze.
Brak skonfigurowanego sekretu oznacza brak dostępu do zarządzania.

**UWAGA: brak logowania oznacza, że każdy, kto może uzyskać dostęp do
Alice Web (w tym każdy z zaufanej sieci LAN), może też zarządzać RSS.**
Znacznik żądania NIE uwierzytelnia użytkownika. Nie udostępniaj tej
instancji do Internetu ani przez publiczny reverse proxy.
Jeśli dostęp ma być szerszy niż zaufana sieć LAN, dodaj logowanie lub
ograniczenie dostępu sieciowego przed bramą, a także zabezpiecz
zapisy stanu czytania.

Globalny import RSS i wzbogacanie LLM pozostają niedostępne przez bramę
Alice Web.

**Wdrożenie**: `./pull-all.ps1`, następnie
`docker compose --env-file .env up -d --build --no-deps --force-recreate --wait news-service alice-web`.
Migracja Flyway `V4` tworzy kolumny dla ukrytych artykułów i źródeł,
zachowując istniejące `is_read`, `is_saved` i pobrane rekordy.
Bez włączania czyszczenia dane nie zostaną usunięte.

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


## Alice News V2 — tryb regułowy i warunkowy LLM

Plan wdrożenia: `alice-news-service/docs/ALICE_NEWS_V2_PLAN.md`.
Migracje Flyway `V6` i `V7` zachowują artykuły i stany czytania.

**Harmonogram**: każdy kanał ma `refreshMinutes` 5–1440 (domyślnie 30 min).
Scheduler jedynie sprawdza terminy co `NEWS_RSS_POLL_MS=60000`; nie pobiera
kanału przed jego `next_fetch_at`. Dotychczasowe `NEWS_RSS_INTERVAL_MS`
pozostaje w starszych skryptach dla kompatybilności, ale nie steruje już
harmonogramem V2. Klient wysyła `If-None-Match` i `If-Modified-Since`;
HTTP 304 oznacza brak nowych treści. Dla HTTP 429 obsługiwany jest
liczbowy `Retry-After` (60–14400 s), a inne błędy mają stopniowy backoff.
Maksymalnie trzy przekierowania, wyłącznie HTTPS na ten sam host. Import
automatyczny w DEV pozostaje domyślnie wyłączony.

**Klasyfikacja**: metadane `category` z RSS/Atom i reguły tytułu/opisu
przypisują maks. 3 tematy oraz sugerowaną geografię. Przy niepewnym wyniku
status artykułu to `PENDING_LLM`, lecz artykuł pozostaje widoczny.
Opcjonalne wywołania LLM wymagają prywatnego `NEWS_CLASSIFICATION_ENABLED=true`;
domyślnie są wyłączone. W tym etapie fallback wykorzystuje profil celu
`TRANSLATOR` dostępny w Alice LLM, wywoływany tylko dla niejednoznacznych
wiadomości. Cel można przestawić przez `NEWS_CLASSIFICATION_LLM_PURPOSE`,
gdy zostanie skonfigurowany wyspecjalizowany profil. Nie ma automatycznego
ukrywania artykułów.

**Język**: artykuły z `language=en` pozostają w obecnej kolejce tłumaczeń,
sterowanej `NEWS_ENRICHMENT_ENABLED`; polskie i inne nieangielskie treści
są wyświetlane w oryginale wraz z opisem RSS. Tłumaczenie i klasyfikacja
są niezależnymi procesami.

**Stany**: `isArchived` jest ręcznym statusem niezależnym od przeczytania,
zapisania i ukrycia. Widok archiwum uwzględnia zarówno artykuły archiwalne
wiekowo, jak i ręcznie przeniesione.

Przed aktualizacją DEV pobierz nowe repozytoria, wykonaj kopię bazy News,
sprawdź `docker compose --env-file .env config --quiet`, następnie
przebuduj `news-service` i `alice-web`. Nie aktywuj automatycznie
`NEWS_RSS_ENABLED` ani `NEWS_CLASSIFICATION_ENABLED` przed testem ręcznym
nowego importera na DEV. GitLab CI nie potwierdza migracji na działającej bazie.
