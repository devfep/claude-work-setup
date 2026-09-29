#!/usr/bin/env bash
# Idempotent workspace bootstrap. Safe to re-run after every workspace rebuild.
# Env overrides (mainly for tests): PERSIST_DIR, PROJECTS_DIR, SKIP_TOOLS=1.
set -euo pipefail
SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PERSIST_DIR="${PERSIST_DIR:-$HOME/ebs}"
CLAUDE_DIR="$PERSIST_DIR/.claude"
OVERLAY="$CLAUDE_DIR/overlay.env"
BIN="$PERSIST_DIR/tools/bin"

step() { echo "== $*"; }
link() {
  local src=$1 dst=$2
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    echo "keep: $dst exists and is not a symlink; move it aside and re-run to replace it"
    return 0
  fi
  if [[ "$(readlink "$dst" 2>/dev/null || true)" == "$src" ]]; then return 0; fi
  ln -sfn "$src" "$dst"
  echo "link: $dst -> $src"
}
append_once() {
  if ! grep -qxF -- "$2" "$1" 2>/dev/null; then echo "$2" >>"$1"; fi
}

step "overlay"
mkdir -p "$CLAUDE_DIR"
if [[ ! -f "$OVERLAY" ]]; then
  cp "$SETUP_DIR/overlay.env.example" "$OVERLAY"
  echo "seeded $OVERLAY from the example; edit it, then re-run"
fi
# shellcheck disable=SC1090  # runtime path by design
source "$OVERLAY"
PROJECTS_DIR="${PROJECTS_DIR:-$PERSIST_DIR/projects}"

case "$SETUP_DIR" in
  "$PERSIST_DIR"/*) ;;
  *) echo "warning: $SETUP_DIR is outside $PERSIST_DIR and will not survive a workspace rebuild" ;;
esac

step "config links"
link "$SETUP_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
link "$SETUP_DIR/claude/hooks" "$CLAUDE_DIR/hooks"
link "$SETUP_DIR/claude/commands" "$CLAUDE_DIR/commands"
link "$SETUP_DIR/claude/statusline.sh" "$CLAUDE_DIR/statusline.sh"
mkdir -p "$CLAUDE_DIR/skills" "$BIN"
for s in "$SETUP_DIR"/claude/skills/*/ "$SETUP_DIR"/projects/*/skills/*/; do
  [[ -d "$s" ]] || continue
  link "${s%/}" "$CLAUDE_DIR/skills/$(basename "$s")"
done
link "$SETUP_DIR/tools/cdp.mjs" "$BIN/cdp"

step "settings"
case "${WORKSPACE_MODE:-interactive}" in
  unattended) mode=bypassPermissions ;;
  *) mode=acceptEdits ;;
esac
rendered=$(sed "s#__DEFAULT_MODE__#$mode#g" "$SETUP_DIR/claude/settings.json.tmpl")
jq -e . <<<"$rendered" >/dev/null
if [[ -f "$CLAUDE_DIR/settings.json" && ! -f "$CLAUDE_DIR/settings.json.pre-bootstrap" ]] \
  && ! grep -q '"hooks"' "$CLAUDE_DIR/settings.json"; then
  cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.pre-bootstrap"
fi
if [[ "$(cat "$CLAUDE_DIR/settings.json" 2>/dev/null || true)" != "$rendered" ]]; then
  printf '%s\n' "$rendered" >"$CLAUDE_DIR/settings.json"
  echo "wrote settings.json (defaultMode=$mode)"
fi

step "shell PATH"
touch "$PERSIST_DIR/.shellrc"
# shellcheck disable=SC2016  # $HOME and $PATH expand when .shellrc is sourced, not now
path_line='export PATH="$HOME/ebs/tools/bin:$HOME/ebs/tools/npm/bin:$PATH"'
append_once "$PERSIST_DIR/.shellrc" "$path_line"
# Interactive uv (and uv inside Claude sessions) must see the same tool dir, index and CA.
# shellcheck disable=SC2016  # expands when sourced
uv_line='export UV_TOOL_DIR="$HOME/ebs/tools/uv-tools" UV_TOOL_BIN_DIR="$HOME/ebs/tools/bin"'
append_once "$PERSIST_DIR/.shellrc" "$uv_line"

