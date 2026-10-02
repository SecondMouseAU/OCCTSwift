#!/bin/bash
#
# Resolve the pinned swift.org toolchain and the installed Swift SDK for WebAssembly, and print the
# `swiftc` invocation prefix that type-checks a single file for wasm32-unknown-wasip1.
#
# Sourced by run-overflow.sh and run-prims.sh. Both of those ask a question about the TARGET's
# integer width and module availability, so neither needs OCCT, the bridge, a toolset or a link
# step: one `-emit-sil` against the SDK's own sysroot answers it in under a second.
#
# Everything comes from Scripts/wasm-toolchain-versions.txt, the same pins every other wasm script
# reads, so a toolchain bump cannot leave a stale literal here.
#
# `set -e` is deliberately NOT set, and is not an omission: both callers EXPECT some compilations to
# fail, that being the measurement, and an inherited `errexit` ended run-prims.sh after its first
# FAILS line with no further output and an exit status that read as a broken script.
set -u

REPRO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$REPRO_DIR/../../.." && pwd)"
PINS="$REPO_DIR/Scripts/wasm-toolchain-versions.txt"
pin() { sed -n "s/^$1=//p" "$PINS" | head -1; }

TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-$(pin SWIFT_TOOLCHAIN_VERSION).xctoolchain/usr/bin}"
if [ ! -x "$TOOLCHAIN_BIN/swiftc" ]; then
    # The Linux/CI shape: the swift.org toolchain IS the image, so it is simply on PATH.
    TOOLCHAIN_BIN="$(dirname "$(command -v swiftc)")"
fi

SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
SDK_BUNDLE="${SWIFT_WASM_SDK_BUNDLE:-$HOME/.swiftpm/swift-sdks/$SDK_ID.artifactbundle/$SDK_ID/$TRIPLE}"
if [ ! -d "$SDK_BUNDLE" ]; then
    echo "no Swift SDK for WebAssembly at $SDK_BUNDLE" >&2
    echo "install it with Scripts/install-wasm-toolchain.sh, or set SWIFT_WASM_SDK_BUNDLE" >&2
    exit 2
fi

# `-resource-dir` is NOT optional and its absence does not look like a missing flag: without it
# swiftc reports `error: unable to load standard library for target 'wasm32-unknown-wasip1'`, which
# reads as a broken SDK. The path is the `swiftResourcesPath` in the bundle's own swift-sdk.json.
WASM_SWIFTC=(
    "$TOOLCHAIN_BIN/swiftc"
    -swift-version 6
    -target "$TRIPLE"
    -sdk "$SDK_BUNDLE/WASI.sdk"
    -resource-dir "$SDK_BUNDLE/swift.xctoolchain/usr/lib/swift_static"
)
HOST_SWIFTC=("$TOOLCHAIN_BIN/swiftc" -swift-version 6)
