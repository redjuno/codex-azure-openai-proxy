#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ensure-env.sh"

BASE_URL="http://${LITELLM_HOST}:${LITELLM_PORT}"

printf 'Testing OpenAI Responses endpoint: %s/v1/responses\n' "${BASE_URL}"

for model_key in "${CODEX_MODEL_KEYS[@]}"; do
  alias_var="CODEX_MODEL_${model_key}_ALIAS"
  model_alias="${!alias_var}"
  printf '\n-- %s\n' "${model_alias}"
  curl -sS "${BASE_URL}/v1/responses" \
    -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
    -H "content-type: application/json" \
    -d '{
      "model": "'"${model_alias}"'",
      "input": "Reply with one short sentence confirming the proxy works."
    }'
  printf '\n'
done
