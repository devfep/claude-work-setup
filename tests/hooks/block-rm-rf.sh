#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/tests/lib.sh"
assert_hook block-rm-rf.sh 2 "$(bash_json 'rm -rf /tmp/x')"
assert_hook block-rm-rf.sh 2 "$(bash_json 'rm -fr build')"
assert_hook block-rm-rf.sh 2 "$(bash_json 'cd x && rm -r -f y')"
assert_hook block-rm-rf.sh 2 "$(bash_json 'ls | rm --recursive --force z')"
assert_hook block-rm-rf.sh 0 "$(bash_json 'rm -r build')"
assert_hook block-rm-rf.sh 0 "$(bash_json 'rm -f file.txt')"
assert_hook block-rm-rf.sh 0 "$(bash_json 'git rm -rf --cached dir')"
assert_hook block-rm-rf.sh 0 "$(bash_json 'echo rm -rf')"
assert_hook block-rm-rf.sh 0 '{"tool_name":"Bash","tool_input":{}}'
