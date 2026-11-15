#!/bin/bash
# nell-status.sh <nell-socket> [<your status command>] — posts Claude Code's status JSON (stdin) to Nell, for her usage
# chips. With your own status line (from ~/.claude/settings.json) it prints that command's output; without, Nell's line.
# Never slows Claude down: if Nell can't be reached it gives up fast, prints nothing of hers and exits as yours did (or 0).
post() { /usr/bin/curl -sf -m 0.3 -H 'Expect:' --unix-socket "$1" --data-binary @- http://nell/status; }
if [ -z "${2:-}" ]; then post "$1"; exit 0; fi
input=$(/bin/cat; printf x); input=${input%x} # the x keeps trailing newlines: yours gets exactly what Claude sent
printf '%s' "$input" | post "$1" >/dev/null 2>&1 &
printf '%s' "$input" | /bin/sh -c "$2"; rc=$?
wait
exit $rc
