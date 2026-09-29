#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/tests/lib.sh"
h=block-local-only.sh
repo=$(tmp_repo); cd "$repo"
assert_hook $h 2 "$(bash_json 'git add CLAUDE.local.md')"
assert_hook $h 2 "$(bash_json 'git add -f .claude/settings.local.json')"
assert_hook $h 2 "$(bash_json 'git commit -m "ABC-1 x" -- CLAUDE.local.md')"
assert_hook $h 2 "$(bash_json 'git rm --cached CLAUDE.local.md')"
assert_hook $h 2 "$(bash_json 'git add "CLAUDE.local.md"')" 'quoted path'
assert_hook $h 2 "$(bash_json 'git add CLAUDE.local.md && git status')" 'chained'
assert_hook $h 2 "$(bash_json 'git -c core.x=1 add overlay.env')" 'global option form'
assert_hook $h 0 "$(bash_json 'git add src/app.ts')"
assert_hook $h 0 "$(bash_json 'git add -A')"
assert_hook $h 0 "$(bash_json 'cat CLAUDE.local.md')"
assert_hook $h 0 "$(bash_json 'git commit -m "ABC-1 update CLAUDE.md"')"
ov=$(mktemp); echo "LOCAL_ONLY_PATTERNS='secret.txt'" >"$ov"
export CLAUDE_WORK_OVERLAY=$ov
assert_hook $h 2 "$(bash_json 'git add secret.txt')" 'overlay pattern'
assert_hook $h 0 "$(bash_json 'git add CLAUDE.local.md')" 'overlay replaces defaults'
export CLAUDE_WORK_OVERLAY=/nonexistent
mkdir -p .claude && touch .claude/workflow-repo
assert_hook $h 0 "$(bash_json 'git add projects/x/CLAUDE.local.md')" 'workflow repo exempt'
