#!/usr/bin/env bash
set -euo pipefail
fail() { echo "  $*" >&2; exit 1; }
chrome=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "$(command -v google-chrome || true)" "$(command -v chromium || true)"; do
  if [[ -n "$c" && -x "$c" ]]; then chrome=$c; break; fi
done
if [[ -z "$chrome" ]]; then
  echo "  SKIP: no Chrome found; cdp is proven in the pod by docs/POD-CHECKLIST.md"
  exit 0
fi
port=$(( 20000 + RANDOM % 20000 )); tmp=$(mktemp -d)
"$chrome" --headless=new --remote-debugging-port=$port --user-data-dir="$tmp/profile" \
  --no-first-run about:blank >/dev/null 2>&1 &
cpid=$!
trap 'kill $cpid 2>/dev/null; wait $cpid 2>/dev/null || true' EXIT
for _ in $(seq 1 50); do
  curl -fsS "http://127.0.0.1:$port/json/version" >/dev/null 2>&1 && break
  sleep 0.2
done
export CDP_URL="http://127.0.0.1:$port"
cdp="node $ROOT/tools/cdp.mjs"
# capture <cmd-args> <out-file>: run a cdp collector in the background, record its exit code
capture() { ( rc=0; $cdp "$1" 2 >"$tmp/$2.jsonl" || rc=$?; echo $rc >"$tmp/$2.rc" ) & }

$cdp doctor | grep -q 'Browser:' || fail "doctor missing Browser line"
CDP_TARGET=$($cdp new about:blank); export CDP_TARGET
[[ -n "$CDP_TARGET" ]] || fail "new printed no id"
page='data:text/html,<title>t</title><button id="b" aria-label="Go"'
page+=' onclick="document.title=%27clicked%27">Go</button><input id="i">'
$cdp nav "$page"
$cdp wait '#b' 5000
$cdp snapshot | grep -qi 'button.*Go' || fail "snapshot lacks the button"
$cdp click '#b'
[[ $($cdp eval 'document.title') == '"clicked"' ]] || fail "click did not change title"
$cdp type '#i' 'hello'
[[ $($cdp eval 'document.getElementById("i").value') == '"hello"' ]] || fail "type did not fill"
$cdp screenshot "$tmp/shot.png"
[[ $(head -c 8 "$tmp/shot.png" | xxd -p) == 89504e470d0a1a0a ]] || fail "screenshot is not a PNG"

capture console console; bg=$!
sleep 0.5; $cdp eval 'console.error("boom")' >/dev/null; wait $bg
grep -q 'boom' "$tmp/console.jsonl" || fail "console capture missed the error"
[[ $(cat "$tmp/console.rc") == 1 ]] || fail "console should exit 1 on an error"

capture console replay; bg=$!
wait $bg
grep -q 'boom' "$tmp/replay.jsonl" || fail "console should replay errors logged since page load"
$cdp nav 'data:text/html,<p>quiet</p>'
capture console quiet; bg=$!
wait $bg
[[ $(cat "$tmp/quiet.rc") == 0 ]] || fail "console should exit 0 on a fresh page with no errors"

capture network network; bg=$!
sleep 0.5; $cdp eval 'fetch("http://127.0.0.1:1/nope").catch(()=>0)' >/dev/null; wait $bg
[[ $(cat "$tmp/network.rc") == 1 ]] || fail "network should exit 1 on a failed request"

rc=0; $cdp click '#missing' 2>/dev/null || rc=$?
[[ $rc == 2 ]] || fail "click on a missing selector should exit 2, got $rc"
$cdp close "$CDP_TARGET"
rc=0; $cdp eval '1' 2>/dev/null || rc=$?
[[ $rc == 2 ]] || fail "eval on a closed target should exit 2, got $rc"
