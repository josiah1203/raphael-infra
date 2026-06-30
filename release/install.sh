#!/usr/bin/env bash
# Raphael self-hosted installer — pull release images or build from local sibling repos.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MONOREPO_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"
COMPOSE_RELEASE="${SCRIPT_DIR}/docker-compose.release.yml"
COMPOSE_DEV="${INFRA_DIR}/docker-compose.yml"
ENV_EXAMPLE="${SCRIPT_DIR}/.env.selfhost.example"
ENV_FILE="${SCRIPT_DIR}/.env"
DEPLOY_DOC="${INFRA_DIR}/DEPLOY.md"

LOCAL_BUILD=false
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_BUILD=true ;;
    -h|--help)
      echo "Usage: $0 [--local]"
      echo "  --local   Build images from sibling repos (~/Projects/raphael-*) instead of pulling from GHCR."
      exit 0
      ;;
  esac
done

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
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s/change-me-use-at-least-32-random-bytes!!/${JWT}/" "${ENV_FILE}"
      sed -i '' "s/change-me-in-production/${PG}/" "${ENV_FILE}"
    else
      sed -i "s/change-me-use-at-least-32-random-bytes!!/${JWT}/" "${ENV_FILE}"
      sed -i "s/change-me-in-production/${PG}/" "${ENV_FILE}"
    fi
    echo "Generated JWT secret and Postgres password."
  else
    echo "WARNING: Edit ${ENV_FILE} — set RAPHAEL_JWT_SECRET and POSTGRES_PASSWORD before production use."
  fi
fi

# shellcheck disable=SC1090
set -a && source "${ENV_FILE}" && set +a

if [[ "${RAPHAEL_BUILD_LOCAL:-0}" == "1" ]]; then
  LOCAL_BUILD=true
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install Docker Desktop or Docker Engine first."
  exit 1
fi

has_local_sources() {
  [[ -f "${COMPOSE_DEV}" ]] && [[ -d "${MONOREPO_ROOT}/raphael-core" ]] && [[ -d "${MONOREPO_ROOT}/raphael-ui" ]]
}

run_local_build() {
  if ! has_local_sources; then
    echo "Local build requires sibling repos under ${MONOREPO_ROOT}:"
    echo "  raphael-core, raphael-ui, raphael-identity, … (polyrepo checkout)"
    exit 1
  fi
  echo ""
  echo "Building from local source (raphael-infra/docker-compose.yml)…"
  echo "This may take several minutes on first run."
  cd "${INFRA_DIR}"
  docker compose up -d --build
}

run_release_pull() {
  local compose=(docker compose -f "${COMPOSE_RELEASE}" --env-file "${ENV_FILE}")
  echo "Pulling images (${RAPHAEL_REGISTRY:-ghcr.io/hblabs}/raphael-*:${RAPHAEL_VERSION:-0.1.0})…"
  set +e
  "${compose[@]}" pull
  local status=$?
  set -e
  return $status
}

run_release_up() {
  local compose=(docker compose -f "${COMPOSE_RELEASE}" --env-file "${ENV_FILE}")
  echo "Starting infrastructure (Postgres, Kafka, MinIO)…"
  "${compose[@]}" up -d postgres redpanda minio minio-init migrate
  echo "Starting Raphael services…"
  "${compose[@]}" up -d
}

if [[ "${LOCAL_BUILD}" == "true" ]]; then
  run_local_build
else
  if ! run_release_pull; then
    echo ""
    echo "Registry pull failed (images may not be published yet)."
    if has_local_sources; then
      echo "Falling back to local build from sibling repos…"
      run_local_build
    else
      echo ""
      echo "Options:"
      echo "  1. Re-run with --local if you have the polyrepo checkout:"
      echo "       ./install.sh --local"
      echo "  2. Set RAPHAEL_REGISTRY to a registry that hosts the release images."
      echo "  3. Use dev compose directly: cd ${INFRA_DIR} && docker compose up -d --build"
      exit 18
    fi
  else
    run_release_up
  fi
fi

echo ""
echo "Waiting for API gateway…"
for _ in $(seq 1 90); do
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
