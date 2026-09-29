#!/usr/bin/env bash
# Sourced by hooks. Loads the overlay if present and defines helpers.
OVERLAY="${CLAUDE_WORK_OVERLAY:-$HOME/ebs/.claude/overlay.env}"
if [[ -f "$OVERLAY" ]]; then
  # shellcheck disable=SC1090  # path is runtime-defined by design
  source "$OVERLAY"
fi

# block <reason>: print and exit 2
block() { echo "BLOCKED: $*" >&2; exit 2; }

# in_workflow_repo: true when cwd is inside this setup repo (marker file)
in_workflow_repo() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  [[ -f "$root/.claude/workflow-repo" ]]
}

# is_git_subcommand <name-or-ERE-group> <cmd>: true if cmd runs `git <name>` at a command boundary.
# A boundary is line start or ; & | ( followed by optional VAR=value prefixes. Global options
# before the subcommand may take a value (`-c http.proxy=…`, `-C dir`), as the pod's git does.
is_git_subcommand() {
  local start='(^|[;&|(])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
  local opts='([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|-[^[:space:]]+))*'
  grep -qE "${start}git${opts}[[:space:]]+$1([[:space:]]|\$)" <<<"$2"
}
