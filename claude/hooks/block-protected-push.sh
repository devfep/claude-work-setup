#!/usr/bin/env bash
# PreToolUse(Bash): refuse `git push` to a protected branch, explicit or implied.
# The workflow repo is exempt: it is a personal repo whose main branch carries programme state.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
CMD=$(jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0
is_git_subcommand push "$CMD" || exit 0
in_workflow_repo && exit 0
PROTECTED="${PROTECTED_BRANCHES:-main master develop release}"

# Explicit branch anywhere after `push`: not preceded by a name char, slash or dash
# (so feature/release-notes passes), followed by a non-name char (so release/1.2 is caught).
after_push=${CMD#*git*push}
for b in $PROTECTED; do
  if grep -qE "(^|[^[:alnum:]_./-])${b}([^[:alnum:]_.]|\$)" <<<"$after_push"; then
    block "push to protected branch '$b' is not allowed. Push a feature/* branch and open a PR."
  fi
done

# No branch named: only flags and at most one positional (the remote) → current branch.
positionals=0
for tok in $after_push; do
  case "$tok" in -*) ;; *) positionals=$((positionals + 1)) ;; esac
done
if (( positionals <= 1 )); then
  cur=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  for b in $PROTECTED; do
    if [[ "$cur" == "$b" || "$cur" == "$b/"* || "$cur" == "$b-"* ]]; then
      block "current branch '$cur' is protected. Check out a feature/* branch before pushing."
    fi
  done
fi
exit 0
