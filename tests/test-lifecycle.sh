#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
BIN_DIR="${TEST_DIR}/bin"
ENV_FILE="${TEST_DIR}/test.env"
RUNTIME_DIR="${TEST_DIR}/runtime"
STARTS_FILE="${TEST_DIR}/starts"
RUNS_FILE="${TEST_DIR}/runs"
PORT="$((20000 + RANDOM % 20000))"
trap '[[ -f "${RUNTIME_DIR}/proxy.pid" ]] && kill -- "-$(<"${RUNTIME_DIR}/proxy.pid")" 2>/dev/null || true; rm -rf "${TEST_DIR}"' EXIT
mkdir -p "${BIN_DIR}"
cat >"${ENV_FILE}" <<EOF
AZURE_API_KEY=test-key
AZURE_API_BASE=https://example.test
AZURE_API_VERSION=2025-03-01-preview
AZURE_DEPLOYMENT_OPUS=test-opus
AZURE_DEPLOYMENT_FABLE=test-fable
LITELLM_MASTER_KEY=test-key
LITELLM_HOST=127.0.0.1
LITELLM_PORT=${PORT}
CODEX_MODEL_OPUS_ALIAS=opus
CODEX_MODEL_FABLE_ALIAS=fable
EOF
cat >"${BIN_DIR}/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s|%s|%s\n' "$PWD" "${OPENAI_BASE_URL}" "${OPENAI_API_KEY}" "$*" >>"${MOCK_CODEX_RUNS}"
sleep "${MOCK_CODEX_SLEEP:-0}"
exit "${MOCK_CODEX_EXIT:-0}"
EOF
chmod +x "${BIN_DIR}/codex"
export PATH="${BIN_DIR}:${PATH}"
export CODEX_AZURE_ENV_FILE="${ENV_FILE}"
export CODEX_AZURE_RUNTIME_DIR="${RUNTIME_DIR}"
export CODEX_AZURE_PROXY_COMMAND="${ROOT_DIR}/tests/mock-proxy.py"
export CODEX_AZURE_PROXY_START_TIMEOUT=5 CODEX_AZURE_PROXY_STOP_TIMEOUT=2
export MOCK_PROXY_STARTS="${STARTS_FILE}" MOCK_CODEX_RUNS="${RUNS_FILE}"
fail() { echo "FAIL: $*" >&2; exit 1; }
wait_file() { local n=100; while [[ ! -s "$1" && n -gt 0 ]]; do n=$((n-1)); sleep .05; done; [[ -s "$1" ]]; }
wait_leases() { local n=100 c; while ((n--)); do c=$(find "${RUNTIME_DIR}/sessions" -type f 2>/dev/null | wc -l); ((c == $1)) && return; sleep .05; done; return 1; }
run_bounded() { local limit="$1"; shift; "$@" >/dev/null 2>&1 & local pid=$!; local n=$((limit * 10)); while ((n--)); do kill -0 "${pid}" 2>/dev/null || { wait "${pid}"; return; }; sleep .1; done; kill -KILL "${pid}" 2>/dev/null; return 124; }

echo 'Test: automatic start, environment, cwd, exit, stop'
mkdir -p "${TEST_DIR}/project"
set +e
(cd "${TEST_DIR}/project" && MOCK_CODEX_EXIT=7 "${ROOT_DIR}/scripts/codex-via-azure-openai.sh" --version)
status=$?
set -e
[[ $status == 7 ]] || fail "exit code $status"
grep -F "${TEST_DIR}/project|http://127.0.0.1:${PORT}/v1|test-key|" "${RUNS_FILE}" >/dev/null || fail 'Codex environment not preserved'
[[ ! -f "${RUNTIME_DIR}/proxy.pid" ]] || fail 'proxy remained'

echo 'Test: concurrent sessions share one proxy'
: >"${STARTS_FILE}"
MOCK_CODEX_SLEEP=2 "${ROOT_DIR}/scripts/codex-via-azure-openai.sh" one >/dev/null 2>&1 & p1=$!
wait_file "${STARTS_FILE}" || fail 'proxy did not start'
MOCK_CODEX_SLEEP=10 "${ROOT_DIR}/scripts/codex-via-azure-openai.sh" two >/dev/null 2>&1 & p2=$!
wait_leases 2 || fail 'two leases not created'
(( $(wc -l <"${STARTS_FILE}") == 1 )) || fail 'multiple proxies started'
wait $p1
[[ -f "${RUNTIME_DIR}/proxy.pid" ]] || fail 'proxy stopped early'
wait $p2
[[ ! -f "${RUNTIME_DIR}/proxy.pid" ]] || fail 'proxy remained'

echo 'Test: LITELLM_PORT falls back to the documented default'
grep -v '^LITELLM_PORT=' "${ENV_FILE}" >"${TEST_DIR}/no-port.env"
port="$(CODEX_AZURE_ENV_FILE="${TEST_DIR}/no-port.env" \
  bash -c 'source "$1/scripts/ensure-env.sh"; printf "%s" "${LITELLM_PORT}"' _ "${ROOT_DIR}")"
[[ "${port}" == 4020 ]] || fail "port fallback is ${port}, expected 4020"

echo 'Test: an inherited ROOT_DIR does not redirect the runtime directory'
runtime="$(ROOT_DIR=/nonexistent-root bash -c \
  'unset CODEX_AZURE_RUNTIME_DIR; source "$1/scripts/proxy-runtime.sh"; printf "%s" "${RUNTIME_DIR}"' _ "${ROOT_DIR}")"
[[ "${runtime}" == "${ROOT_DIR}/.codex-runtime" ]] || fail "runtime directory is ${runtime}"

echo 'Test: direct status and stop terminate'
run_bounded 10 env ROOT_DIR=/nonexistent-root "${ROOT_DIR}/scripts/proxy-runtime.sh" status \
  || fail 'proxy-runtime.sh status did not finish'
run_bounded 10 env ROOT_DIR=/nonexistent-root "${ROOT_DIR}/scripts/proxy-runtime.sh" stop \
  || fail 'proxy-runtime.sh stop did not finish'

echo 'All lifecycle tests passed.'
