#!/bin/bash
# nell-hook.sh <mode> <nell-socket> <event> — forwards one Claude Code hook event (stdin) to Nell.
# If Nell can't be reached, approvals raise this session's kitty console so Claude's own prompt is seen.
# Needs nothing on PATH, and no jq (it isn't on macOS before 15): Nell's settings pass the event name.
# Nell's kitty windows carry the user var nell_mode (an env tag would be inherited by any new tab).
mode="$1"; sock="$2"; event="$3"
# Nell passes the kitten she found in kitty's env; the default is for a kitty an older Nell started
KITTEN="${NELL_KITTEN:-/Applications/kitty.app/Contents/MacOS/kitten}"
input=$(/bin/cat)
# a Claude session started before the upgrade still runs the old two-argument command: read the event as before, where jq exists
[ -n "$event" ] || [ ! -x /usr/bin/jq ] || event=$(printf '%s' "$input" | /usr/bin/jq -r '.hook_event_name // empty' 2>/dev/null)
if [ "$event" = PermissionRequest ]; then max="${NELL_HOOK_DEADLINE:-590}"; else max=0.5; fi
# Expect: off — for big bodies curl otherwise waits 1 s for 100-continue, past the 0.5 s budget.
out=$(printf '%s' "$input" | /usr/bin/curl -sf -m "$max" -H 'Expect:' --unix-socket "$sock" --data-binary @- "http://nell/hook?mode=$mode")
rc=$?
if [ $rc -eq 0 ]; then
  [ "$event" = PermissionRequest ] && printf '%s' "$out"
  exit 0
fi
# Only "couldn't connect" (7) means Nell isn't running. A deadline or dropped reply means she is, and she offers the console herself.
[ $rc -eq 7 ] || exit 0
# Only an approval surfaces kitty without Nell: a plain notification isn't worth a window nobody asked for.
case "$event" in
  PermissionRequest)
    if [ -n "${KITTY_LISTEN_ON:-}" ]; then
      "$KITTEN" @ --to "$KITTY_LISTEN_ON" resize-os-window --match "var:nell_mode=$mode" --action show >/dev/null 2>&1
      "$KITTEN" @ --to "$KITTY_LISTEN_ON" focus-window --match "var:nell_mode=$mode" >/dev/null 2>&1
    fi ;;
esac
exit 0
