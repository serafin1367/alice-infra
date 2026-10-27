# Develop Stack

Ten katalog zawiera lokalny stack developerski dla:
- `postgres`
- `rabbitmq`
- `weather-service`
- `time-coordinator-service`
- `mail-service`
- `work-service`
- `shopping-service`
- `mailhog`

Srodowisko `develop` jest odseparowane od `production`:
- ma inne domyslne porty hosta,
- ma osobny wolumen danych,
- ma lokalny callback OAuth Google na `localhost`.

## Struktura

- `docker-compose.yml` - wspolny stack developerski
- `.env.example` - przykladowe zmienne srodowiskowe
- `postgres/init/01-init-databases.sh` - inicjalizacja baz i uzytkownikow
- `secrets/google-calendar/` - mount dla credentials i tokenow Google

## Przygotowanie

1. Skopiuj `.env.example` do `.env`.
2. Umiesc plik Google OAuth credentials w:
   - `secrets/google-calendar/credentials.json`
3. Upewnij sie, ze istnieje katalog:
   - `secrets/google-calendar/tokens`
4. Jesli domyslne porty developerskie sa zajete, zmien je w `.env`.

## Uruchomienie

```powershell
docker compose --env-file .env up -d --build
```

## Zatrzymanie

```powershell
docker compose --env-file .env down
```

## Wazne porty domyslne

- Postgres: `55432`
- RabbitMQ AMQP: `55672`
- RabbitMQ panel: `15673`
- Weather API: `19081`
- Time Coordinator API: `19082`
- Mail API: `19083`
- Work API: `19085`
- Shopping API: `19086`
- Shopping (API i PWA): `19086`
- MailHog SMTP: `11125`
- MailHog UI: `19025`

## OAuth w develop

Domyslny callback Google OAuth:

```text
http://localhost:19082/api/google/calendar/oauth/callback
```

Ten adres musi byc dodany do dozwolonych redirect URI w projekcie Google OAuth dla develop.

## Alice Web

Serwis `alice-web` udostępnia stronę startową oraz moduły Knowledge i Shopping pod http://localhost:19080/. Uruchomienie: `docker compose up -d --build --no-deps alice-web`. Wymaga działających backendów dla funkcji modułów, lecz samą stronę startową można uruchomić niezależnie. Domyślne powiązanie portu to `127.0.0.1`; ustawienia dostępu LAN i plan publikacji internetowej opisuje `../../../alice-web/README.md`.

## Alice Media – integracja developerska

Kod repozytorium `alice-microservices-media` powinien znajdowac sie w katalogu `microservices/media` obok innych mikroserwisow Alice. Sciezka budowania relatywna do `environments/develop/docker-compose.yml`: `../../../microservices/media`.

Konfiguracja współdzieli istniejące usługi `postgres` i `rabbitmq`; **nie uruchamiaj osobnego `docker-compose.yml` z repozytorium Media**, jeśli korzystasz z tego stacku. Ustaw `MEDIA_DB_PASSWORD` w prywatnym `.env` i zachowaj spójność z hasłem użytkownika PostgreSQL.

**Ważne przy istniejącym wolumenie PostgreSQL:** skrypty w `postgres/init` działają wyłącznie przy pierwszej inicjalizacji pustego katalogu danych. Dodanie `08-init-media-database.sh` NIE tworzy bazy w już uruchomionym PostgreSQL. Nie usuwaj wolumenu danych, aby wymusić inicjalizację! Zamiast tego, wykonaj poniższy skrypt w istniejącym kontenerze, po skonfigurowaniu `.env`:

```powershell
# W katalogu alice-infra/environments/develop
# Uruchomienie jawne: skrypt tworzy rolę i bazę, jeśli nie istnieją.
docker compose --env-file .env exec -T postgres bash /docker-entrypoint-initdb.d/08-init-media-database.sh
```

Następnie:

```powershell
docker compose --env-file .env config --quiet
docker compose --env-file .env up -d --build media-service alice-web
docker compose --env-file .env ps media-service alice-web
curl.exe http://127.0.0.1:19096/api/media/health
```

Frontend: `http://localhost:19080/media/`. API z Alice Web: `http://localhost:19080/api/media/health`. Lokalny port Media Service: `127.0.0.1:19096`.

**Uwaga bezpieczeństwa**: bieżące Media API nie ma kompletnej autoryzacji; środowisko nie nadaje się do publicznego wystawienia. Ruch RabbitMQ używany do transmisji danych plików wymaga osobnych testów wydajnościowych.

## Skrypty przebudowy

Z katalogu `environments/develop` (PowerShell):

```powershell
./rebuild-media.ps1  # przebudowuje alice-web i media-service, bez uruchamiania zaleznosci
./rebuild-all.ps1    # przebudowuje wszystkie obrazy ze zbiorczej listy, w tym media-service
```

`rebuild-media.ps1` uzywa `--no-deps`, wiec PostgreSQL i RabbitMQ musza juz dzialac, a baza `media` musi istniec. Skrypt nie usuwa wolumenow ani baz danych. Logi sa wyswietlane po odtworzeniu kontenerow; `Ctrl+C` konczy sledzenie logow.
