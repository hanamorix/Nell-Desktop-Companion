#!/bin/bash
# nell-status.sh <nell-socket> [<your status command, as at launch>] — posts Claude Code's status JSON (stdin) to Nell, for
# her usage chips. With your own status line it prints your command's output; without, Nell's line.
# Never slows Claude down: if Nell can't be reached it gives up fast and prints nothing of hers.
post() { /usr/bin/curl -sf -m 0.3 -H 'Expect:' --unix-socket "$1" --data-binary @- http://nell/status; }
# read-only, on each run, so /statusline inside Nell takes effect at once; the launch-time copy covers an unreadable file.
# shortcut: removing your status line mid-session keeps the launch-time one until Nell restarts; tell "no key" from "can't read" if that matters.
cmd=$(/usr/bin/plutil -extract statusLine.command raw -o - "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" 2>/dev/null) || cmd=${2:-}
if [ -z "$cmd" ]; then post "$1"; exit 0; fi
input=$(/bin/cat; printf x); input=${input%x} # the x keeps trailing newlines: yours gets exactly what Claude sent
printf '%s' "$input" | post "$1" >/dev/null 2>&1 &
# exec: this process becomes your command, so Claude's SIGTERM (a slow line it gives up on) reaches it and its exit status is Claude's
exec /bin/sh -c "$cmd" < <(printf '%s' "$input")
