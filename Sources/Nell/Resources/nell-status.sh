#!/bin/bash
# nell-status.sh <nell-socket> — posts Claude Code's status JSON (stdin) to Nell and prints her one-line reply.
# Never slows Claude down: if Nell can't be reached it gives up fast, prints nothing and exits 0.
/usr/bin/curl -sf -m 0.3 -H 'Expect:' --unix-socket "$1" --data-binary @- http://nell/status
exit 0