install_tools() {
  mkdir -p "$PERSIST_DIR/tools/npm"
  export PATH="$BIN:$PATH"
  if ! command -v uv >/dev/null; then
    local venv="$PERSIST_DIR/tools/uv-venv"
    if [[ ! -x "$venv/bin/pip" ]]; then python3 -m venv "$venv"; fi
    "$venv/bin/pip" install --quiet ${PYPI_INDEX_URL:+--index-url "$PYPI_INDEX_URL"} uv
    ln -sfn "$venv/bin/uv" "$BIN/uv"
  fi
  export UV_TOOL_BIN_DIR="$BIN" UV_TOOL_DIR="$PERSIST_DIR/tools/uv-tools"
  # uv reads neither pip.conf nor the Node/Java trust settings: give it the same index and CA.
  if [[ -z "${PYPI_INDEX_URL:-}" ]]; then
    PYPI_INDEX_URL=$(pip config get global.index-url 2>/dev/null \
      || pip3 config get global.index-url 2>/dev/null || true)
  fi
  if [[ -n "${PYPI_INDEX_URL:-}" ]]; then
    export UV_DEFAULT_INDEX="$PYPI_INDEX_URL" UV_INDEX_URL="$PYPI_INDEX_URL"
    echo "uv index: $PYPI_INDEX_URL"
    append_once "$PERSIST_DIR/.shellrc" "export UV_DEFAULT_INDEX=\"$PYPI_INDEX_URL\""
  else
    echo "warn: no PyPI index known (overlay PYPI_INDEX_URL empty, pip config has none)"
  fi
  if [[ -z "${SSL_CERT_FILE:-}" && -n "${NODE_EXTRA_CA_CERTS:-}" \
        && -f "$NODE_EXTRA_CA_CERTS" ]]; then
    export SSL_CERT_FILE="$NODE_EXTRA_CA_CERTS"
    echo "uv CA: $SSL_CERT_FILE"
    append_once "$PERSIST_DIR/.shellrc" "export SSL_CERT_FILE=\"$NODE_EXTRA_CA_CERTS\""
  fi
  local t err
  for t in prek ruff ty sqlfluff shellcheck-py shfmt-py ast-grep-cli mutmut; do
    if ! err=$(uv tool install --quiet "$t" 2>&1); then
      echo "warn: could not install $t: $(tail -1 <<<"$err")"
    fi
  done
  for t in oxlint oxfmt; do
    if [[ -x "$PERSIST_DIR/tools/npm/bin/$t" ]]; then continue; fi
    if ! err=$(npm install -g --prefix "$PERSIST_DIR/tools/npm" "$t" 2>&1); then
      err=$(grep -m1 -E 'ERR!|error' <<<"$err" || tail -1 <<<"$err")
      echo "warn: could not install $t: $err"
    fi
  done
  if [[ -n "${RTK_VENDORED_REPO:-}" && ! -x "$BIN/rtk" ]]; then
    if command -v cargo >/dev/null; then
      local src="$PERSIST_DIR/tools/src/rtk-vendored"
      if [[ -d "$src/.git" ]]; then
        git -C "$src" pull -q --ff-only \
          || echo "warn: could not update $src; building what is there"
      else
        git clone -q "$RTK_VENDORED_REPO" "$src"
      fi
      echo "rtk: building offline from $src (one-time, several minutes on two CPUs)"
      if (cd "$src" && cargo build --release --offline --locked >"$src/build.log" 2>&1); then
        install -m 755 "$src/target/release/rtk" "$BIN/rtk"
        echo "rtk: $("$BIN/rtk" --version)"
      else
        err=$(grep -m1 -E '^error' "$src/build.log" || tail -1 "$src/build.log")
        echo "warn: rtk build failed: $err"
      fi
    else
      echo "warn: RTK_VENDORED_REPO is set but cargo is not on PATH" \
        "(activate rust via toolchain, then re-run)"
    fi
  fi
  local restore="$PERSIST_DIR/tools/restore-workspace-tooling.sh"
  if [[ -x "$restore" ]]; then
    step "user restore script"
    "$restore" || echo "warn: restore script exited non-zero"
  fi
}
if [[ "${SKIP_TOOLS:-0}" != "1" ]]; then
  step "tools (via internal mirrors)"
  install_tools
fi

step "projects"
for p in "$SETUP_DIR"/projects/*/; do
  [[ -d "$p" ]] || continue
  name=$(basename "$p"); repo="$PROJECTS_DIR/$name"
  # The workspace UI nests a project's checkout one level down: <name>/<name>/.git
  if [[ ! -d "$repo/.git" && -d "$repo/$name/.git" ]]; then repo="$repo/$name"; fi
  if [[ ! -d "$repo/.git" ]]; then echo "skip: $repo is not a git checkout"; continue; fi
  if [[ -f "$p/CLAUDE.local.md" ]]; then link "${p}CLAUDE.local.md" "$repo/CLAUDE.local.md"; fi
  mkdir -p "$repo/.git/info"
  for f in CLAUDE.local.md .claude/settings.local.json .worktrees/; do
    append_once "$repo/.git/info/exclude" "$f"
  done
done

step "done"
echo "Restart any open Claude sessions so hooks and settings load. Plugins install on first launch."
