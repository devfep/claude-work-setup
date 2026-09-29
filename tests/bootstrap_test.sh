#!/usr/bin/env bash
set -euo pipefail
fail() { echo "  $*" >&2; exit 1; }
home=$(mktemp -d)
ebs="$home/ebs"; mkdir -p "$ebs/.claude/skills/platform-skill" "$ebs/projects"
echo 'export PLATFORM=1' >"$ebs/.shellrc"
echo '{"model":"old"}' >"$ebs/.claude/settings.json"
ln -s "$ebs/.claude" "$home/.claude"
repo="$ebs/projects/app-admin/app-admin"; mkdir -p "$ebs/projects/app-admin"
git -C "$ebs/projects/app-admin" init -q app-admin   # nested like the workspace UI lays it out
fixture="$ROOT/projects/app-admin"
[[ ! -e "$fixture" ]] || fail "$fixture already exists; the test would clobber it"
mkdir -p "$fixture/skills/verify-app-admin"
trap 'rm -r "$fixture"' EXIT
printf '# local\n' >"$fixture/CLAUDE.local.md"
printf -- '---\nname: verify-app-admin\ndescription: t\n---\n' \
  >"$fixture/skills/verify-app-admin/SKILL.md"

run() {
  HOME=$home PERSIST_DIR=$ebs PROJECTS_DIR=$ebs/projects SKIP_TOOLS=1 \
    bash "$ROOT/bootstrap.sh" >"$home/out.txt" 2>&1 || { cat "$home/out.txt"; return 1; }
}
# tree <dir>: one line per path with its type, link target and content checksum
tree() {
  (cd "$1" && find . | sort | while IFS= read -r p; do
    if [[ -L "$p" ]]; then echo "$p l $(readlink "$p")"
    elif [[ -d "$p" ]]; then echo "$p d"
    else echo "$p f $(cksum <"$p")"; fi
  done)
}
run

c="$ebs/.claude"
[[ -f "$c/overlay.env" ]] || fail "overlay not seeded"
for l in CLAUDE.md hooks commands statusline.sh; do
  [[ -L "$c/$l" ]] || fail "config link $l missing"
done
[[ -d "$c/skills/platform-skill" && ! -L "$c/skills" ]] || fail "platform skills dir replaced"
[[ -L "$c/skills/humanizer" ]] || fail "humanizer skill not linked"
[[ -L "$c/skills/verify-app-admin" ]] || fail "project verify skill not linked"
[[ -L "$ebs/tools/bin/cdp" ]] || fail "cdp CLI not linked"
jq -e '.permissions.defaultMode == "acceptEdits"' "$c/settings.json" >/dev/null \
  || fail "settings not rendered as interactive"
[[ -f "$c/settings.json.pre-bootstrap" ]] || fail "old settings not backed up"
grep -q '^export PATH=.*tools/bin' "$ebs/.shellrc" || fail "shellrc PATH line missing"
grep -q 'PLATFORM=1' "$ebs/.shellrc" || fail "shellrc platform line lost"
[[ -L "$repo/CLAUDE.local.md" ]] || fail "project CLAUDE.local.md not linked"
grep -qx 'CLAUDE.local.md' "$repo/.git/info/exclude" || fail "exclude entry missing"

# idempotent: second run changes nothing
before=$(tree "$ebs")
run
after=$(tree "$ebs")
if [[ "$before" != "$after" ]]; then
  diff <(echo "$before") <(echo "$after") >&2 || true
  fail "second run changed the tree"
fi
[[ $(grep -c '^export PATH=' "$ebs/.shellrc") == 1 ]] || fail "PATH line duplicated"

# firm additions merge into the rendered settings
firm_json='{"enabledPlugins":{"x@internal":true},'
firm_json+='"extraKnownMarketplaces":{"internal":'
firm_json+='{"source":{"source":"git","url":"http://x/internal.git"}}}}'
printf '%s\n' "$firm_json" >"$ebs/.claude/settings.firm.json"
run
jq -e '.enabledPlugins["x@internal"] == true
  and .extraKnownMarketplaces.internal.source.url == "http://x/internal.git"
  and .permissions.defaultMode == "acceptEdits"' "$ebs/.claude/settings.json" >/dev/null \
  || fail "settings.firm.json not merged"
mv "$ebs/.claude/settings.firm.json" "$ebs/.claude/settings.firm.json.used"

# unattended mode renders bypassPermissions
sed -i.bak 's/^WORKSPACE_MODE=.*/WORKSPACE_MODE=unattended/' "$c/overlay.env"
run
jq -e '.permissions.defaultMode == "bypassPermissions"' "$c/settings.json" >/dev/null \
  || fail "unattended not rendered"
