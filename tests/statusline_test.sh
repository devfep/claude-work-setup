#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/tests/lib.sh"
sl="$ROOT/claude/statusline.sh"
fail() { echo "  $*" >&2; exit 1; }
render() { printf '%s' "$1" | bash "$sl" 2>&1 || fail "statusline exited non-zero for: $2"; }

repo=$(tmp_repo)
git -C "$repo" checkout -q -b feature/ABC-1-x
json=$(jq -cn --arg d "$repo" '{workspace:{current_dir:$d}, model:{display_name:"Claude Opus"},
  cost:{total_cost_usd:1.234, total_duration_ms:65000},
  context_window:{remaining_percentage:70}}')
out=$(render "$json" 'repo dir')
for want in Opus "$(basename "$repo")" feature/ABC-1-x '30%' '1m 5s'; do
  grep -qF -- "$want" <<<"$out" || fail "missing '$want' in: $out"
done

plain=$(mktemp -d)
out=$(render "$(jq -cn --arg d "$plain" '{workspace:{current_dir:$d}}')" 'non-git dir')
grep -qF "$(basename "$plain")" <<<"$out" || fail "folder missing outside git: $out"

render 'not json' 'malformed input' >/dev/null
