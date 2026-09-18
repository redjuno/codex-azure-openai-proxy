#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ensure-env.sh"
source "${SCRIPT_DIR}/proxy-runtime.sh"

export OPENAI_BASE_URL="http://${LITELLM_HOST}:${LITELLM_PORT}/v1"
export OPENAI_API_KEY="${LITELLM_MASTER_KEY}"

session_id="session-$$"
codex_pid=""
session_acquired=0
cleanup_started=0

cleanup() {
  local exit_code="${1:-$?}"
  (( cleanup_started == 1 )) && return
  cleanup_started=1
  trap - EXIT INT TERM HUP
  if [[ -n "${codex_pid}" ]] && process_is_alive "${codex_pid}"; then
    kill -TERM "${codex_pid}" 2>/dev/null || true
    wait "${codex_pid}" 2>/dev/null || true
  fi
  if (( session_acquired == 1 )); then
    proxy_session_release "${session_id}" || true
  fi
  exit "${exit_code}"
}

forward_signal() {
  local signal="$1"
  [[ -n "${codex_pid}" ]] && process_is_alive "${codex_pid}" && kill -"${signal}" "${codex_pid}" 2>/dev/null || true
}

trap 'cleanup $?' EXIT
trap 'forward_signal INT' INT
trap 'forward_signal TERM' TERM
trap 'forward_signal HUP' HUP

proxy_session_acquire "${session_id}" || exit 1
session_acquired=1

printf 'Launching Codex via LiteLLM: %s, model=%s\n' "${OPENAI_BASE_URL}" "${CODEX_DEFAULT_MODEL}"

set +e
codex \
  -c 'model_provider="codex-azure"' \
  -c "model=\"${CODEX_DEFAULT_MODEL}\"" \
  -c 'model_providers.codex-azure.name="Local Azure OpenAI"' \
  -c "model_providers.codex-azure.base_url=\"${OPENAI_BASE_URL}\"" \
  -c 'model_providers.codex-azure.env_key="OPENAI_API_KEY"' \
  -c 'model_providers.codex-azure.wire_api="responses"' \
  "$@" <&0 &
codex_pid=$!
wait "${codex_pid}"
codex_exit_code=$?
set -e
codex_pid=""
cleanup "${codex_exit_code}"
