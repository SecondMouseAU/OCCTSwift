#!/usr/bin/env bash
# #2171: does the bridge's error contract survive on wasm32-unknown-wasip1?
#
# Builds and runs three things and prints what each said:
#   standalone/  eight cases putting OCCT's exception shape through the wasm unwinder
#   standalone/  the same package's second executable, raising with nothing catching
#   size/        the same small program with and without exceptions, for the size cost
#
# Exits non-zero if any of the eight cases returns the wrong sentinel. The uncaught run is
# EXPECTED to exit non-zero; that is the measurement, not a failure.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
PINS="$REPO_ROOT/Scripts/wasm-toolchain-versions.txt"

# --- the pinned toolchain ------------------------------------------------------------------
# The pins file arrives with #2169. Until it lands on this branch, the values below are the ones
# that PR measured, and this script says so rather than pretending it read them.
if [ -f "$PINS" ]; then
  pin() { grep "^$1=" "$PINS" | head -1 | cut -d= -f2-; }
  SWIFT_TOOLCHAIN_VERSION="$(pin SWIFT_TOOLCHAIN_VERSION)"
  SWIFT_WASM_SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
  SWIFT_WASM_TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
  WASI_SDK_VERSION="$(pin WASI_SDK_VERSION)"
  EH_FLAGS="$(pin WASM_CXX_EH_FLAGS)"
  echo ">>> pins read from Scripts/wasm-toolchain-versions.txt"
else
  SWIFT_TOOLCHAIN_VERSION="6.4.0-RELEASE"
  SWIFT_WASM_SDK_ID="swift-6.4.0-RELEASE_wasm"
  SWIFT_WASM_TRIPLE="wasm32-unknown-wasip1"
  WASI_SDK_VERSION="34.0"
  EH_FLAGS="-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false"
  echo ">>> Scripts/wasm-toolchain-versions.txt is not on this branch yet (it arrives with #2169)."
  echo ">>> Using the values that PR measured. Delete this branch of the script once it lands."
fi

# The swift.org toolchain, not Xcode's, which has no wasm-ld. See #2169.
SWIFT_BIN="${SWIFT_BIN:-/Library/Developer/Toolchains/swift-$SWIFT_TOOLCHAIN_VERSION.xctoolchain/usr/bin}"
if [ ! -x "$SWIFT_BIN/swift" ]; then
  echo "error: no swift.org toolchain at $SWIFT_BIN" >&2
  echo "       install it, or set SWIFT_BIN to one that carries wasm-ld and wasmkit." >&2
  exit 1
fi
export PATH="$SWIFT_BIN:$PATH"
export TOOLCHAINS=swift

if [ -z "${WASI_SDK_PREFIX:-}" ]; then
  for candidate in "$REPO_ROOT"/Libraries/wasi-sdk-"$WASI_SDK_VERSION"-*; do
    [ -d "$candidate" ] && WASI_SDK_PREFIX="$candidate" && break
  done
fi
if [ -z "${WASI_SDK_PREFIX:-}" ] || [ ! -d "$WASI_SDK_PREFIX" ]; then
  echo "error: no wasi-sdk $WASI_SDK_VERSION found. Set WASI_SDK_PREFIX, or run" >&2
  echo "       Scripts/install-wasm-toolchain.sh once #2169 has landed." >&2
  exit 1
fi
export WASI_SDK_PREFIX
export PROBE_CXX_EH_FLAGS="$EH_FLAGS"

echo ">>> Swift toolchain : $SWIFT_BIN"
echo ">>> Swift SDK       : $SWIFT_WASM_SDK_ID ($SWIFT_WASM_TRIPLE)"
echo ">>> wasi-sdk        : $WASI_SDK_PREFIX"
echo ">>> EH flags        : $EH_FLAGS"
echo

# --- the seven cases -----------------------------------------------------------------------
# --manifest-cache none is not caution. SwiftPM keys that cache on the CONTENT of Package.swift,
# so a change to PROBE_CXX_EH_FLAGS does not reach the next build without it, and `touch` does not
# help because touching does not change the hash. See README.md.
cd "$HERE/standalone"
echo ">>> Building the probe for $SWIFT_WASM_TRIPLE..."
swift build --manifest-cache none --swift-sdk "$SWIFT_WASM_SDK_ID" --triple "$SWIFT_WASM_TRIPLE"
PRODUCTS=".build/out/Products/Debug-webassembly-wasm32"

echo
echo ">>> probe.wasm"
wasmkit run "$PRODUCTS/probe.wasm"

echo
echo ">>> probe-uncaught.wasm (a non-zero exit here IS the measurement)"
set +e
wasmkit run "$PRODUCTS/probe-uncaught.wasm"
echo "    exit status: $?"
set -e

# --- the size cost -------------------------------------------------------------------------
echo
echo ">>> Size of the same program with and without exceptions"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for opt in O0 Os; do
  "$WASI_SDK_PREFIX/bin/clang++" --target="$SWIFT_WASM_TRIPLE" "-$opt" \
    -fno-exceptions -DPROBE_NO_EXCEPTIONS "$HERE/size/size-probe.cpp" -o "$WORK/noeh-$opt.wasm"
  # shellcheck disable=SC2086
  "$WASI_SDK_PREFIX/bin/clang++" --target="$SWIFT_WASM_TRIPLE" "-$opt" $EH_FLAGS \
    "$HERE/size/size-probe.cpp" -lunwind -o "$WORK/eh-$opt.wasm"
  noeh=$(wc -c < "$WORK/noeh-$opt.wasm")
  eh=$(wc -c < "$WORK/eh-$opt.wasm")
  printf '    -%-3s  no exceptions %9d  exceptions %9d  delta %+9d\n' \
    "$opt" "$noeh" "$eh" "$((eh - noeh))"
done
wasmkit run "$WORK/eh-Os.wasm"

echo
echo "Done. See README.md for what each line means."
