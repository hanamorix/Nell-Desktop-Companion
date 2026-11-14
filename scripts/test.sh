#!/bin/bash
# shortcut: CLT-only toolchain drops the Swift Testing macro plugin on incremental builds; load it explicitly. Drop this once Xcode is installed.
set -euo pipefail
cd "$(dirname "$0")/.."
exec swift test -Xswiftc -load-plugin-library -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib "$@"
