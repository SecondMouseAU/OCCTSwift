#!/bin/bash
#
# Guard (#2757): the wasm kernel archive must hold no lowered setjmp.
#
#   Scripts/check-wasm-archive-no-setjmp.sh [archive]      # default Libraries/libOCCT-wasm.a
#
# A function that carries both a lowered `setjmp` and wasm exceptions can come out as an INVALID
# module (an `br_table` whose targets disagree on their label types; reduction in
# Scripts/repro/2757/). Scripts/build-occt-wasm.sh avoids it with -UOCC_CONVERT_SIGNALS, so no OCCT
# object calls __wasm_setjmp, __wasm_longjmp or __c_longjmp. Nothing else notices that going
# wrong: a kernel rebuilt without the -U, or a new dependency that really uses setjmp, links fine
# and only dies at the first OCCT call at run time.
#
# Reads the symbol table with llvm-nm: from $LLVM_NM, else the wasi-sdk's, else the pinned Swift
# toolchain's. Host `nm` lists an undefined wasm symbol as though it were defined, so it is never
# used. Exit 0 clean, 1 if any member references a lowered setjmp, 2 on a setup error.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ARCHIVE="${1:-$REPO_DIR/Libraries/libOCCT-wasm.a}"
PINS="$SCRIPT_DIR/wasm-toolchain-versions.txt"
pin() { sed -n "s/^$1=//p" "$PINS" | head -1; }

NM="${LLVM_NM:-}"
if [ -z "$NM" ]; then
    for c in "${WASI_SDK_PREFIX:-}/bin/llvm-nm" \
             "/Library/Developer/Toolchains/swift-$(pin SWIFT_TOOLCHAIN_VERSION).xctoolchain/usr/bin/llvm-nm"; do
        [ -x "$c" ] && { NM="$c"; break; }
    done
fi
[ -n "$NM" ] && [ -x "$NM" ] || { echo "ERROR: no llvm-nm (set LLVM_NM or WASI_SDK_PREFIX)" >&2; exit 2; }
[ -f "$ARCHIVE" ] || { echo "ERROR: no archive at $ARCHIVE" >&2; exit 2; }

# llvm-nm prints "archive:member:" headers with -A; --undefined-only plus the defined weak
# `__c_longjmp` (a tag the lowering emits) cover both halves. Match symbol names, not substrings of
# other names, and count the members that hold one.
HITS="$("$NM" -A "$ARCHIVE" 2>/dev/null | grep -E '[ :](__wasm_setjmp|__wasm_setjmp_test|__wasm_longjmp|__c_longjmp)$' || true)"
MEMBERS="$("$NM" "$ARCHIVE" 2>/dev/null | grep -c ':$' || true)"
if [ -n "$HITS" ]; then
    echo "FAIL: $ARCHIVE references a lowered setjmp ($(printf '%s\n' "$HITS" | wc -l | tr -d ' ') symbols):" >&2
    printf '%s\n' "$HITS" | head -10 | sed 's/^/  /' >&2
    echo "See Scripts/repro/2757/README.md: setjmp lowering plus wasm exceptions can emit an invalid br_table." >&2
    exit 1
fi
echo "OK: no __wasm_setjmp / __wasm_longjmp / __c_longjmp reference in $ARCHIVE ($MEMBERS members scanned)"
