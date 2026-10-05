#!/bin/bash
#
# #2928 question 1: is `Int(Int32.max) + 1` a COMPILE error on wasm32, or a run-time trap?
#
# Five spellings, one per -D so one diagnostic cannot mask another, each compiled for wasm32 (where
# `Int` is 32 bits) and for the host (where it is 64). A case that compiles for wasm32 prints
# nothing after its header.
set -u

cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=wasm-swiftc.sh
source ./wasm-swiftc.sh

for c in CASE1 CASE2 CASE3 CASE4 CASE5; do
    echo "===== $c (wasm32, Int is 32 bits)"
    "${WASM_SWIFTC[@]}" -D "$c" -emit-sil overflow-probe.swift -o /dev/null 2>&1 | head -4
    echo "===== $c (host, Int is 64 bits)"
    "${HOST_SWIFTC[@]}" -D "$c" -emit-sil overflow-probe.swift -o /dev/null 2>&1 | head -4
done
