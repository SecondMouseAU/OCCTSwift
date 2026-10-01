#!/usr/bin/env bash
#
# #2897: build and run probe.cpp against the pinned OCCT kernel.
#
#   ./run.sh            wasm32-unknown-wasip1, under the pinned wasmkit
#   ./run.sh --native   macOS arm64, against Libraries/OCCT.xcframework
#
# Both are needed to answer the question #2897 asks. The same source on both platforms is what
# distinguishes "wasm traps on something only wasm checks" from "wasm traps on something real".
#
# Prerequisites for the wasm mode, both of which the repo already owns a script for:
#   Scripts/install-wasm-toolchain.sh   -> wasi-sdk and the Swift SDK for WebAssembly
#   Scripts/fetch-occt-wasm.sh          -> Libraries/libOCCT-wasm.a and Libraries/occt-headers-wasm
#
# THE COMPILER AND THE SYSROOT ARE NOT INTERCHANGEABLE. Scripts/cmake/wasi-swift-sdk.cmake compiles
# OCCT with the swift.org toolchain's clang++ against the SWIFT SDK's WASI.sdk, taking only the
# exception-enabled runtime libraries from wasi-sdk. Building a probe with wasi-sdk's own clang++
# and sysroot instead fails on the threading shim's static_assert, because that sysroot's libc++
# has _LIBCPP_HAS_THREADS 1 and the Swift SDK's has 0. A probe built against the other sysroot is
# measuring a different program.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"

if [ "${1:-}" = "--native" ]; then
    # The xcframework can live in the main checkout rather than in a linked worktree, which has a
    # Libraries/ tree of its own and not a symlink to one.
    XC="$REPO/Libraries/OCCT.xcframework/macos-arm64"
    [ -d "$XC" ] || XC="/Users/elb/Projects/OCCTSwift/Libraries/OCCT.xcframework/macos-arm64"
    [ -d "$XC" ] || { echo "no macos-arm64 slice under Libraries/OCCT.xcframework"; exit 2; }
    NATIVE_OUT="${OUT:-$HERE/probe-native}"
    set -x
    clang++ -std=c++17 -w \
        -I"$XC/Headers" \
        -DOCCT_AVAILABLE=1 -DOCCT_NO_DEPRECATED \
        -o "$NATIVE_OUT" "$HERE/probe.cpp" \
        -L"$XC" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++
    set +x
    exec "$NATIVE_OUT"
fi

PINS="$REPO/Scripts/wasm-toolchain-versions.txt"
pin() { sed -n "s/^$1=//p" "$PINS" | head -1; }

SWIFT_WASM_SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
SWIFT_WASM_TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
SWIFT_SDKS_DIR="${SWIFT_SDKS_DIR:-$HOME/.swiftpm/swift-sdks}"
SDK_ROOT="$SWIFT_SDKS_DIR/${SWIFT_WASM_SDK_ID}.artifactbundle/${SWIFT_WASM_SDK_ID}/${SWIFT_WASM_TRIPLE}"

SWIFT_WASI_SYSROOT="${SWIFT_WASI_SYSROOT:-$SDK_ROOT/WASI.sdk}"
WASI_SWIFT_BUILTINS_DIR="${WASI_SWIFT_BUILTINS_DIR:-$SDK_ROOT/swift.xctoolchain/usr/lib/clang/lib/wasip1}"
TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-$(pin SWIFT_TOOLCHAIN_VERSION).xctoolchain/usr/bin}"
WASMKIT="${WASMKIT:-$TOOLCHAIN_BIN/wasmkit}"

ARCH="$(uname -m)"
case "$(uname -s)" in Darwin) OS=macos ;; *) OS=linux ;; esac
WASI_SDK_PREFIX="${WASI_SDK_PREFIX:-$REPO/Libraries/wasi-sdk-$(pin WASI_SDK_VERSION)-${ARCH}-${OS}}"
if [ ! -d "$WASI_SDK_PREFIX" ]; then
    WASI_SDK_PREFIX="/Users/elb/Projects/OCCTSwift/Libraries/wasi-sdk-$(pin WASI_SDK_VERSION)-${ARCH}-${OS}"
