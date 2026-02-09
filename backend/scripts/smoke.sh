#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${BASE_URL:-}" || -z "${APP_CODE:-}" ]]; then
  echo "Usage: BASE_URL=https://api.example.com APP_CODE=xxxx ./scripts/smoke.sh"
  exit 1
fi

echo "Health"
curl -fsS "${BASE_URL}/health" | jq .

echo "Today"
curl -fsS -H "X-APP-CODE: ${APP_CODE}" "${BASE_URL}/v1/today" | jq .

echo "Month"
curl -fsS -H "X-APP-CODE: ${APP_CODE}" "${BASE_URL}/v1/month" | jq '.mtd_actual, .mtd_target, .updated_at'

echo "Events"
curl -fsS -H "X-APP-CODE: ${APP_CODE}" "${BASE_URL}/v1/events" | jq '.events | length'

