# Alice Speech — uruchomienie i diagnostyka HTTP 503

Stan: 2026-11-23. Dotyczy formularza **Alice Web → Ustawienia → Mowa → Generowanie MP3**.

## Dlaczego pojawiało się „Speech Service jest niedostępny”?

Alice Web ma proxy Nginx `/api/speech/`, które zwraca HTTP 503 gdy:
- brak zmiennej `SPEECH_GATEWAY_TOKEN` (celowa blokada dostępu);
- kontener `speech-service` nie istnieje / nie działa / nie rozwiązuje się w Docker DNS;
- usługa backendu nie odpowiada albo zwraca 503.

Wcześniejszy `alice-infra` nie miał **w ogóle** wpisu `speech-service`
w Compose i nie przekazywał `SPEECH_GATEWAY_TOKEN` do `alice-web`.
Po tej zmianie DEV i PROD zawierają opcjonalny profil `speech`.

**Ważne:** profil jest domyślnie wyłączony, żeby nie zepsuć już
działających usług. Nie usuwać kontroli tokenu w Nginx!

## Wdrożenie produkcyjne tylko Alice Speech — bez restartu całej platformy

Do wdrażania TTS (Studio MP3, Alice NEWS, historia i retencja) używaj
dedykowanego skryptu
[`deploy-speech-production.sh`](../environments/production/deploy-speech-production.sh).
W przeciwieństwie do `deploy-production.sh` **nie aktualizuje on wszystkich
mikroserwisów**. Ogólny skrypt został dodatkowo naprawiony i objęty
kontrolą składni, ale nadal dotyczy całego środowiska.

Przed wdrożeniem: synchronizacja najnowszych commitów GitHub → GitLab,
walidacja CI, aktualizacja repo `alice-infra` na produkcji, wpisy
`COMPOSE_PROFILES=speech` i `SPEECH_API_TOKEN=<min. 32 znaki>` w
prywatnym `.env`, działający produkcyjny RabbitMQ. Ustawienia workerów
Windows DEV **nie** przenoszą się automatycznie do produkcyjnego brokera.
Udostępniaj AMQP tylko przez zaufaną sieć/VPN z restrykcjami zapory;
samo mapowanie portu 5672 nie zapewnia szyfrowania TLS.

```bash
cd /opt/alice/infra/environments/production
./deploy-speech-production.sh --check
./deploy-speech-production.sh --deploy
```

Ścieżka instalacji na serwerze może być inna. Tryb `--check` niczego nie
aktualizuje. Tryb `--deploy` pobiera tylko Speech i Web z GitLab,
**przed** ponownym uruchomieniem tworzy kopię istniejącego woluminu
`<COMPOSE_PROJECT_NAME>_speech_data` w
`/var/backups/alice/speech` i przerywa, jeśli backup się nie uda.
Wykorzystuje obraz `alpine:3.21` do kopii woluminu; na serwerze
musi działać Docker. Jeśli nazwa działającego projektu Compose nie
jest `production`, przekaż faktyczną wartość
`COMPOSE_PROJECT_NAME`, aby wskazać właściwe kontenery i wolumin.

Następnie skrypt buduje i odtwarza **tylko** `speech-service`
i `alice-web`, sprawdza ich stan i API historii. W razie problemów
nie wykonuje automatycznego rollbacku. Backupy produkcyjne
`backup-production.sh` obejmują teraz również katalog MP3
`docker/speech-data`, gdy kontener Speech jest uruchomiony.

**Pierwszy start usuwa stare nagrania zgodnie z retencją.** Jeśli
potrzebujesz zachować oryginały do odrębnej analizy, ustaw tymczasowo
`SPEECH_RETENTION_ENABLED=false`, wykonaj backup i dopiero po
zatwierdzeniu włącz limit 100 zadań / 14 dni / 512 MB.

P8 (monitoring w Alice Web) jest planem, nie częścią tego wdrożenia.

## Włączenie profilu produkcyjnego

