#!/usr/bin/env bash
# PreToolUse(Bash): uv over pip in Python projects; pnpm over npm where a pnpm lockfile exists.
set -euo pipefail
CMD=$(jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
boundary='(^|[;&|(])[[:space:]]*'

if [[ -f "$PROJECT_DIR/pnpm-lock.yaml" ]] && grep -qE "${boundary}npm[[:space:]]" <<<"$CMD"; then
  echo "BLOCKED: this project uses pnpm (pnpm-lock.yaml present). Use pnpm." >&2
  exit 2
fi
pip_call="${boundary}(pip[0-9]*|python[0-9.]*[[:space:]]+-m[[:space:]]+pip)[[:space:]]"
for marker in pyproject.toml setup.py requirements.txt Pipfile; do
  if [[ -f "$PROJECT_DIR/$marker" ]] && grep -qE "$pip_call" <<<"$CMD"; then
    echo "BLOCKED: this Python project uses uv, not pip." \
      "Use 'uv add <pkg>' or 'uv pip install <pkg>'." >&2
    exit 2
  fi
done
exit 0
