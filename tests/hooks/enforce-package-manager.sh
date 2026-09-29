#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/tests/lib.sh"
h=enforce-package-manager.sh
py=$(mktemp -d); touch "$py/pyproject.toml"
node=$(mktemp -d); touch "$node/pnpm-lock.yaml"
plain=$(mktemp -d)
export CLAUDE_PROJECT_DIR=$py
assert_hook $h 2 "$(bash_json 'pip install requests')" 'pip in uv project'
assert_hook $h 2 "$(bash_json 'pip3 install requests')" 'pip3'
assert_hook $h 2 "$(bash_json 'python -m pip install x')" 'python -m pip'
assert_hook $h 2 "$(bash_json 'cd sub && pip install x')" 'chained pip'
assert_hook $h 0 "$(bash_json 'uv pip install requests')" 'uv pip ok'
assert_hook $h 0 "$(bash_json 'uv add requests')" 'uv add ok'
assert_hook $h 0 "$(bash_json 'uv run python -m pip --version')" 'pip under uv run'
export CLAUDE_PROJECT_DIR=$plain
assert_hook $h 0 "$(bash_json 'pip install x')" 'no python markers'
assert_hook $h 0 "$(bash_json 'npm install')" 'npm without pnpm lock'
export CLAUDE_PROJECT_DIR=$node
assert_hook $h 2 "$(bash_json 'npm install')" 'npm in pnpm project'
assert_hook $h 2 "$(bash_json 'cd web && npm ci')" 'chained npm'
assert_hook $h 0 "$(bash_json 'pnpm install')" 'pnpm ok'
