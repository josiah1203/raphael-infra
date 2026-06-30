#!/usr/bin/env bash
# Raphael self-hosted installer — pull release images, configure env, start stack.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.release.yml"
ENV_EXAMPLE="${SCRIPT_DIR}/.env.selfhost.example"
ENV_FILE="${SCRIPT_DIR}/.env"
DEPLOY_DOC="${SCRIPT_DIR}/../DEPLOY.md"

echo "Raphael self-hosted installer"
echo "============================="

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ ! -f "${ENV_EXAMPLE}" ]]; then
    echo "Missing ${ENV_EXAMPLE}"
    echo "Run install.sh from the release/ directory (raphael-infra/release)."
    exit 1
  fi
  echo "Creating ${ENV_FILE} from .env.selfhost.example"
  cp "${ENV_EXAMPLE}" "${ENV_FILE}"
  if command -v openssl >/dev/null 2>&1; then
    JWT="$(openssl rand -base64 32)"
    PG="$(openssl rand -hex 16)"
    sed -i.bak "s/change-me-use-at-least-32-random-bytes!!/${JWT}/" "${ENV_FILE}"
    sed -i.bak "s/change-me-in-production/${PG}/" "${ENV_FILE}"
    rm -f "${ENV_FILE}.bak"
    echo "Generated JWT secret and Postgres password."
  else
    echo "WARNING: Edit ${ENV_FILE} — set RAPHAEL_JWT_SECRET and POSTGRES_PASSWORD before production use."
  fi
fi

# shellcheck disable=SC1090
set -a && source "${ENV_FILE}" && set +a

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install Docker Desktop or Docker Engine first."
  exit 1
fi

COMPOSE=(docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}")

echo "Pulling images (version ${RAPHAEL_VERSION:-0.1.0})…"
"${COMPOSE[@]}" pull

echo "Starting infrastructure (Postgres, Kafka, MinIO)…"
"${COMPOSE[@]}" up -d postgres redpanda minio minio-init migrate

echo "Starting Raphael services…"
"${COMPOSE[@]}" up -d

echo ""
echo "Waiting for API gateway…"
for _ in $(seq 1 60); do
  if curl -sf "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

UI_URL="${RAPHAEL_PUBLIC_API_BASE:-http://localhost:5173}"
echo ""
echo "Raphael is starting."
echo "  UI:      ${UI_URL}"
echo "  API:     http://localhost:8080"
echo ""
echo "First admin: open ${UI_URL}/signup and create your organization."
echo "Optional: set RAPHAEL_CLOUD_API_KEY in ${ENV_FILE} and restart to enable billing + RWU sync."
echo ""
echo "See ${DEPLOY_DOC} for operations, backups, and troubleshooting."
