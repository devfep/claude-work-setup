#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/tests/lib.sh"
h=require-jira-prefix.sh
repo=$(tmp_repo)
cd "$repo"
assert_hook $h 0 "$(bash_json 'git commit -m "ABC-123 add thing"')"
assert_hook $h 0 "$(bash_json "git commit -m 'DATA-7: add thing'")"
assert_hook $h 0 "$(bash_json 'git commit -am "X9-1 quick"')"
assert_hook $h 0 "$(bash_json 'git commit --message="ABC-1 x"')"
assert_hook $h 2 "$(bash_json 'git commit -m "add thing"')"
assert_hook $h 2 "$(bash_json 'git commit -m "abc-123 lowercase"')"
assert_hook $h 2 "$(bash_json 'git commit -m "feat: ABC-1 later"')"
assert_hook $h 0 "$(bash_json 'git commit --amend --no-edit')"
assert_hook $h 2 "$(bash_json 'git commit')" 'no message at all'
assert_hook $h 0 "$(bash_json 'git status')"
assert_hook $h 0 "$(bash_json 'echo git commit -m nope')"
assert_hook $h 2 "$(bash_json 'git -c http.proxy=http://p:1 commit -m "no key"')" 'proxy -c form'

heredoc_ok=$'git commit -m "$(cat <<\'EOF\'\nABC-55 subject line\n\nBody text.\nEOF\n)"'
heredoc_bad=$'git commit -m "$(cat <<\'EOF\'\nsubject without key\nEOF\n)"'
assert_hook $h 0 "$(bash_json "$heredoc_ok")" 'heredoc with key'
assert_hook $h 2 "$(bash_json "$heredoc_bad")" 'heredoc without key'

printf 'ABC-9 from file\n\nbody\n' > msg-ok.txt
printf 'from file\n' > msg-bad.txt
assert_hook $h 0 "$(bash_json 'git commit -F msg-ok.txt')" '-F ok'
assert_hook $h 2 "$(bash_json 'git commit -F msg-bad.txt')" '-F bad'

ov=$(mktemp); echo "JIRA_KEY_REGEX='[A-Z]{2}[0-9]{3}'" >"$ov"
CLAUDE_WORK_OVERLAY=$ov assert_hook $h 0 "$(bash_json 'git commit -m "AB123 custom"')" 'overlay regex ok'
CLAUDE_WORK_OVERLAY=$ov assert_hook $h 2 "$(bash_json 'git commit -m "ABC-123 default no longer ok"')" 'overlay regex rejects'

mkdir -p .claude && touch .claude/workflow-repo
assert_hook $h 0 "$(bash_json 'git commit -m "Checkpoint state"')" 'workflow repo exempt'
