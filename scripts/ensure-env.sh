#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${CODEX_AZURE_ENV_FILE:-${ROOT_DIR}/.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
  printf 'Missing %s\n' "${ENV_FILE}" >&2
  printf 'Create it first:\n  cp %s/.env.example %s\n' "${ROOT_DIR}" "${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

# Every model this proxy exposes. Each key needs AZURE_DEPLOYMENT_<KEY> in .env
# and maps to the Codex-visible alias CODEX_MODEL_<KEY>_ALIAS.
CODEX_MODEL_KEYS=(SOL ASTRA LUNA)

required_vars=(
  AZURE_API_KEY
  AZURE_API_BASE
  AZURE_API_VERSION
  LITELLM_MASTER_KEY
)
for model_key in "${CODEX_MODEL_KEYS[@]}"; do
  required_vars+=("AZURE_DEPLOYMENT_${model_key}")
done

missing=()
for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" || "${!var_name}" == your-* || "${!var_name}" == *your-* ]]; then
    missing+=("${var_name}")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'Fill these values in %s:\n' "${ENV_FILE}" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

if [[ "${AZURE_API_VERSION}" < "2025-03-01-preview" ]]; then
  printf 'AZURE_API_VERSION must be 2025-03-01-preview or later for Azure OpenAI Responses API.\n' >&2
  printf 'Current value: %s\n' "${AZURE_API_VERSION}" >&2
  exit 1
fi

export ROOT_DIR
export LITELLM_HOST="${LITELLM_HOST:-127.0.0.1}"
export LITELLM_PORT="${LITELLM_PORT:-4020}"
export CODEX_MODEL_SOL_ALIAS="${CODEX_MODEL_SOL_ALIAS:-gpt-5.6-sol}"
export CODEX_MODEL_ASTRA_ALIAS="${CODEX_MODEL_ASTRA_ALIAS:-gpt-6-astra}"
export CODEX_MODEL_LUNA_ALIAS="${CODEX_MODEL_LUNA_ALIAS:-gpt-5.6-luna}"

# Model used when codex-azure runs without -m.
export CODEX_DEFAULT_MODEL="${CODEX_MODEL_SOL_ALIAS}"
