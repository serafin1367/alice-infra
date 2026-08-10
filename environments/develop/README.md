# Develop Stack

Ten katalog zawiera lokalny stack developerski dla:
- `postgres`
- `rabbitmq`
- `weather-service`
- `time-coordinator-service`
- `mail-service`
- `work-service`
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
- Weather API: `18081`
- Time Coordinator API: `18082`
- Mail API: `18083`
- Work API: `18085`
- MailHog SMTP: `11025`
- MailHog UI: `18025`

## OAuth w develop

Domyslny callback Google OAuth:

```text
http://localhost:18082/api/google/calendar/oauth/callback
```

Ten adres musi byc dodany do dozwolonych redirect URI w projekcie Google OAuth dla develop.
