#!/usr/bin/env bash
set -euo pipefail
tmpl="$ROOT/claude/settings.json.tmpl"
fail() { echo "  $*" >&2; exit 1; }
for mode in acceptEdits bypassPermissions; do
  out=$(sed "s#__DEFAULT_MODE__#$mode#g" "$tmpl")
  jq -e . <<<"$out" >/dev/null || fail "template does not render to valid JSON for $mode"
  [[ $(jq -r '.permissions.defaultMode' <<<"$out") == "$mode" ]] || fail "defaultMode not rendered"
done
out=$(sed "s#__DEFAULT_MODE__#acceptEdits#g" "$tmpl")
hooks='block-rm-rf block-protected-push require-jira-prefix block-local-only
  enforce-package-manager protect-files teams-notify'
grep -q "exec rtk hook claude; exit 0" <<<"$out" \
  || { echo "  rtk hook not wired as a no-op when absent" >&2; exit 1; }
for hook in $hooks; do
  grep -q "hooks/$hook.sh" <<<"$out" || fail "hook $hook not wired"
  [[ -x "$ROOT/claude/hooks/$hook.sh" ]] || fail "wired hook $hook.sh does not exist"
done
if grep -q 'osascript' <<<"$out"; then fail "macOS notification left in"; fi
if grep -qE 'Library/|\.claude-alt' <<<"$out"; then fail "Mac-only path left in"; fi
plugins='superpowers@superpowers-marketplace modern-python@trailofbits gh-cli@trailofbits
  pstack@pstack-claude'
for p in $plugins; do
  enabled=$(jq -r --arg p "$p" '.enabledPlugins[$p]' <<<"$out")
  [[ "$enabled" == "true" ]] || fail "plugin $p not enabled"
done
while read -r name repo; do
  got=$(jq -r --arg n "$name" '.extraKnownMarketplaces[$n].source.repo' <<<"$out")
  [[ "$got" == "$repo" ]] || fail "marketplace $name source missing"
done <<'EOF'
superpowers-marketplace obra/superpowers-marketplace
trailofbits trailofbits/skills
pstack-claude hadifarnoud/pstack-claude
EOF
