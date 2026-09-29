#!/usr/bin/env bash
# PreToolUse(Bash): commit subjects must start with a JIRA key (firm convention).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
CMD=$(jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0
is_git_subcommand commit "$CMD" || exit 0
in_workflow_repo && exit 0
REGEX="${JIRA_KEY_REGEX:-[A-Z][A-Z0-9]+-[0-9]+}"

subject=""
if grep -qE -- '(-m|--message)[[:space:]]+"\$\(cat[[:space:]]+<<' <<<"$CMD"; then
  # heredoc subject: first line after the <<'EOF' opener
  subject=$(awk "/<<-?'?[A-Za-z_]+'?[[:space:]]*\$/ {getline; print; exit}" <<<"$CMD")
elif grep -qE -- '(^|[[:space:]])-F[[:space:]]+|--file[= ]' <<<"$CMD"; then
  file=$(grep -oE -- '(-F[[:space:]]+|--file[= ])[^[:space:]]+' <<<"$CMD" | head -1 \
    | sed -E 's/^(-F[[:space:]]+|--file[= ])//' || true)
  if [[ -f "$file" ]]; then subject=$(head -1 "$file"); fi
else
  quoted='"[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+'
  subject=$(grep -oE -- "(-[a-zA-Z]*m|--message)(=|[[:space:]]+)($quoted)" <<<"$CMD" | head -1 \
    | sed -E 's/^(-[a-zA-Z]*m|--message)(=|[[:space:]]+)//; s/^["'"'"']//; s/["'"'"']$//' \
    || true)
fi

if [[ -z "$subject" ]]; then
  grep -qE -- '--amend' <<<"$CMD" && exit 0
  block "no commit message found. Use git commit -m \"<JIRA-KEY> subject\"."
fi
[[ "$subject" =~ ^($REGEX) ]] && exit 0
block "commit subject must start with a JIRA key matching /$REGEX/. Got: '$subject'"
