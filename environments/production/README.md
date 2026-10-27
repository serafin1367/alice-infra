# Production Stack

Ten katalog zawiera docelowy runtime produkcyjny z aplikacją Alice Web i jej bramą API:
- jeden `postgres`
- jeden `rabbitmq`
- `weather-service`
- `time-coordinator-service`
- `mail-service`
- `llm-service`
- `work-service`
- `shopping-service`
- `knowledge-service`
- `health-service`
- `budget-service`
- `smarthome-service`

## Struktura

- `docker-compose.yml` - wspolny stack produkcyjny
- `.env.example` - lista wymaganych zmiennych
- `postgres/init/01-init-databases.sh` - inicjalizacja baz `weather` i `time_coordinator`
- `postgres/init/02-init-mail-database.sh` - inicjalizacja bazy `mail`
- `postgres/init/03-init-llm-database.sh` - inicjalizacja bazy `llm`
- `postgres/init/04-init-work-database.sh` - inicjalizacja bazy `work`
- `postgres/init/05-init-shopping-database.sh` - inicjalizacja bazy `shopping`
- `secrets/google-calendar/` - lokalne mounty dla credentials i tokenow Google
- `data/mail-attachments/` - lokalny katalog hosta na zapis zalacznikow mail
- `FIRST_RUN_CHECKLIST.md` - checklista pierwszego uruchomienia
- `POST_DEPLOY_VALIDATION.md` - checklista walidacji po wdrozeniu

## Przygotowanie

1. Skopiuj `.env.example` do `.env`.
2. Ustaw mocne hasla:
- `POSTGRES_SUPERUSER_PASSWORD`
- `WEATHER_DB_PASSWORD`
- `TIME_COORDINATOR_DB_PASSWORD`
- `MAIL_DB_PASSWORD`
- `LLM_DB_PASSWORD`
- `WORK_DB_PASSWORD`
- `SHOPPING_DB_PASSWORD`
- `KNOWLEDGE_DB_PASSWORD`
- `HEALTH_DB_PASSWORD`
- `BUDGET_DB_PASSWORD`
- `RABBITMQ_PASSWORD`

`HEALTH_INTERNAL_TOKEN` musi byc dlugim losowym sekretem wspoldzielonym przez Health i LLM.
Skrypt `deploy-production.sh` automatycznie generuje i zapisuje brakujaca wartosc w
produkcyjnym `.env`, dzieki czemu aktualizacja starszej instalacji nie zatrzymuje sie na walidacji Compose.
Ustaw także `HOME_ASSISTANT_URL` oraz długoterminowy `HOME_ASSISTANT_TOKEN`. Plik `.env`
ma zawierać sekret i nie może trafić do repozytorium. Smart Home nie publikuje portu na
hoście; Alice Web i LLM łączą się z nim przez prywatną sieć Compose.
3. Dopasuj porty hosta, jesli domyslne sa zajete.
4. Umiesc plik Google OAuth credentials w:
- `secrets/google-calendar/credentials.json`
5. Upewnij sie, ze katalog:
- `secrets/google-calendar/tokens`
  istnieje i jest zapisywalny dla kontenera.
6. Upewnij sie, ze katalog:
- `MAIL_ATTACHMENTS_HOST_DIR`
  istnieje na hoscie albo moze zostac utworzony przez Docker i ma byc objety backupem.
7. Ustaw `WORK_JIRA_URL`, `WORK_JIRA_USERNAME` i `WORK_JIRA_PASSWORD` oraz upewnij sie, ze katalog `WORK_ATTACHMENTS_HOST_DIR` jest objety backupem.

## Pierwsze uruchomienie

```powershell
docker compose --env-file .env up -d --build
```

## Aktualizacja

```powershell
docker compose --env-file .env up -d --build
```

Pelne wdrozenie z pobraniem aktualnego kodu wszystkich projektow wykonuje skrypt
`deploy-production.sh`. Zaklada on uklad katalogow, w ktorym `alice-web`, `desktop`, `infra`
i `microservices/*` sa katalogami jednego workspace. Skrypt wymaga czystych
plikow sledzonych przez Git; ignoruje typowe niezatwierdzone artefakty runtime,
takie jak `.env`, dane i sekrety. Nie usuwa wolumenow z danymi:

Repozytorium `desktop` jest aktualizowane tylko wtedy, gdy istnieje na serwerze;
nie jest wymagane do wdrozenia mikroserwisow.

```bash
cd infra/environments/production
chmod +x deploy-production.sh
./deploy-production.sh
```

Domyslnie pobierana jest galaz `main`; mozna wskazac inna przez
`DEPLOY_BRANCH=nazwa-galezi ./deploy-production.sh`.

## Operacyjne uwagi

