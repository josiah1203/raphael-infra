# Raphael Platform Infrastructure

Local development stack: API gateway, domain services, event bus, object store, Postgres.

## Quick start

```bash
# Build context is ~/Projects (parent of each service repo)
cd ~/Projects/raphael-infra
docker compose up -d
```

Docker builds copy `raphael-contracts` from the sibling repo automatically via `docker/Dockerfile.service`.

```bash
# Install shared contracts first (native dev)
cd ../raphael-contracts && uv sync
```

## Services

| Service | Port | URL |
|---------|------|-----|
| raphael-core (gateway) | 8080 | http://localhost:8080 |
| raphael-identity | 8081 | internal |
| raphael-workspaces | 8083 | internal |
| raphael-reviews | 8087 | internal |
| raphael-notifications | 8090 | internal |
| Redpanda (Kafka API) | 19092 | localhost:19092 |
| MinIO | 9000 | http://localhost:9000 |
| Postgres | 5432 | localhost:5432 |

## Environment

Copy `services.env.example` to `services.env` and set `RAPHAEL_NOTIFICATIONS_POSTMARK_TOKEN` for email delivery.
