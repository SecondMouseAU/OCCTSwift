#!/usr/bin/env bash
# Reproducer for #2179: wasi-osd-chronometer.patch could not compile in either configuration.
#
# Runs four measurements, each in both configurations (bare, and with the emulation define the
# sysroot's #error asks for):
#
#   1. the reduced probe as the patch left the site BEFORE the fix   -> must fail
#   2. the reduced probe as the patch leaves it AFTER the fix        -> must pass
#   3. the real OSD_Chronometer.cxx with the BEFORE patch applied    -> must fail
#   4. the real OSD_Chronometer.cxx with the live patch applied      -> must pass
#
# 3 and 4 need the patched OCCT tree (V8_0_1 plus Scripts/patches/), which a linked worktree does
# not have. Point OCCT_SRC at the main checkout's, or skip them. Nothing here mutates that tree:
# the file is copied out and patched in a temp directory.
#
# Usage: Scripts/repro/2179/run.sh [OCCT_SRC]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"

CXX="${CXX:-/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/clang++}"
SDK="${WASI_SDK:-$HOME/.swiftpm/swift-sdks/swift-6.4.0-RELEASE_wasm.artifactbundle/swift-6.4.0-RELEASE_wasm/wasm32-unknown-wasip1/WASI.sdk}"
OCCT_SRC="${1:-${OCCT_SRC:-$REPO/Libraries/occt-src}}"
OCCT_INC="${OCCT_INC:-$(dirname "$OCCT_SRC")/occt-install-macos/include/opencascade}"
REL="src/FoundationClasses/TKernel/OSD/OSD_Chronometer.cxx"

[ -x "$CXX" ] || { echo "no clang++ at $CXX (set CXX)"; exit 2; }
[ -d "$SDK" ] || { echo "no WASI sysroot at $SDK (set WASI_SDK)"; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0

# $1 expectation (pass|fail), $2 label, $3.. compiler args
check() {
  local want="$1" label="$2"; shift 2
  local out; out="$("$@" 2>&1)"; local got=$?
  local verdict
  if [ "$want" = pass ]; then [ $got -eq 0 ] && verdict=OK || verdict=UNEXPECTED
  else [ $got -ne 0 ] && verdict=OK || verdict=UNEXPECTED; fi
  [ "$verdict" = OK ] || rc=1
  printf '%-58s want=%-4s exit=%-3s %s\n' "$label" "$want" "$got" "$verdict"
  [ -n "$out" ] && printf '%s\n' "$out" | sed -n '1,4p' | sed 's/^/      | /'
  return 0
}

wasi() { "$CXX" --target=wasm32-unknown-wasip1 --sysroot="$SDK" -std=c++17 -fsyntax-only "$@"; }

echo "=== 1/2. reduced probes ==="
check fail "probe-before, bare"                     wasi "$HERE/probe-before.cxx"
check fail "probe-before, -D_WASI_EMULATED_PROCESS_CLOCKS" wasi -D_WASI_EMULATED_PROCESS_CLOCKS "$HERE/probe-before.cxx"
check pass "probe-after,  bare"                     wasi "$HERE/probe-after.cxx"
check pass "probe-after,  -D_WASI_EMULATED_PROCESS_CLOCKS" wasi -D_WASI_EMULATED_PROCESS_CLOCKS "$HERE/probe-after.cxx"

if [ ! -f "$OCCT_SRC/$REL" ]; then
  echo
  echo "=== 3/4. SKIPPED: no patched OCCT tree at $OCCT_SRC ==="
  echo "    pass the main checkout's Libraries/occt-src as \$1 to run them"
  exit $rc
fi

if [ ! -f "$OCCT_INC/OSD_Chronometer.hxx" ]; then
  echo
  echo "=== 3/4. ABORT: no OCCT headers at $OCCT_INC ==="
  echo "    without them every compile below fails on the first #include, which would score the"
  echo "    two 'must fail' rows green for a reason that has nothing to do with this patch."
  exit 2
fi

echo
echo "=== 3/4. the real OSD_Chronometer.cxx, patched in $TMP ==="
mkdir -p "$TMP/$(dirname "$REL")"
cp "$OCCT_SRC/$REL" "$TMP/$REL"
git -C "$TMP" init -q . && git -C "$TMP" apply "$HERE/wasi-osd-chronometer.before.patch" \
  || { echo "could not apply the BEFORE patch"; exit 2; }
cp "$TMP/$REL" "$TMP/before.cxx"
git -C "$TMP" apply --reverse "$HERE/wasi-osd-chronometer.before.patch"
git -C "$TMP" apply "$REPO/Scripts/patches-wasi/wasi-osd-chronometer.patch" \
  || { echo "could not apply the CURRENT patch"; exit 2; }
cp "$TMP/$REL" "$TMP/after.cxx"

check fail "before.cxx, bare"                       wasi -I"$OCCT_INC" "$TMP/before.cxx"
check fail "before.cxx, -D_WASI_EMULATED_PROCESS_CLOCKS" wasi -D_WASI_EMULATED_PROCESS_CLOCKS -I"$OCCT_INC" "$TMP/before.cxx"
check pass "after.cxx,  bare"                       wasi -I"$OCCT_INC" "$TMP/after.cxx"
check pass "after.cxx,  -D_WASI_EMULATED_PROCESS_CLOCKS" wasi -D_WASI_EMULATED_PROCESS_CLOCKS -I"$OCCT_INC" "$TMP/after.cxx"

if [ -d "$OCCT_INC" ] && command -v xcrun >/dev/null; then
  echo
  echo "=== native macOS, to show the guards change nothing off WASI ==="
  check pass "after.cxx,  native arm64"             xcrun clang++ -std=c++17 -fsyntax-only -I"$OCCT_INC" "$TMP/after.cxx"
fi

exit $rc