- `postgres/init/01-init-databases.sh` wykonuje sie tylko przy pierwszym uruchomieniu pustego wolumenu `postgres_data`.
- Zalaczniki `mail-service` sa trwale zapisywane na hoscie przez `MAIL_ATTACHMENTS_HOST_DIR`.
- Zalaczniki `work-service` sa trwale zapisywane na hoscie przez `WORK_ATTACHMENTS_HOST_DIR`.
- Zmiana hasel po inicjalizacji bazy wymaga recznej operacji SQL albo odtworzenia wolumenu.
- Port `15672` od RabbitMQ management nie powinien byc wystawiony publicznie bez firewalla.
- Web OAuth Google korzysta z callbacku HTTP aplikacji:
  - `GOOGLE_CALENDAR_OAUTH_REDIRECT_URI`
- Brak reverse proxy oznacza brak TLS termination na poziomie stacka. Jesli uslugi maja byc publiczne, trzeba to rozwiazac na poziomie hosta lub sieci.
- Widoki Knowledge i Shopping są wyłącznie w Alice Web. Porty 8086 i 8087 udostępniają backendowe API.

## Automatyczny backup całego środowiska

Skrypt `backup-production.sh` wykonuje pełną kopię danych i konfiguracji produkcyjnej:

- osobny dump każdej bazy PostgreSQL oraz role i uprawnienia,
- dane Dashboardu,
- pliki konfiguracji Smart Home z wolumenu `smarthome_data`,
- pliki Knowledge oraz załączniki Mail i Work,
- credentials i tokeny Google Calendar,
- definicje RabbitMQ i, domyślnie, jego pełny katalog danych,
- kod źródłowy, plik Compose i produkcyjny `.env`.

Archiwum zawiera dane wrażliwe, dlatego jest tworzone z uprawnieniami wynikającymi
z `umask 077`. Katalog backupów musi znajdować się poza katalogiem projektu, powinien
znajdować się na szyfrowanym nośniku i być
kopiowany poza serwer produkcyjny. Domyślny katalog to `/var/backups/alice`, a retencja
wynosi 30 dni. Pełna kopia RabbitMQ powoduje krótką przerwę w pracy brokera; usługi
pozostają uruchomione i ponownie nawiązują połączenie po jego automatycznym starcie.

Pierwsze uruchomienie ręczne:

```bash
cd /opt/alice/infra/environments/production
sudo /usr/bin/bash ./backup-production.sh
```

Opcjonalne ustawienia można dodać do `.env`:

```dotenv
ALICE_BACKUP_DIR=/var/backups/alice
ALICE_BACKUP_RETENTION_DAYS=30
ALICE_BACKUP_RABBITMQ_DATA=true
ALICE_BACKUP_EMAIL=admin@example.com
```

Jeżeli `ALICE_BACKUP_EMAIL` jest ustawione, po poprawnym utworzeniu i sprawdzeniu
archiwum skrypt wysyła wiadomość z nazwą pliku, rozmiarem i sumą SHA-256. Korzysta
z systemowego polecenia `mail`, więc host musi mieć skonfigurowany lokalny transport
poczty oraz pakiet `mailutils` albo `s-nail`. Błąd wysłania wiadomości jest zapisywany
jako ostrzeżenie i nie usuwa prawidłowego backupu.

Przykładowy wpis crona znajduje się w `backup-cron.example`. Po dopasowaniu ścieżki
instalacja może wyglądać tak:

```bash
sudo install -m 600 backup-cron.example /etc/cron.d/alice-backup
```

Jeżeli serwer ma już działającą pocztę systemową z Cron Daemon, wystarczy ustawić
`MAILTO=adres@example.com` w pliku crona. Cron wyśle wtedy cały log skryptu, również
końcowy komunikat o sukcesie. W takim wariancie pozostaw `ALICE_BACKUP_EMAIL` puste,
aby nie otrzymywać dwóch wiadomości po każdym backupie. Przekierowanie wyłącznie do
pliku (`>> ... 2>&1`) przechwytuje jednak wyjście przed cronem; aby jednocześnie zapisać
log i wysłać go przez Cron Daemon, użyj `tee`:

```cron
MAILTO=admin@example.com
30 2 * * * root /usr/bin/flock -n /var/lock/alice-backup-cron.lock /usr/bin/bash /opt/alice/infra/environments/production/backup-production.sh 2>&1 | /usr/bin/tee -a /var/log/alice-backup.log
```

Pole `root` jest wymagane w plikach instalowanych w `/etc/cron.d/`. Nie dodaje się
go tylko wtedy, gdy ten sam wpis jest instalowany poleceniem `crontab -e`.

Po pierwszym automatycznym wykonaniu sprawdź `/var/log/alice-backup.log`, sumę SHA-256
oraz testowo odtwórz dump w oddzielnym środowisku. Backup bez regularnego testu
odtwarzania nie powinien być traktowany jako zweryfikowany.

## Minimalna weryfikacja po starcie

1. `docker compose ps`
2. sprawdzenie logow obu mikroserwisow
3. sprawdzenie migracji Flyway
4. `http://HOST:8081`
5. `http://HOST:8082`
6. `http://HOST:8083`
7. `http://HOST:8084`
8. `http://HOST:8085`
6. `http://HOST:15672` tylko z ograniczonym dostepem

