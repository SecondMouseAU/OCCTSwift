#!/bin/bash
#
# #2928 question 3: which of the primitives `Package.swift` named as the reason for the five
# whole-target wasm exclusions actually fail to compile for wasm32-unknown-wasip1?
#
# One -D per primitive, so one failure cannot mask another. Measured 2026-10-02 against the pinned
# toolchain: NSLock, ProcessInfo, withTaskGroup and Thread COMPILE; DispatchQueue, DispatchGroup,
# DispatchSemaphore and autoreleasepool do not.
set -u

cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=wasm-swiftc.sh
source ./wasm-swiftc.sh

for c in P_NSLOCK P_DISPATCHQUEUE P_DISPATCHGROUP P_DISPATCHSEMAPHORE P_PROCESSINFO \
    P_AUTORELEASEPOOL P_TASKGROUP P_THREAD; do
    out="$("${WASM_SWIFTC[@]}" -D "$c" -emit-sil prims.swift -o /dev/null 2>&1 | head -3)"
    if [ -z "$out" ]; then
        echo "COMPILES  $c"
    else
        echo "FAILS     $c"
        echo "$out" | sed 's/^/            /'
    fi
done
