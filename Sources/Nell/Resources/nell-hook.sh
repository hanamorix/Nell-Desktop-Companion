#!/bin/bash
# nell-hook.sh <mode> <nell-socket> — forwards one Claude Code hook event (stdin) to Nell.
# If Nell can't be reached, approvals raise this session's kitty console so Claude's own prompt is seen.
mode="$1"; sock="$2"
KITTEN="${NELL_KITTEN:-/Applications/kitty.app/Contents/MacOS/kitten}"
input=$(cat)
event=$(printf '%s' "$input" | /usr/bin/jq -r '.hook_event_name // empty' 2>/dev/null)
if [ "$event" = PermissionRequest ]; then max=590; else max=0.5; fi
# Expect: off — for big bodies curl otherwise waits 1 s for 100-continue, past the 0.5 s budget.
if out=$(printf '%s' "$input" | /usr/bin/curl -sf -m "$max" -H 'Expect:' --unix-socket "$sock" --data-binary @- "http://nell/hook?mode=$mode"); then
  [ "$event" = PermissionRequest ] && printf '%s' "$out"
  exit 0
fi
# Only an approval surfaces kitty without Nell: a plain notification isn't worth a window nobody asked for.
case "$event" in
  PermissionRequest)
    if [ -n "${KITTY_LISTEN_ON:-}" ]; then
      "$KITTEN" @ --to "$KITTY_LISTEN_ON" resize-os-window --match "env:NELL_MODE=$mode" --action show >/dev/null 2>&1
      "$KITTEN" @ --to "$KITTY_LISTEN_ON" focus-window --match "env:NELL_MODE=$mode" >/dev/null 2>&1
    fi ;;
esac
exit 0