Repozytoria ułożone tak jak dotychczas, w szczególności:
`alice_ai/microservices/speech` dla źródeł
[alice-speech-service](https://github.com/serafin1367/alice-speech-service).

1. W lokalnym, ignorowanym przez Git pliku
   `infra/environments/production/.env` ustaw:
   ```dotenv
   COMPOSE_PROFILES=speech
   ALICE_WEB_SPEECH_UPSTREAM=http://speech-service:8098
   SPEECH_API_TOKEN=
   SPEECH_PREFERRED_TTS_NODE=
   ```
   `COMPOSE_PROFILES` może być wielowartościowe, np. `speech,inny-profil`.
2. Skrypt `deploy-production.sh` wykryje aktywny profil, wygeneruje raz
   64-znakowy sekret `SPEECH_API_TOKEN` jeśli pole jest puste,
   pobierze repozytorium `microservices/speech` z GitHub,
   zbuduje obraz i uruchomi Compose. Repo jest prywatne: wymagany
   działający dostęp `git clone` z hosta albo wcześniejszy checkout.
   **Nie** nadpisuje niepustych katalogów i nie usuwa woluminów.
3. Z katalogu `infra/environments/production` uruchom:
   ```bash
   ./deploy-production.sh
   ```
4. Jeśli uruchamiasz Compose samodzielnie, **sam wygeneruj** token
   (nie pozostawiaj pustego) i upewnij się, że repo Speech jest sklonowane.
   Przykład na Linux w tym katalogu:
   ```bash
   token="$(od -An -N32 -tx1 /dev/urandom | tr -d '[:space:]')"
   # Dodaj token do lokalnego .env jako SPEECH_API_TOKEN=<token>,
   # nie pokazuj go w logach ani nie umieszczaj w Git.
   docker compose --profile speech --env-file .env config -q
   docker compose --profile speech --env-file .env up -d --build speech-service alice-web
   ```

`alice-web` otrzymuje `SPEECH_GATEWAY_TOKEN` z tej samej wartości
`SPEECH_API_TOKEN`, której używa backend. Po aktualizacji `.env`
**trzeba odtworzyć kontener `alice-web`**, samo odświeżenie karty nie wystarczy.
`SPEECH_UPSTREAM` pozostaje w prywatnej sieci Compose.
Port 8098 nie jest publikowany na hoście ani do Internetu.

## DEV

W `infra/environments/develop/.env` ustaw:

```dotenv
COMPOSE_PROFILES=speech
ALICE_WEB_SPEECH_UPSTREAM=http://speech-service:8098
SPEECH_API_TOKEN=<wygenerowany-losowy-sekret-min-32-znaki>
```

Zainstaluj kod usługi w `alice_ai/microservices/speech` (checkout z GitHub),
następnie w katalogu `environments/develop`:

```bash
docker compose --profile speech --env-file .env config -q
docker compose --profile speech --env-file .env up -d --build speech-service alice-web
```

## Diagnostyka — bez ujawniania sekretów

Z katalogu właściwego środowiska, gdzie znajduje się `docker-compose.yml`
i `.env`:

```bash
docker compose --profile speech --env-file .env ps rabbitmq speech-service alice-web
docker compose --profile speech --env-file .env logs --tail=60 speech-service
docker compose --profile speech --env-file .env exec -T alice-web sh -c 'if [ -n "$SPEECH_GATEWAY_TOKEN" ]; then echo SPEECH_TOKEN_SET; else echo SPEECH_TOKEN_MISSING; fi'
docker compose --profile speech --env-file .env exec -T alice-web wget -S -O - http://speech-service:8098/health
```

Interpretacja:
- `SPEECH_TOKEN_MISSING`: nieprzekazany sekret; odbuduj/odtwórz Alice Web.
- Brak kontenera `speech-service`: profil nieaktywny lub brak wdrożenia.
- `/health` zwraca 503: Speech Service działa, lecz nie połączył się z RabbitMQ.
- `/health` zwraca 200, a UI pokazuje brak workerów:
  backend jest dostępny, ale żaden FormsSpeechMicroservice na Windows
  nie zgłasza `READY`. Włącz adapter C# zgodnie z
  [README Speech Service](https://github.com/serafin1367/alice-speech-service).
- `/api/speech/tts/workers` z przeglądarki powinno zwrócić
  `{"workers":[]}` (HTTP 200) zanim dołączy pierwszy worker.

## Retencja MP3 i historii — ochrona woluminu speech_data

Od 2026-11-26 backend Alice Speech domyślnie automatycznie usuwa
starsze zakończone zadania i ich MP3. **Przed pierwszą przebudową
kontenera wykonaj kopię woluminu `speech_data`, jeśli chcesz zachować
dotychczasowe nagrania.** Czyszczenie przy pierwszym starcie jest
nieodwracalne; nie stosuj `down -v`.

W prywatnym `.env` (DEV albo PROD) można ustawić:

```dotenv
SPEECH_RETENTION_ENABLED=true
SPEECH_RETENTION_MAX_JOBS=100
SPEECH_RETENTION_MAX_DAYS=14
SPEECH_RETENTION_MAX_AUDIO_MB=512
SPEECH_RETENTION_CLEANUP_MINUTES=60
```

Polityka obowiązuje dla zakończonych `DONE` i `FAILED`;
nie dotyczy aktywnych `QUEUED` i `RUNNING`. Limity zadań,
wieku i sumarycznej wielkości MP3 działają jednocześnie.
Wartość `0` wyłącza pojedynczy limit; `ENABLED=false`
wyłącza czyszczenie. Czyszczenie odbywa się na starcie, po
zakończeniu zadania i cyklicznie. W Alice Web w panelu
**Ustawienia → Mowa → Historia** widać bieżące limity i
orientacyjną zajętość MP3.

W DEV po aktualizacji repozytoriów `alice-infra` i
`alice-speech-service` oraz ewentualnej edycji `.env`:

```powershell
docker compose --profile speech --env-file .env config -q
docker compose --profile speech --env-file .env up -d --build --no-deps --force-recreate speech-service
Invoke-RestMethod 'http://127.0.0.1:19080/api/speech/tts/history?limit=1' | ConvertTo-Json -Depth 5
```

Dla podglądu limitów w Alice Web trzeba również przebudować
`alice-web` po pobraniu jego najnowszego `main`.
Synchronizacja GitHub → GitLab sama nie wdraża obrazów Docker.

## Bezpieczeństwo, trwałość i CI

Trwałe pliki MP3 i statusy trzymane są w woluminie `speech_data:/data`,
a nie w ephemeral filesystem kontenera. Należy uwzględnić jego backup,
monitorowanie miejsca i retencję audio. Tokenu nie loguj i nie commituj.
W produkcji zalecana oddzielna tożsamość RabbitMQ z minimalnym ACL oraz
szyfrowanie AMQP, jeśli komunikacja opuszcza zaufaną sieć.

GitLab infra: `infra-compose-speech` waliduje oba profile przez
`docker compose config --quiet`, a `infra-news-dev-contract` przez
`python -m unittest discover` uruchamia także
`tests/test_speech_compose_contract.py`.
Konfigurację i kod sprawdzono statycznie; nie wykonano zdalnego
`docker compose up` ani testu z prawdziwym Windows workerem.
