#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export ROOT
export CLAUDE_WORK_OVERLAY=/nonexistent   # hooks must work with no overlay
fail=0
for t in "$ROOT"/tests/hooks/*.sh "$ROOT"/tests/*_test.sh; do
  [[ -f "$t" ]] || continue
  if bash "$t"; then echo "PASS $(basename "$t")"; else echo "FAIL $(basename "$t")"; fail=1; fi
done
mapfile -t scripts < <(find "$ROOT" -name '*.sh' -not -path '*/.git/*' | sort)
shellcheck -S warning "${scripts[@]}" && echo "PASS shellcheck (${#scripts[@]} scripts)" || fail=1
for s in "${scripts[@]}"; do
  [[ -x "$s" || "$s" == */lib.sh ]] || { echo "FAIL not executable: $s"; fail=1; }
done
nested=$(find "$ROOT" -mindepth 2 -name .git -not -path "$ROOT/.git/*")
if [[ -n "$nested" ]]; then echo "FAIL embedded git repository: $nested"; fail=1; fi
long=$(awk 'length > 100 { print FILENAME ":" FNR }' "${scripts[@]}" "$ROOT"/tools/*.mjs)
if [[ -z "$long" ]]; then
  echo "PASS line length"
else
  echo "FAIL over 100 chars: $long"
  fail=1
fi
exit $fail
