#!/usr/bin/env bash
# PreToolUse(Bash): never stage or commit local-only workflow files into a team repo.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
CMD=$(jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0
is_git_subcommand '(add|commit|rm|mv)' "$CMD" || exit 0
in_workflow_repo && exit 0
PATTERNS="${LOCAL_ONLY_PATTERNS:-CLAUDE.local.md settings.local.json overlay.env}"
for p in $PATTERNS; do
  if grep -qE "(^|[[:space:]/\"'])${p//./\\.}([[:space:]\"';&|)]|\$)" <<<"$CMD"; then
    block "'$p' is local-only and must never enter a team repository." \
      "It is excluded via .git/info/exclude; do not add it explicitly."
  fi
done
exit 0
