#!/bin/bash
# Tests hooks/nell-hook.sh with Nell unreachable: non-blocking events stay silent and fast; approvals raise kitty.
set -u
cd "$(dirname "$0")/.."
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
printf '#!/bin/bash\necho "$@" >> %q\n' "$T/calls" > "$T/kitten"; chmod +x "$T/kitten"
F=Tests/NellCoreTests/Fixtures
fail=0
run() { NELL_KITTEN="$T/kitten" KITTY_LISTEN_ON="unix:$T/kitty-1.sock" bash Sources/Nell/Resources/nell-hook.sh code "$T/nope.sock" < "$1"; }

start=$(date +%s); out=$(run $F/PreToolUse-Bash.json); rc=$?; secs=$(( $(date +%s) - start ))
if [ $rc -eq 0 ] && [ -z "$out" ] && [ $secs -le 1 ] && [ ! -e "$T/calls" ]; then echo PASS preToolUseSilentWhenNellDown; else echo "FAIL preToolUse rc=$rc out=[$out] secs=$secs"; fail=1; fi

out=$(run $F/PermissionRequest-Bash.json); rc=$?
if [ $rc -eq 0 ] && [ -z "$out" ] && grep -q "resize-os-window --match env:NELL_MODE=code --action show" "$T/calls" && grep -q "focus-window --match env:NELL_MODE=code" "$T/calls"; then echo PASS permissionRaisesKittyWhenNellDown; else echo "FAIL permission rc=$rc out=[$out] calls=[$(cat "$T/calls" 2>/dev/null)]"; fail=1; fi
out=$(run $F/Notification-idle_prompt.json); rc=$?
if [ $rc -eq 0 ] && [ -z "$out" ] && ! grep -q "idle" "$T/calls" 2>/dev/null && [ "$(wc -l < "$T/calls")" -eq 2 ]; then echo PASS notificationDoesNotRaiseKitty; else echo "FAIL notification raised kitty: [$(cat "$T/calls")]"; fail=1; fi
# Nell running but slow to answer (the approval deadline): the script must NOT show kitty, Nell offers the console itself
: > "$T/calls"
python3 -I -c 'import socket,sys,time,os
p=sys.argv[1]
s=socket.socket(socket.AF_UNIX); s.bind(p); s.listen(1); open(sys.argv[2],"w").close()
c,_=s.accept(); time.sleep(5)' "$T/slow.sock" "$T/ready" & SRV=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -e "$T/ready" ] && break; sleep 0.1; done
out=$(NELL_KITTEN="$T/kitten" KITTY_LISTEN_ON="unix:$T/kitty-1.sock" NELL_HOOK_DEADLINE=1 bash Sources/Nell/Resources/nell-hook.sh code "$T/slow.sock" < $F/PermissionRequest-Bash.json); rc=$?
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
if [ $rc -eq 0 ] && [ -z "$out" ] && [ ! -s "$T/calls" ]; then echo PASS deadlineWithNellUpDoesNotRaiseKitty; else echo "FAIL deadline raised kitty: [$(cat "$T/calls")]"; fail=1; fi
exit $fail
