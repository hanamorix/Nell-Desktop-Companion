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
exit $fail
