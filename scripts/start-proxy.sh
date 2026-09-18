#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ensure-env.sh"

cd "${ROOT_DIR}"

GENERATED_DIR="${ROOT_DIR}/.generated"
GENERATED_CONFIG="${GENERATED_DIR}/litellm.config.yaml"
mkdir -p "${GENERATED_DIR}"

if [[ -n "${NODE_EXTRA_CA_CERTS:-}" ]]; then
  SSL_CERT_FILE="${GENERATED_DIR}/ca-bundle.pem"
  command cat "${SYSTEM_CA_FILE:-/etc/ssl/cert.pem}" "${NODE_EXTRA_CA_CERTS}" > "${SSL_CERT_FILE}"
  export SSL_CERT_FILE
  export UV_NATIVE_TLS=true
fi

sed_script=()
for model_key in "${CODEX_MODEL_KEYS[@]}"; do
  deployment_var="AZURE_DEPLOYMENT_${model_key}"
  alias_var="CODEX_MODEL_${model_key}_ALIAS"
  sed_script+=(-e "s#__${deployment_var}__#${!deployment_var}#g")
  sed_script+=(-e "s#__${alias_var}__#${!alias_var}#g")
done

sed "${sed_script[@]}" "${ROOT_DIR}/config/litellm.config.yaml" > "${GENERATED_CONFIG}"

printf 'Starting LiteLLM proxy on http://%s:%s\n' "${LITELLM_HOST}" "${LITELLM_PORT}"
for model_key in "${CODEX_MODEL_KEYS[@]}"; do
  deployment_var="AZURE_DEPLOYMENT_${model_key}"
  alias_var="CODEX_MODEL_${model_key}_ALIAS"
  printf 'Exposing %s -> azure/%s\n' "${!alias_var}" "${!deployment_var}"
done
printf 'Azure API version: %s\n' "${AZURE_API_VERSION}"

exec uvx \
  --from 'litellm[proxy]!=1.82.7,!=1.82.8' \
  litellm \
  --config "${GENERATED_CONFIG}" \
  --host "${LITELLM_HOST}" \
  --port "${LITELLM_PORT}"
