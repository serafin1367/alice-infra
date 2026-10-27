# Post Deploy Validation

Ta lista sluzy do szybkiej walidacji po kazdym wdrozeniu lub restarcie stacka.

## Kontenery

```bash
docker compose ps
```

Sprawdz:
- wszystkie kontenery sa uruchomione
- `postgres`, `rabbitmq` i `smarthome-service` maja status `healthy`

## Logi aplikacji

```bash
docker compose logs weather-service --tail=100
docker compose logs time-coordinator-service --tail=100
docker compose logs mail-service --tail=100
docker compose logs llm-service --tail=100
docker compose logs work-service --tail=100
docker compose logs smarthome-service --tail=100
```

Sprawdz:
- brak restart loop
- brak bledow polaczenia z baza
- brak bledow RabbitMQ

## Flyway

Sprawdz w logach wszystkich aplikacji:
- migracje wykonaly sie bez bledow
- nie ma rollbacku startu aplikacji

## API

Sprawdz recznie:
- `http://HOST:8081`
- `http://HOST:8082`
- `http://HOST:8083`
- `http://HOST:8084`
- `http://HOST:8085`

Sprawdz endpoint Health przez Alice Web: `http://HOST:8080/api/health/setup`.
Sprawdz Smart Home przez Alice Web: `http://HOST:8080/api/smarthome/status` oraz widok
`http://HOST:8080/smarthome/`. Port 8091 nie jest publikowany na hoście.

## RabbitMQ

Sprawdz:
- logowanie do panelu `15672`
- brak alarmow
- poprawny vhost

## Postgres

Sprawdz:
- bazy `weather`, `time_coordinator`, `mail`, `llm` i `work` istnieja
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
- ustawienia, geometria, urządzenia i wyposażenie Smart Home dalej są dostępne

Po wykonaniu `backup-production.sh` sprawdź sumę SHA-256 oraz obecność katalogu
`./docker/smarthome-data/` w archiwum. Smart Home zapisuje dane w plikach na wolumenie
`smarthome_data` i nie ma osobnej bazy PostgreSQL.