fi
WASI_SDK_EH_LIBDIR="$WASI_SDK_PREFIX/share/wasi-sysroot/lib/wasm32-wasip1/eh"

LIB_DIR="${OCCT_WASM_LIB_DIR:-$REPO/Libraries}"

[ -x "$TOOLCHAIN_BIN/clang++" ] || { echo "no swift.org clang++ at $TOOLCHAIN_BIN"; exit 2; }
[ -f "$SWIFT_WASI_SYSROOT/include/c++/v1/__config_site" ] || { echo "no Swift WASI sysroot at $SWIFT_WASI_SYSROOT"; exit 2; }
[ -f "$WASI_SDK_EH_LIBDIR/libc++abi.a" ] || { echo "no exception-enabled runtime at $WASI_SDK_EH_LIBDIR"; exit 2; }
[ -f "$LIB_DIR/libOCCT-wasm.a" ] || { echo "no $LIB_DIR/libOCCT-wasm.a: run Scripts/fetch-occt-wasm.sh"; exit 2; }
[ -x "$WASMKIT" ] || { echo "no wasmkit at $WASMKIT (set WASMKIT=)"; exit 2; }

OUT="${OUT:-$HERE/probe.wasm}"

# THE wasm32 compiler-rt BUILTINS LIVE IN THE SWIFT SDK BUNDLE, NOT IN THE TOOLCHAIN. The swift.org
# toolchain's clang resource directory has an `include` and a darwin `lib`, and asks the linker for
# `lib/wasm32-unknown-wasip1/libclang_rt.builtins.a`, which is not there; the Swift SDK ships that
# archive at `swift.xctoolchain/usr/lib/clang/lib/wasip1/libclang_rt.builtins-wasm32.a` and ships no
# `include`. CMake gets both because Scripts/cmake/wasi-swift-sdk.cmake adds the SDK directory as a
# `link_directories`, which only works because CMake drives the link with its own library list. A
# single clang++ invocation needs one resource directory that has both halves, so this composes one
# out of symlinks rather than copying 80 MB or editing either install.
RESOURCE_DIR="${RESOURCE_DIR:-$(mktemp -d -t occt2897-rd)}"
TOOLCHAIN_RESOURCE_DIR="$("$TOOLCHAIN_BIN/clang++" -print-resource-dir)"
mkdir -p "$RESOURCE_DIR/lib/wasm32-unknown-wasip1"
ln -sfn "$TOOLCHAIN_RESOURCE_DIR/include" "$RESOURCE_DIR/include"
ln -sfn "$WASI_SWIFT_BUILTINS_DIR/libclang_rt.builtins-wasm32.a" \
    "$RESOURCE_DIR/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a"

set -x
"$TOOLCHAIN_BIN/clang++" \
    --target="$SWIFT_WASM_TRIPLE" \
    --sysroot "$SWIFT_WASI_SYSROOT" \
    -resource-dir "$RESOURCE_DIR" \
    -std=c++17 \
    -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false -mllvm -wasm-enable-sjlj \
    -include "$REPO/Scripts/wasm-shims/wasi-std-threading.hpp" \
    -I "$LIB_DIR/occt-headers-wasm" \
    -DOCCT_AVAILABLE=1 -DOCCT_NO_DEPRECATED \
    -o "$OUT" "$HERE/probe.cpp" \
    -L"$WASI_SDK_EH_LIBDIR" \
    -L"$WASI_SWIFT_BUILTINS_DIR" \
    -L"$LIB_DIR" \
    -lOCCT-wasm -lc++ -lc++abi -lunwind -lsetjmp -lwasi-emulated-getpid
set +x

exec "$WASMKIT" run --dir /tmp --env TMPDIR=/tmp "$OUT"
