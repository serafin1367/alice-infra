# Diagnostyka Alice Web — MVP (2026-11-27)

Nowy widok: `/diagnostics/`. Backend jest opcjonalną usługą `diagnostics-service` (profil `diagnostics`) w środowiskach develop i production. Uruchom z katalogu środowiska: `docker compose --profile diagnostics up -d --build diagnostics-service alice-web`. Profil można połączyć z `speech` przez `COMPOSE_PROFILES=diagnostics,speech`.

Endpoint `GET /api/diagnostics/status` zwraca status HTTP wybranych usług, połączenie TCP z PostgreSQL i stan RabbitMQ przez Management API. Interfejs odpytuje go co 30 sekund bez przeładowania. Nie pokazuje tokenów ani haseł.

**Ograniczenia:** status PostgreSQL oznacza wyłącznie otwarte połączenie TCP, nie test zapytania SQL. Metryki pamięci są widoczne z przestrzeni kontenera, nie są pełnym pomiarem hosta Proxmox. Dostęp do Docker API jest domyślnie wyłączony, ponieważ podmontowanie `docker.sock`, nawet tylko do odczytu, może dać uprawnienia administracyjne do hosta. Lista kontenerów będzie niedostępna, dopóki nie powstanie bezpieczny pośrednik z ograniczonymi uprawnieniami. Niektóre usługi nie mają potwierdzonego endpointu `/health` i mogą być oznaczone jako niedostępne mimo działania; należy zweryfikować kontrakty. Profil nie jest automatycznie uruchamiany na produkcji.

**Bezpieczeństwo:** endpoint zawiera dane operacyjne; przed udostępnieniem Alice Web poza zaufaną sieć należy dodać autoryzację do `/api/diagnostics/status`. Nie uruchamiaj go publicznie bez kontroli dostępu.

Zmiany zapisane w repozytoriach, ale nie potwierdzono uruchomienia, testów CI ani wdrożenia na serwerze.
