#!/usr/bin/env bash
# PreToolUse(Bash): refuse recursive+force rm. The pod has no trash; move aside instead.
set -euo pipefail
CMD=$(jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0
starts_rm='(^|;[[:space:]]*|&&[[:space:]]*|\|\|[[:space:]]*|\|[[:space:]]*)rm[[:space:]]'
if grep -qE "$starts_rm" <<<"$CMD" \
  && grep -qE '(^|[[:space:]])-[a-zA-Z]*[rR]|--recursive' <<<"$CMD" \
  && grep -qE '(^|[[:space:]])-[a-zA-Z]*[fF]|--force' <<<"$CMD"; then
  echo 'BLOCKED: rm -rf is not allowed. Move the path into a scratch directory with mv,' \
    'or delete one path without -f.' >&2
  exit 2
fi
exit 0
