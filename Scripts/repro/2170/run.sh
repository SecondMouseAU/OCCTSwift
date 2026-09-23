#!/bin/bash
#
# #2170: build and run probe.cxx against the pinned wasm toolchain, with and without the shim.
#
#   ./run.sh              both cases
#   ./run.sh --shim       the WITH case only, and run the module
#   ./run.sh --no-shim    the WITHOUT case only, which is expected to fail
#
# Reads nothing from the build: it uses the swift.org toolchain and the Swift SDK sysroot named in
# Scripts/wasm-toolchain-versions.txt directly, so it works in a tree that has never built OCCT.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIM="$SCRIPT_DIR/../../wasm-shims/wasi-std-threading.hpp"

TOOLCHAIN="${SWIFT_TOOLCHAIN:-/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain}"
CLANG="$TOOLCHAIN/usr/bin/clang++"
WASMKIT="$TOOLCHAIN/usr/bin/wasmkit"
SDK="${SWIFT_WASM_SYSROOT:-$HOME/.swiftpm/swift-sdks/swift-6.4.0-RELEASE_wasm.artifactbundle/swift-6.4.0-RELEASE_wasm/wasm32-unknown-wasip1/WASI.sdk}"
BUILTINS="${SWIFT_WASM_BUILTINS:-$HOME/.swiftpm/swift-sdks/swift-6.4.0-RELEASE_wasm.artifactbundle/swift-6.4.0-RELEASE_wasm/wasm32-unknown-wasip1/swift.xctoolchain/usr/lib/clang/lib/wasip1/libclang_rt.builtins-wasm32.a}"

for path in "$CLANG" "$SDK" "$BUILTINS"; do
    if [ ! -e "$path" ]; then
        echo "ERROR: missing '$path'." >&2
        echo "       Install the pins in Scripts/wasm-toolchain-versions.txt, or override" >&2
        echo "       SWIFT_TOOLCHAIN / SWIFT_WASM_SYSROOT / SWIFT_WASM_BUILTINS." >&2
        exit 1
    fi
done

WORK="$(mktemp -d -t occt-2170)"
trap 'rm -rf "$WORK"' EXIT

# The swift.org toolchain's own resource directory carries the clang builtin HEADERS but no wasm32
# builtins ARCHIVE, and the Swift SDK carries the archive but no headers. Neither is usable alone,
# so splice them: this is the "-resource-dir pointing at the bundle's clang resources" that
# Scripts/repro/2169/README.md describes, assembled rather than assumed.
mkdir -p "$WORK/res/lib/wasm32-unknown-wasip1"
ln -s "$("$CLANG" -print-resource-dir)/include" "$WORK/res/include"
ln -s "$BUILTINS" "$WORK/res/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a"

COMMON=(--target=wasm32-unknown-wasip1 --sysroot="$SDK" -std=c++17)

run_without() {
    echo "=== WITHOUT the shim: expected to fail ==="
    local out
    out="$("$CLANG" "${COMMON[@]}" -fsyntax-only -ferror-limit=0 "$SCRIPT_DIR/probe.cxx" 2>&1)"
    local errors
    errors="$(printf '%s\n' "$out" | grep -c 'error:')"
    echo "errors: $errors"
    printf '%s\n' "$out" | grep 'error:' | sed 's/.*error: //' | sort | uniq -c | sort -rn
    if [ "$errors" -eq 0 ]; then
        echo "UNEXPECTED: the probe compiled with no shim. This libc++ is not the pinned one." >&2
        return 1
    fi
    return 0
}

run_with() {
    echo "=== WITH the shim ==="
    if ! "$CLANG" "${COMMON[@]}" -fsyntax-only -ferror-limit=0 -include "$SHIM" "$SCRIPT_DIR/probe.cxx"; then
        echo "FAIL: the probe does not compile with the shim." >&2
        return 1
    fi
    echo "errors: 0"
    if ! "$CLANG" "${COMMON[@]}" -resource-dir="$WORK/res" -include "$SHIM" \
            "$SCRIPT_DIR/probe.cxx" -o "$WORK/probe.wasm"; then
        echo "FAIL: the probe does not link." >&2
        return 1
    fi
    # Running matters and compiling does not settle it. PR #2076's spinlock recursive_mutex
    # COMPILES; what it does is hang at the second acquisition. Only this step sees that.
    if ! "$WASMKIT" run "$WORK/probe.wasm"; then
        echo "FAIL: the probe ran and did not return 0." >&2
        return 1
    fi
    echo "ran: exit 0"
    return 0
}

status=0
case "${1:-}" in
    --shim)    run_with    || status=1 ;;
    --no-shim) run_without || status=1 ;;
    "")        run_without || status=1; echo; run_with || status=1 ;;
    *)         echo "usage: $0 [--shim|--no-shim]" >&2; exit 2 ;;
esac
exit "$status"
