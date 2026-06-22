#!/usr/bin/env bash
#
# Set up an ER workbench checkout for Claude skills and VS Code Rmd editing on
# macOS or Linux. Mirrors setup-er-repo.ps1 (Windows): it locates a Python
# interpreter and delegates to setup_er_repo.py. All flags are forwarded straight
# through, so every option the Python script accepts (--root, --claude-target,
# --vscode-r-platform, --no-configure-vscode, --no-check-runtimes,
# --no-branch-check, --install-missing-r-packages, --dry-run) works unchanged.
#
# Defaults (--claude-target global, --vscode-r-platform current) come from the
# Python script itself; this wrapper adds none of its own.
#
# Usage:
#   bash clinical-biostat-er/skills/er-setup/scripts/setup-er-repo.sh --root .
#   ./setup-er-repo.sh --root . --dry-run

set -euo pipefail

# Resolve this script's directory portably (works under bash and zsh).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SETUP_PY="${SCRIPT_DIR}/setup_er_repo.py"

resolve_python() {
  local candidate
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

if ! PYTHON="$(resolve_python)"; then
  echo "[ERROR] Python was not found on PATH." >&2
  case "$(uname -s)" in
    Darwin)
      echo "Install Python 3, e.g. with Homebrew:" >&2
      echo "  brew install python@3.12" >&2
      ;;
    Linux)
      echo "Install Python 3, e.g. on Debian/Ubuntu:" >&2
      echo "  sudo apt-get install python3 python3-pip" >&2
      ;;
    *)
      echo "Install Python 3 from https://www.python.org/downloads/" >&2
      ;;
  esac
  echo "Then re-run this setup command from the repo root." >&2
  exit 1
fi

if [ ! -f "$SETUP_PY" ]; then
  echo "[ERROR] Cannot find setup_er_repo.py next to this wrapper at: $SETUP_PY" >&2
  exit 1
fi

exec "$PYTHON" "$SETUP_PY" "$@"
