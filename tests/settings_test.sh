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
# Plugins and marketplaces are a firm-side decision (settings.firm.json), never fetched from
# outside by the generic template.
if jq -e '.extraKnownMarketplaces // .enabledPlugins' <<<"$out" >/dev/null 2>&1; then
  fail "template must not declare marketplaces or plugins"
fi
if grep -qE '"source": *"github"' <<<"$out"; then fail "external marketplace source left in"; fi
