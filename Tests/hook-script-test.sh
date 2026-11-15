#!/bin/bash
# Tests hooks/nell-hook.sh: with Nell unreachable non-blocking events stay silent and fast and approvals raise kitty;
# with Nell answering it prints her exact decision. Every run has an empty PATH and no jq (missing before macOS 15).
# Then nell-status.sh: Nell's line, or your own status line's output with usage still posted to Nell.
set -u
cd "$(dirname "$0")/.."
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
printf '#!/bin/bash\necho "$@" >> %q\n' "$T/calls" > "$T/kitten"; chmod +x "$T/kitten"
F=Tests/NellCoreTests/Fixtures
fail=0
NOJQ='(version 1)(allow default)(deny process-exec (literal "/usr/bin/jq"))'
PROFILE=$NOJQ
# hook <socket> <event> [VAR=value...] < body: the script as Claude runs it, as on macOS 14 unless PROFILE allows jq.
# An empty <event> is the old two-argument command, kept by Claude sessions started before the upgrade.
hook() { local sock=$1 event=$2; shift 2
  env -i PATH=/var/empty NELL_KITTEN="$T/kitten" KITTY_LISTEN_ON="unix:$T/kitty-1.sock" "$@" \
    /usr/bin/sandbox-exec -p "$PROFILE" /bin/bash Sources/Nell/Resources/nell-hook.sh code "$sock" ${event:+"$event"}; }
run() { hook "$T/nope.sock" "$2" < "$1"; }

start=$(date +%s); out=$(run $F/PreToolUse-Bash.json PreToolUse); rc=$?; secs=$(( $(date +%s) - start ))
if [ $rc -eq 0 ] && [ -z "$out" ] && [ $secs -le 1 ] && [ ! -e "$T/calls" ]; then echo PASS preToolUseSilentWhenNellDown; else echo "FAIL preToolUse rc=$rc out=[$out] secs=$secs"; fail=1; fi

out=$(run $F/PermissionRequest-Bash.json PermissionRequest); rc=$?
if [ $rc -eq 0 ] && [ -z "$out" ] && grep -q "resize-os-window --match var:nell_mode=code --action show" "$T/calls" && grep -q "focus-window --match var:nell_mode=code" "$T/calls"; then echo PASS permissionRaisesKittyWhenNellDown; else echo "FAIL permission rc=$rc out=[$out] calls=[$(cat "$T/calls" 2>/dev/null)]"; fail=1; fi
out=$(run $F/Notification-idle_prompt.json Notification); rc=$?
if [ $rc -eq 0 ] && [ -z "$out" ] && ! grep -q "idle" "$T/calls" 2>/dev/null && [ "$(wc -l < "$T/calls")" -eq 2 ]; then echo PASS notificationDoesNotRaiseKitty; else echo "FAIL notification raised kitty: [$(cat "$T/calls")]"; fail=1; fi
# Nell running but slow to answer (the approval deadline): the script must NOT show kitty, Nell offers the console itself
: > "$T/calls"
python3 -I -c 'import socket,sys,time,os
p=sys.argv[1]
s=socket.socket(socket.AF_UNIX); s.bind(p); s.listen(1); open(sys.argv[2],"w").close()
c,_=s.accept(); time.sleep(5)' "$T/slow.sock" "$T/ready" & SRV=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -e "$T/ready" ] && break; sleep 0.1; done
out=$(hook "$T/slow.sock" PermissionRequest NELL_HOOK_DEADLINE=1 < $F/PermissionRequest-Bash.json); rc=$?
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
if [ $rc -eq 0 ] && [ -z "$out" ] && [ ! -s "$T/calls" ]; then echo PASS deadlineWithNellUpDoesNotRaiseKitty; else echo "FAIL deadline raised kitty: [$(cat "$T/calls")]"; fail=1; fi

