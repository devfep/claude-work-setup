#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/tests/lib.sh"
h=block-protected-push.sh
assert_hook $h 2 "$(bash_json 'git push origin main')"
assert_hook $h 2 "$(bash_json 'git push origin master')"
assert_hook $h 2 "$(bash_json 'git push -u origin develop')"
assert_hook $h 2 "$(bash_json 'git push origin release/1.2')"
assert_hook $h 2 "$(bash_json 'git push origin release-1.2')"
assert_hook $h 2 "$(bash_json 'git push origin HEAD:develop')"
assert_hook $h 2 "$(bash_json 'git push origin feature/ABC-1-x:main')"
assert_hook $h 2 "$(bash_json 'cd repo && git push origin main')"
assert_hook $h 2 "$(bash_json 'git -c http.proxy=http://p:1 push origin develop')" 'proxy -c form'
assert_hook $h 2 "$(bash_json 'git -C repo push origin main')" '-C dir form'
assert_hook $h 2 "$(bash_json 'GIT_TRACE=1 git push origin main')" 'env prefix'
assert_hook $h 2 "$(bash_json 'x=$(git push origin main)')" 'command substitution'
assert_hook $h 2 "$(bash_json 'git push origin "develop"')" 'quoted branch'
assert_hook $h 2 "$(bash_json 'git push origin +master')" 'force refspec'
assert_hook $h 0 "$(bash_json 'git -c http.proxy=http://p:1 push origin feature/ABC-1-x')" \
  'proxy form, feature'
assert_hook $h 0 "$(bash_json 'git push origin feature/ABC-1-x')"
assert_hook $h 0 "$(bash_json 'git push -u origin feature/release-notes')"
assert_hook $h 0 "$(bash_json 'git push origin feature/ABC-2-maintenance')"
assert_hook $h 0 "$(bash_json 'git pull origin main')"
assert_hook $h 0 "$(bash_json 'echo git push origin main')"

# bare `git push` uses the current branch
repo=$(tmp_repo)
git -C "$repo" checkout -q -b develop
( cd "$repo" && assert_hook $h 2 "$(bash_json 'git push')" 'bare push on develop' )
( cd "$repo" && assert_hook $h 2 "$(bash_json 'git push -u origin')" 'push -u origin on develop' )
git -C "$repo" checkout -q -b feature/ABC-3-thing
( cd "$repo" && assert_hook $h 0 "$(bash_json 'git push')" 'bare push on feature branch' )

# overlay overrides the list
ov=$(mktemp); echo "PROTECTED_BRANCHES='trunk'" >"$ov"
export CLAUDE_WORK_OVERLAY=$ov
assert_hook $h 2 "$(bash_json 'git push origin trunk')" 'overlay trunk'
assert_hook $h 0 "$(bash_json 'git push origin main')" 'overlay lets main through'
