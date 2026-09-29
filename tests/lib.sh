#!/usr/bin/env bash
# Shared helpers for hook tests. Source this file; do not execute it.

# assert_hook <hook-file-name> <expected-exit> <json-stdin> [<label>]
assert_hook() {
  local hook="$ROOT/claude/hooks/$1" want="$2" json="$3" label="${4:-$3}" got=0
  printf '%s' "$json" | bash "$hook" >/dev/null 2>&1 || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "  expected exit $want, got $got for: $label" >&2
    return 1
  fi
}

# bash_json <command> -> PreToolUse JSON for a Bash tool call
bash_json() {
  jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'
}

# file_json <path> -> PreToolUse JSON for an Edit tool call
file_json() {
  jq -cn --arg p "$1" '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$p}}'
}

# tmp_repo -> prints the path of a fresh git repo with one commit, cwd unchanged
tmp_repo() {
  local d
  d=$(mktemp -d)
  git -C "$d" init -q
  git -C "$d" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "ABC-1 init"
  echo "$d"
}
