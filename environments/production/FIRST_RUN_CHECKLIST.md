# First Run Checklist

Ta lista sluzy do pierwszego uruchomienia stacka produkcyjnego:
- `postgres`
- `rabbitmq`
- `weather-service`
- `time-coordinator-service`

## 1. Przygotowanie hosta

- zainstalowany Docker i Docker Compose
- wolne porty:
  - `5432` lub alternatywny `POSTGRES_PORT`
  - `5672`
  - `15672`
  - `8081`
  - `8082`
  - `8888`
- katalog roboczy zawiera aktualne pliki z `infra/environments/production`

## 2. Przygotowanie plikow

- skopiowano `.env.example` do `.env`
- ustawiono mocne hasla w `.env`
- dopasowano porty hosta w `.env`, jesli domyslne sa zajete
- dodano plik:
  - `secrets/google-calendar/credentials.json`
- potwierdzono istnienie katalogu:
  - `secrets/google-calendar/tokens`

## 3. Uprawnienia skryptu init Postgresa

Na hoście Linux:

```bash
chmod +x postgres/init/01-init-databases.sh
chmod +x postgres/init/02-init-mail-database.sh
```

## 4. Start stacka

```bash
docker compose --env-file .env up -d --build
```

## 5. Weryfikacja kontenerow

```bash
docker compose ps
```

Oczekiwany stan:
- `postgres` - `healthy`
- `rabbitmq` - `healthy`
- `weather-service` - `running`
- `time-coordinator-service` - `running`

## 6. Weryfikacja logow

```bash
docker compose logs postgres --tail=100
docker compose logs rabbitmq --tail=100
docker compose logs weather-service --tail=100
docker compose logs time-coordinator-service --tail=100
```

Sprawdz:
- brak bledow startowych Spring Boot
- brak bledow polaczenia z baza
- brak bledow RabbitMQ
- brak bledow Flyway

## 7. Weryfikacja baz danych

Sprawdz, czy istnieja:
- baza `weather`
- baza `time_coordinator`
- baza `mail`
- uzytkownik `weather`
- uzytkownik `time_coordinator`
- uzytkownik `mail`

Przyklad:

```bash
docker exec -it alice-postgres psql -U postgres -d postgres
```

W `psql`:

```sql
\l
\du
```

## 8. Weryfikacja RabbitMQ

Sprawdz panel:
- `http://HOST:15672`

Zweryfikuj:
- mozna sie zalogowac
- istnieje vhost zgodny z `.env`

## 9. Weryfikacja API

Sprawdz:
- `http://HOST:8081`
- `http://HOST:8082`

Jesli sa endpointy health, sprawdz je w pierwszej kolejnosci.

## 10. Weryfikacja Google Calendar

- konto domyslne jest widoczne w API / desktopie
- mozna pobrac liste kont
- mozna wykonac synchronizacje
- katalog `secrets/google-calendar/tokens` zapisuje tokeny po autoryzacji
- port `8888` jest dostepny dla callbacku OAuth

## 11. Po starcie

- wykonaj pierwszy backup wolumenu Postgresa albo dump obu baz
- zapisz finalne uzyte porty i hasla w menedzerze sekretow
- ogranicz dostep do `15672` firewallem
- jesli `5672` nie jest potrzebny z zewnatrz, zamknij go na firewallu

## 12. Typowe problemy

- `postgres init script did not run`
  - wolumen `postgres_data` juz istnial
- `mail database missing on existing postgres volume`
  - wykonaj recznie `postgres/init/02-init-mail-database.sh`
- `database does not exist`
  - bledne zmienne w `.env`
- `port already allocated`
  - konflikt portow hosta
- `Google OAuth callback bind failed on 8888`
  - port zajety przez inny proces
- `Flyway migration failed`
  - niespojny stan bazy lub brak uprawnien uzytkownika
