#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/tests/lib.sh"
h=protect-files.sh
assert_hook $h 2 "$(file_json '/r/.env')"
assert_hook $h 2 "$(file_json '/r/.env.local')"
assert_hook $h 2 "$(file_json '/r/.git/config')"
assert_hook $h 2 "$(file_json '/r/package-lock.json')"
assert_hook $h 2 "$(file_json '/r/pnpm-lock.yaml')"
assert_hook $h 2 "$(file_json '/h/ebs/.claude/overlay.env')"
assert_hook $h 0 "$(file_json '/r/.env.example')"
assert_hook $h 0 "$(file_json '/r/overlay.env.example')"
assert_hook $h 0 "$(file_json '/r/src/environment.ts')"
assert_hook $h 0 "$(file_json '/r/gitlab-ci.yml')"
assert_hook $h 0 '{"tool_name":"Edit","tool_input":{}}'
