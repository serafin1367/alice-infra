# Post Deploy Validation

Ta lista sluzy do szybkiej walidacji po kazdym wdrozeniu lub restarcie stacka.

## Kontenery

```bash
docker compose ps
```

Sprawdz:
- wszystkie kontenery sa uruchomione
- `postgres` i `rabbitmq` maja status `healthy`

## Logi aplikacji

```bash
docker compose logs weather-service --tail=100
docker compose logs time-coordinator-service --tail=100
```

Sprawdz:
- brak restart loop
- brak bledow polaczenia z baza
- brak bledow RabbitMQ

## Flyway

Sprawdz w logach obu aplikacji:
- migracje wykonaly sie bez bledow
- nie ma rollbacku startu aplikacji

## API

Sprawdz recznie:
- `http://HOST:8081`
- `http://HOST:8082`

Jesli wprowadzicie endpointy health, dopiszcie je tutaj jako glowny check.

## RabbitMQ

Sprawdz:
- logowanie do panelu `15672`
- brak alarmow
- poprawny vhost

## Postgres

Sprawdz:
- obie bazy istnieja
- aplikacje zapisują i czytają dane

## Google Calendar

Sprawdz:
- lista kont zwraca dane
- synchronizacja dziala
- nowe wydarzenie pojawia sie w widoku po synchronizacji
- usuwanie wydarzenia dziala

## Dane trwale

Po restarcie:

```bash
docker compose restart
```

Sprawdz:
- konta Google dalej istnieja
- cache wydarzen dalej istnieje
- tokeny OAuth dalej sa dostepne
