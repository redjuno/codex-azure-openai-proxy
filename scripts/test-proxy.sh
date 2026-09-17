#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ensure-env.sh"

BASE_URL="http://${LITELLM_HOST}:${LITELLM_PORT}"

printf 'Testing OpenAI Responses endpoint: %s/v1/responses\n' "${BASE_URL}"

for model_alias in "${CODEX_MODEL_OPUS_ALIAS}" "${CODEX_MODEL_FABLE_ALIAS}"; do
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
