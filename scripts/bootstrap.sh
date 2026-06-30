#!/usr/bin/env bash
# Bootstrap first org admin via API (optional — UI signup is preferred).
set -euo pipefail

API_BASE="${RAPHAEL_API_BASE:-http://127.0.0.1:8080}"
EMAIL="${1:-admin@localhost}"
PASSWORD="${2:-}"

if [[ -z "${PASSWORD}" ]]; then
  echo "Usage: $0 <email> <password>"
  exit 1
fi

curl -sf -X POST "${API_BASE}/v1/identity/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}" | python3 -m json.tool

echo ""
echo "Admin registered. Sign in at ${RAPHAEL_PUBLIC_API_BASE:-http://localhost:5173}/login"