# Nell answers <reply>: a fake server reads one request, keeps its body in $T/posted and replies with <reply> as the body
answers() { rm -f "$T/fake.sock" "$T/fake-ready" "$T/posted"
  python3 -I -c 'import socket,sys
s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1); open(sys.argv[2],"w").close()
c,_=s.accept(); d=b""
while b"\r\n\r\n" not in d: d+=c.recv(65536)
h,_,b=d.partition(b"\r\n\r\n"); n=int([l.split(b":")[1] for l in h.split(b"\r\n") if l.lower().startswith(b"content-length:")][0])
while len(b)<n: b+=c.recv(65536)
open(sys.argv[4],"wb").write(b)
r=sys.argv[3].encode(); c.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n"%len(r)+r); c.close()' "$T/fake.sock" "$T/fake-ready" "$1" "$T/posted" & SRV=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -e "$T/fake-ready" ] && break; sleep 0.1; done; }
ALLOW='{"hookSpecificOutput":{"decision":{"behavior":"allow"},"hookEventName":"PermissionRequest"}}'
DENY='{"hookSpecificOutput":{"decision":{"behavior":"deny","message":"Denied from Nell"},"hookEventName":"PermissionRequest"}}'
for want in "$ALLOW" "$DENY"; do
  answers "$want"; out=$(hook "$T/fake.sock" PermissionRequest < $F/PermissionRequest-Bash.json); rc=$?; kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
  if [ $rc -eq 0 ] && [ "$out" = "$want" ]; then echo "PASS printsDecisionWithoutJq $out"; else echo "FAIL decision rc=$rc out=[$out] want=[$want]"; fail=1; fi
done
answers "x"; out=$(hook "$T/fake.sock" Stop < $F/Stop.json); rc=$?; kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
if [ $rc -eq 0 ] && [ -z "$out" ]; then echo PASS nonApprovalPrintsNothing; else echo "FAIL Stop printed rc=$rc out=[$out]"; fail=1; fi

# The old two-argument command: with jq the event still comes from stdin; without it the script just degrades
if [ -x /usr/bin/jq ]; then
  PROFILE='(version 1)(allow default)'
  answers "$ALLOW"; out=$(hook "$T/fake.sock" "" < $F/PermissionRequest-Bash.json); rc=$?; kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
  if [ $rc -eq 0 ] && [ "$out" = "$ALLOW" ]; then echo PASS oldTwoArgCommandWithJqPrintsDecision; else echo "FAIL old command with jq rc=$rc out=[$out]"; fail=1; fi
  PROFILE=$NOJQ
else echo "SKIP oldTwoArgCommandWithJqPrintsDecision (no /usr/bin/jq)"; fi
answers "$ALLOW"; out=$(hook "$T/fake.sock" "" < $F/PermissionRequest-Bash.json); rc=$?; kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
if [ $rc -eq 0 ] && [ -z "$out" ]; then echo PASS oldTwoArgCommandWithoutJqExitsQuietly; else echo "FAIL old command without jq rc=$rc out=[$out]"; fail=1; fi
# nell-status.sh <socket> [<your status command>], as Claude runs it (stdin: its status JSON)
status() { env -i PATH=/var/empty /bin/bash Sources/Nell/Resources/nell-status.sh "$@" < $F/statusline.json; }
answers "NELL LINE"; out=$(status "$T/fake.sock"); rc=$?; kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
if [ $rc -eq 0 ] && [ "$out" = "NELL LINE" ]; then echo PASS statusPrintsNellsLineWithoutYours; else echo "FAIL status without yours rc=$rc out=[$out]"; fail=1; fi
YOURS="/bin/cat > $(printf %q "$T/yours-stdin"); echo 'YOUR LINE'"
answers "NELL LINE"; out=$(status "$T/fake.sock" "$YOURS"); rc=$?; kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
if [ $rc -eq 0 ] && [ "$out" = "YOUR LINE" ] && cmp -s "$T/yours-stdin" $F/statusline.json && cmp -s "$T/posted" $F/statusline.json
then echo PASS statusRunsYoursWithTheSameStdinAndStillPosts; else echo "FAIL status with yours rc=$rc out=[$out] posted=$(cmp "$T/posted" $F/statusline.json 2>&1) stdin=$(cmp "$T/yours-stdin" $F/statusline.json 2>&1)"; fail=1; fi
rm -f "$T/yours-stdin"; start=$(date +%s); out=$(status "$T/nope.sock" "$YOURS"); rc=$?; secs=$(( $(date +%s) - start ))
if [ $rc -eq 0 ] && [ "$out" = "YOUR LINE" ] && cmp -s "$T/yours-stdin" $F/statusline.json && [ $secs -le 1 ]
then echo PASS statusRunsYoursWhenNellIsDown; else echo "FAIL status with yours, Nell down rc=$rc out=[$out] secs=$secs"; fail=1; fi
exit $fail
