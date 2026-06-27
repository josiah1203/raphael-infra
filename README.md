# Raphael Platform Infrastructure

Local development stack: API gateway, 22 domain services, event bus, object store, Postgres.

## Quick start

```bash
# Build context is ~/Projects (parent of each service repo)
cd ~/Projects/raphael-infra
docker compose up -d
```

Docker builds copy `raphael-contracts`, `raphael-audit`, and `raphael-artifacts` path deps via `docker/Dockerfile.service`.

```bash
# Native dev — all 22 services + gateway (+ UI)
./scripts/dev-local.sh

# Install shared contracts first
cd ../raphael-contracts && uv sync
```

## Staging (Terraform)

See [`terraform/README.md`](terraform/README.md) for RDS Postgres, S3, Secrets Manager, and ECS Fargate skeleton.

## Services

| Service | Port | URL |
|---------|------|-----|
| raphael-core (gateway) | 8080 | http://localhost:8080 |
| raphael-identity | 8081 | internal |
| raphael-orgs | 8082 | internal |
| raphael-workspaces | 8083 | internal |
| raphael-reviews | 8087 | internal |
| raphael-comments | 8088 | internal |
| raphael-messaging | 8089 | internal |
| raphael-notifications | 8090 | internal |
| raphael-links | 8091 | internal |
| raphael-audit | 8093 | internal |
| raphael-automation | 8095 | internal |
| raphael-connectors | 8096 | internal |
| raphael-registry | 8097 | internal |
| raphael-sync | 8098 | internal |
| raphael-graph | 8100 | internal |
| raphael-rwu | 8101 | internal |
| raphael-environments | 8102 | internal |
| raphael-ops | 8103 | internal |
| raphael-ai | 8104 | internal |
| raphael-analytics | 8105 | internal |
| raphael-admin | 8106 | internal |
| raphael-artifacts | 8107 | internal |
| Redpanda (Kafka API) | 19092 | localhost:19092 |
| MinIO | 9000 | http://localhost:9000 |
| Postgres | 5432 | localhost:5432 |
| Ollama | 11434 | http://localhost:11434 |

Gateway healthchecks wait for identity, orgs, workspaces, audit, raphael-ai, and raphael-automation before accepting traffic.

## Ollama / Gemma (intelligence)

On first `docker compose up`, `ollama-init` pulls `gemma2:2b` into the persistent `ollamadata` volume. Expect **2–5 minutes** on a fresh volume before `raphael-ai` reports a live model tier.

| Variable | Default | Purpose |
|----------|---------|---------|
| `RAPHAEL_GEMMA_MODEL` | `gemma2:2b` | Model tag verified by Ollama healthcheck |
| `RAPHAEL_MODEL_BACKEND` | `ollama` | Set `stub` for CI without GPU |
| `RAPHAEL_MODEL_STARTUP_WAIT_SEC` | `300` | How long raphael-ai blocks startup waiting for the model |

`raphael-ai` starts only after `ollama-init` completes successfully and Ollama is healthy with the configured Gemma model present.

## Environment

Copy `services.env.example` to `services.env` and set `RAPHAEL_NOTIFICATIONS_POSTMARK_TOKEN` for email delivery.

Observability defaults: `RAPHAEL_LOG_FORMAT=json`, Prometheus at `/metrics`.

