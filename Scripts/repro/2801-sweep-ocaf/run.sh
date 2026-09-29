#!/usr/bin/env bash
# #2801 sweep: two out-of-line index guards the pinned kernel compiles out.
# Every mode runs in its own process, because the result of half of them is a fault.
#
# Point OCCT_XCFRAMEWORK at the PINNED asset, not at Libraries/OCCT.xcframework, which in a
# developer checkout is often a locally built kernel:
#   gh release download v4.0.0-kernel.2 --repo SecondMouseAU/OCCTSwift -p OCCT.xcframework.zip
#   swift package compute-checksum OCCT.xcframework.zip   # must be 18b181cc27778520fa...
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
K="${OCCT_XCFRAMEWORK:-$HERE/../../../Libraries/OCCT.xcframework}"
BIN="${TMPDIR:-/tmp}/probe-2801-sweep-ocaf"

set -x
clang++ -std=c++17 -ObjC++ -w \
  -I"$K/macos-arm64/Headers" \
  -L"$K/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  "$HERE/probe.mm" -o "$BIN" || exit 1
set +x

for m in 0 1 2 3 4 5 10 11 12 13 20 21 22; do
  echo "----- mode $m"
  "$BIN" "$m" 2>&1
  echo "exit=$?"
done
