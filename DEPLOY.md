# Raphael self-hosted deployment

Deploy Raphael on your own infrastructure with Docker. Passive collaboration (reviews, activity, connectors idle) is **unlimited and free** on a local install. Connect a **Raphael Cloud API key** to unlock billing UI, managed compute, and RWU (Raphael Work Unit) metering for automation runs and AI jobs.

## Requirements

| Resource | Minimum |
|----------|---------|
| CPU | 4 cores |
| RAM | 8 GB (16 GB recommended if enabling local AI via Ollama) |
| Disk | 20 GB free |
| Software | Docker 24+ with Compose v2 |

## Quick start

```bash
cd raphael-infra/release
chmod +x install.sh
./install.sh
```

Open http://localhost:5173 and complete **Sign up** to create the first organization. No seeded demo data is included.

### Images not on GHCR yet?

Release images publish when a `v*` tag is pushed (see `.github/workflows/release.yml`). Until then, build from your polyrepo checkout:

```bash
./install.sh --local
# or set RAPHAEL_BUILD_LOCAL=1 in release/.env
```

This uses `raphael-infra/docker-compose.yml` and builds from sibling repos under `~/Projects/`.

## Environment variables

Copy `release/.env.selfhost.example` to `release/.env`.

| Variable | Required | Description |
|----------|----------|-------------|
| `POSTGRES_PASSWORD` | Yes | Database password |
| `RAPHAEL_JWT_SECRET` | Yes | ≥32 bytes; signs session tokens |
| `RAPHAEL_DATABASE_URL` | Yes | Postgres connection (set by compose) |
| `RAPHAEL_PUBLIC_API_BASE` | Yes | Public URL users open in the browser |
| `RAPHAEL_CLOUD_API_KEY` | No | Enables cloud billing + RWU sync in UI |
| `RAPHAEL_STRIPE_*` | No | Stripe checkout when cloud-connected |
| `RAPHAEL_NOTIFICATIONS_POSTMARK_TOKEN` | No | Password reset email; without it, docs note email is unconfigured |
| `RAPHAEL_RWU_DAILY_LIMIT` | No | Daily RWU allocation when cloud-connected (default 500) |
| `RAPHAEL_KAFKA_DISABLED` | No | Set `0` in release (event bus enabled) |

## Raphael Cloud connection

1. Obtain an API key from Raphael Cloud.
2. Set `RAPHAEL_CLOUD_API_KEY` in `.env` **or** enter the key in **Settings → Raphael Cloud** in the UI.
3. Restart `raphael-core` or the full stack.
4. **Billing & usage** (`/settings/billing`) shows plan, RWU ledger, and invoices.

Self-hosted installs without a cloud key show honest copy: local execution is not charged RWU.

## First admin

**Recommended:** UI signup at `/signup`.

**CLI alternative:**

```bash
./scripts/bootstrap.sh admin@example.com 'your-secure-password'
```

## Operations

```bash
# Logs
docker compose -f release/docker-compose.release.yml logs -f raphael-core

# Stop
docker compose -f release/docker-compose.release.yml down

# Upgrade
export RAPHAEL_VERSION=0.2.0
./release/install.sh
```

## Development vs release

| Mode | Compose file | Notes |
|------|--------------|-------|
| **Polyrepo dev** | `raphael-infra/docker-compose.yml` | Builds from source; use `scripts/dev-local.sh` for stub AI |
| **Release** | `raphael-infra/release/docker-compose.release.yml` | Pinned images; Postgres required; no SQLite fallback |

## Troubleshooting

- **UI cannot reach API** — confirm `raphael-core` is healthy on port 8080 and nginx proxies `/v1` to core.
- **Password reset fails** — configure Postmark or use an admin reset via identity service.
- **RWU tab empty** — connect Raphael Cloud; local installs log execution without charging RWU.
- **Kafka errors** — ensure `redpanda` is healthy; release sets `RAPHAEL_KAFKA_DISABLED=0`.

## Security checklist

- Change default passwords before exposing to the internet.
- Terminate TLS at a reverse proxy (Caddy, nginx, Traefik).
- Restrict Postgres and Kafka ports to internal networks only.
- Rotate `RAPHAEL_JWT_SECRET` only with a planned session invalidation.
