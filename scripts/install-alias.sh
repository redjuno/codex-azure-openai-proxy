#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="${ROOT_DIR}/scripts/codex-via-azure-openai.sh"
SHELL_RC="${CODEX_AZURE_SHELL_RC:-${HOME}/.zshrc}"
ALIAS_NAME="${CODEX_AZURE_ALIAS_NAME:-codex-azure}"
MARKER_BEGIN="# >>> codex-azure-openai-proxy >>>"
MARKER_END="# <<< codex-azure-openai-proxy <<<"
BIN_DIR="${CODEX_AZURE_BIN_DIR:-${HOME}/.local/bin}"
SHIM="${BIN_DIR}/${ALIAS_NAME}"

if [[ ! -f "${LAUNCHER}" ]]; then
  printf 'Launcher not found: %s\n' "${LAUNCHER}" >&2
  exit 1
fi

mkdir -p "$(dirname "${SHELL_RC}")"
touch "${SHELL_RC}"

tmp_file="$(mktemp)"
awk -v begin="${MARKER_BEGIN}" -v end="${MARKER_END}" '
  $0 == begin { skip = 1; next }
  $0 == end { skip = 0; next }
  skip != 1 { print }
' "${SHELL_RC}" > "${tmp_file}"

{
  cat "${tmp_file}"
  printf '\n%s\n' "${MARKER_BEGIN}"
  printf "alias %s=%q\n" "${ALIAS_NAME}" "${LAUNCHER}"
  printf '%s\n' "${MARKER_END}"
} > "${SHELL_RC}"

rm -f "${tmp_file}"

mkdir -p "${BIN_DIR}"
{
  printf '#!/usr/bin/env bash\n'
  printf 'exec %q "$@"\n' "${LAUNCHER}"
} > "${SHIM}"
chmod +x "${SHIM}"

printf 'Installed alias:\n'
printf '  %s -> %s\n' "${ALIAS_NAME}" "${LAUNCHER}"
printf '\nInstalled command shim:\n'
printf '  %s\n' "${SHIM}"
printf '\nApply it in the current terminal:\n'
printf '  source %s\n' "${SHELL_RC}"
printf '\nThen run from any project directory:\n'
printf '  %s\n' "${ALIAS_NAME}"
