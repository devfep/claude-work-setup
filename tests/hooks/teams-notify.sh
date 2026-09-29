#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/tests/lib.sh"
h=teams-notify.sh
shim=$(mktemp -d); log="$shim/curl.log"
cat >"$shim/curl" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "${CURL_LOG:?}"
exit 0
SHIM
chmod +x "$shim/curl"
export PATH="$shim:$PATH" CURL_LOG="$log"
need() { grep -q -- "$1" "$log" || { echo "  $2" >&2; exit 1; }; }

# no URL: exit 0, curl never called
export CLAUDE_WORK_OVERLAY=/nonexistent
assert_hook $h 0 '{"hook_event_name":"Stop","last_assistant_message":"done"}'
[[ ! -f "$log" ]] || { echo "  curl was called without a webhook URL" >&2; exit 1; }

ov=$(mktemp); echo "TEAMS_WEBHOOK_URL='https://example.invalid/hook'" >"$ov"
export CLAUDE_WORK_OVERLAY=$ov
assert_hook $h 0 '{"hook_event_name":"Notification","message":"Claude needs input","cwd":"/w/proj"}'
need 'https://example.invalid/hook' 'webhook URL not posted to'
need 'Claude needs input' 'message missing from payload'
need 'Notification' 'event name missing from title'
need 'proj' 'cwd basename missing from title'

: >"$log"
bash "$ROOT/claude/hooks/$h" --text "PENDING: pick a schema" </dev/null
need 'PENDING: pick a schema' '--text mode not posted'

# malformed stdin still exits 0
assert_hook $h 0 'not json' 'malformed input tolerated'

# curl failure still exits 0
cat >"$shim/curl" <<'SHIM'
#!/usr/bin/env bash
exit 22
SHIM
assert_hook $h 0 '{"hook_event_name":"Stop","last_assistant_message":"x"}' 'curl failure tolerated'