## Wdrożenie Alice Web i Knowledge

Repozytoria wymagane na serwerze: infra, alice-web oraz microservices/llm, mail, shopping, knowledge, time_coordinator, weather, work, dashboard, health, budget i smarthome. Desktop jest opcjonalny. Skrypt wdrożeniowy automatycznie klonuje brakujące repozytoria i uruchamia migracje usług bazodanowych.

1. Pobierz aktualne repozytorium infra. Skrypt automatycznie sklonuje brakujące wymagane repozytoria, w tym Alice Web, Knowledge i Smart Home. Adres Smart Home: `http://gitlab.mbb.net.pl/alice/microservices/smarthome.git`.
2. Uzupełnij produkcyjne `.env`: `KNOWLEDGE_DB_NAME`, `KNOWLEDGE_DB_USERNAME`, `KNOWLEDGE_DB_PASSWORD`, `KNOWLEDGE_STORAGE_HOST_DIR`, `HEALTH_DB_NAME`, `HEALTH_DB_USERNAME`, `HEALTH_DB_PASSWORD`, `HOME_ASSISTANT_URL`, `HOME_ASSISTANT_TOKEN`, `ALICE_WEB_PUBLIC_PORT` (domyślnie 8080), `ALICE_WEB_BIND_IP` (domyślnie 127.0.0.1). Hasła muszą odpowiadać istniejącym rolom bazy; skrypty nie resetują istniejących haseł.
3. Wykonaj backup bazy PostgreSQL i katalogów danych przed aktualizacją. Skrypt nie kopiuje danych developerskich na produkcję. Istniejące dane produkcyjne pozostają w swoich wolumenach/katalogach.
4. Pobierz aktualizację infra, następnie uruchom `bash deploy-production.sh`. Skrypt wymaga wskazanej gałęzi, wykonuje tylko merge fast-forward, buduje wszystkie obrazy przed zmianą działających usług, uruchamia infrastrukturę i tworzy brakujące bazy Shopping, Knowledge i Health także na istniejącym wolumenie. Na koniec odtwarza zmienione kontenery bez `down` i bez kasowania wolumenów.
5. Zweryfikuj `docker compose ps` i logi migracji. Alice Web jest lokalnie dostępne na serwerze pod `http://127.0.0.1:8080/` (w tym `/knowledge/` i `/shopping/`).
6. W produkcyjnym LLM skonfiguruj profil z przeznaczeniem `KNOWLEDGE`. Profil developerski nie jest automatycznie przenoszony. Powinien obsługiwać JSON z `message` i `actions` dla propozycji zmian; dane dostawcy/modelu pozostają w produkcyjnej konfiguracji LLM.

Smart Home nie używa PostgreSQL. Ustawienia, geometria, urządzenia i wyposażenie są
zapisywane w `/data` na nazwanym wolumenie `smarthome_data`; wdrożenie nie usuwa tego
wolumenu, a `backup-production.sh` kopiuje go do `docker/smarthome-data` i sprawdza
obecność tej kopii w końcowym archiwum.

Domyślny binding Alice Web pozostaje lokalny. Dostęp z internetu wymaga HTTPS i uwierzytelniania obejmującego stronę, API i WebSocket. Nie publikuj bezpośrednio niechronionych API; istniejące porty developerskie/administracyjne backendów należy ograniczyć zaporą lub bindingiem hosta. Aktualizacja nie otwiera routera i nie konfiguruje domeny.
## Automatyczne klonowanie

Skrypt deploy-production.sh klonuje brakujące wymagane repozytoria na gałęzi DEPLOY_BRANCH (domyślnie main). Istniejące repozytoria zachowują origin i są aktualizowane fast-forward. Niepusty katalog bez Git blokuje wdrożenie, aby nie nadpisać danych. Pusty katalog jest dopuszczalny. Desktop pozostaje opcjonalny i nie jest klonowany automatycznie. Git na serwerze musi mieć dostęp do wskazanych repozytoriów GitLab.

## Pliki Knowledge na produkcji

Katalog hosta `/mnt/md0/docker/docker-volume/alice_ai/knowledge/` jest montowany do `/app/storage/projects` w kontenerze Knowledge. Zawiera katalogi projektów i ich pliki; baza PostgreSQL pozostaje w swoim dotychczasowym wolumenie.

W istniejącym produkcyjnym `.env` ustaw:

```dotenv
KNOWLEDGE_STORAGE_HOST_DIR=/mnt/md0/docker/docker-volume/alice_ai/knowledge
```

Wartość z `.env` nadpisuje domyślną ścieżkę Compose. Przed zmianą montowania przenieś dotychczasowe pliki Knowledge do nowego katalogu (jeżeli są już zapisane); sama zmiana konfiguracji ich nie przenosi. Katalog powinien być objęty backupem i zapisywalny przez kontener. Odtwórz usługę przez skrypt wdrożeniowy lub `docker compose --env-file .env up -d knowledge-service`.
