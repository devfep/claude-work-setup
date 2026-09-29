#!/usr/bin/env bash
# Notification/Stop hook or CLI: post a short Adaptive Card to a Teams webhook. Never blocks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[[ -z "${TEAMS_WEBHOOK_URL:-}" ]] && exit 0

if [[ "${1:-}" == "--text" ]]; then
  title="Claude Code · $(basename "$PWD")"
  body="${2:-}"
else
  input=$(cat)
  event=$(jq -r '.hook_event_name // "event"' <<<"$input" 2>/dev/null || echo event)
  cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null || true)
  title="Claude Code · $event · $(basename "${cwd:-$PWD}")"
  body=$(jq -r '.message // .last_assistant_message // "(no message)"' <<<"$input" 2>/dev/null \
    || echo "(unreadable hook input)")
  body=${body:0:800}
fi

payload=$(jq -cn --arg t "$title" --arg b "$body" '{
  type: "message",
  attachments: [{
    contentType: "application/vnd.microsoft.card.adaptive",
    content: {
      "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
      type: "AdaptiveCard", version: "1.4",
      body: [
        {type: "TextBlock", text: $t, weight: "Bolder", wrap: true},
        {type: "TextBlock", text: $b, wrap: true}
      ]
    }
  }]
}')
if ! curl -fsS -m 10 -H 'Content-Type: application/json' -d "$payload" "$TEAMS_WEBHOOK_URL" \
  >/dev/null 2>&1; then
  echo "teams-notify: post failed (webhook unreachable or rejected)" >&2
fi
exit 0
