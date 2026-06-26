#!/usr/bin/env bash
set -euo pipefail

PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/Projects}"

services=(
  "raphael-identity:8081:raphael_identity.app:app"
  "raphael-orgs:8082:raphael_orgs.app:app"
  "raphael-workspaces:8083:raphael_workspaces.app:app"
  "raphael-reviews:8087:raphael_reviews.app:app"
  "raphael-notifications:8090:raphael_notifications.app:app"
  "raphael-audit:8093:raphael_audit.app:app"
  "raphael-automation:8095:raphael_automation.app:app"
  "raphael-connectors:8096:raphael_connectors.app:app"
  "raphael-sync:8098:raphael_sync.app:app"
  "raphael-graph:8100:raphael_graph.app:app"
  "raphael-rwu:8101:raphael_rwu.app:app"
  "raphael-ops:8103:raphael_ops.app:app"
  "raphael-ai:8104:raphael_ai.app:app"
  "raphael-admin:8106:raphael_admin.app:app"
  "raphael-artifacts:8107:raphael_artifacts.app:app"
  "raphael-core:8080:raphael_core.app:app"
)

export RAPHAEL_IDENTITY_URL="${RAPHAEL_IDENTITY_URL:-http://127.0.0.1:8081}"
export RAPHAEL_ORGS_URL="${RAPHAEL_ORGS_URL:-http://127.0.0.1:8082}"
export RAPHAEL_WORKSPACES_URL="${RAPHAEL_WORKSPACES_URL:-http://127.0.0.1:8083}"
export RAPHAEL_REVIEWS_URL="${RAPHAEL_REVIEWS_URL:-http://127.0.0.1:8087}"
export RAPHAEL_NOTIFICATIONS_URL="${RAPHAEL_NOTIFICATIONS_URL:-http://127.0.0.1:8090}"
export RAPHAEL_AUDIT_URL="${RAPHAEL_AUDIT_URL:-http://127.0.0.1:8093}"
export RAPHAEL_AUTOMATION_URL="${RAPHAEL_AUTOMATION_URL:-http://127.0.0.1:8095}"
export RAPHAEL_CONNECTORS_URL="${RAPHAEL_CONNECTORS_URL:-http://127.0.0.1:8096}"
export RAPHAEL_SYNC_URL="${RAPHAEL_SYNC_URL:-http://127.0.0.1:8098}"
export RAPHAEL_GRAPH_URL="${RAPHAEL_GRAPH_URL:-http://127.0.0.1:8100}"
export RAPHAEL_RWU_URL="${RAPHAEL_RWU_URL:-http://127.0.0.1:8101}"
export RAPHAEL_OPS_URL="${RAPHAEL_OPS_URL:-http://127.0.0.1:8103}"
export RAPHAEL_AI_URL="${RAPHAEL_AI_URL:-http://127.0.0.1:8104}"
export RAPHAEL_ADMIN_URL="${RAPHAEL_ADMIN_URL:-http://127.0.0.1:8106}"
export RAPHAEL_ARTIFACTS_URL="${RAPHAEL_ARTIFACTS_URL:-http://127.0.0.1:8107}"
export RAPHAEL_JWT_SECRET="${RAPHAEL_JWT_SECRET:-dev-secret-with-32-byte-minimum-length!!}"

for spec in "${services[@]}"; do
  IFS=":" read -r name port app <<<"${spec}"
  (
    cd "${PROJECTS_ROOT}/${name}"
    uv run uvicorn "${app}" --host 127.0.0.1 --port "${port}"
  ) &
done

(
  cd "${PROJECTS_ROOT}/raphael-ui"
  npm run dev
) &

wait
