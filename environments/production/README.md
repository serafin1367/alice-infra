# Production Stack

Ten katalog zawiera docelowy runtime produkcyjny bez reverse proxy:
- jeden `postgres`
- jeden `rabbitmq`
- `weather-service`
- `time-coordinator-service`
- `mail-service`

## Struktura

- `docker-compose.yml` - wspolny stack produkcyjny
- `.env.example` - lista wymaganych zmiennych
- `postgres/init/01-init-databases.sh` - inicjalizacja baz `weather` i `time_coordinator`
- `postgres/init/02-init-mail-database.sh` - inicjalizacja bazy `mail`
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
- `RABBITMQ_PASSWORD`
3. Dopasuj porty hosta, jesli domyslne sa zajete.
4. Umiesc plik Google OAuth credentials w:
- `secrets/google-calendar/credentials.json`
5. Upewnij sie, ze katalog:
- `secrets/google-calendar/tokens`
  istnieje i jest zapisywalny dla kontenera.
6. Upewnij sie, ze katalog:
- `MAIL_ATTACHMENTS_HOST_DIR`
  istnieje na hoscie albo moze zostac utworzony przez Docker i ma byc objety backupem.

## Pierwsze uruchomienie

```powershell
docker compose --env-file .env up -d --build
```

## Aktualizacja

```powershell
docker compose --env-file .env up -d --build
```

## Operacyjne uwagi

- `postgres/init/01-init-databases.sh` wykonuje sie tylko przy pierwszym uruchomieniu pustego wolumenu `postgres_data`.
- Zalaczniki `mail-service` sa trwale zapisywane na hoscie przez `MAIL_ATTACHMENTS_HOST_DIR`.
- Zmiana hasel po inicjalizacji bazy wymaga recznej operacji SQL albo odtworzenia wolumenu.
- Port `15672` od RabbitMQ management nie powinien byc wystawiony publicznie bez firewalla.
- Web OAuth Google korzysta z callbacku HTTP aplikacji:
  - `GOOGLE_CALENDAR_OAUTH_REDIRECT_URI`
- Brak reverse proxy oznacza brak TLS termination na poziomie stacka. Jesli uslugi maja byc publiczne, trzeba to rozwiazac na poziomie hosta lub sieci.

## Minimalna weryfikacja po starcie

1. `docker compose ps`
2. sprawdzenie logow obu mikroserwisow
3. sprawdzenie migracji Flyway
4. `http://HOST:8081`
5. `http://HOST:8082`
6. `http://HOST:15672` tylko z ograniczonym dostepem
