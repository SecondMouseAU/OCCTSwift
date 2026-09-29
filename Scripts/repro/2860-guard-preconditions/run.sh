#!/usr/bin/env bash
# #2860 / #2857: the preconditions the bridge guards are built on.
#
# Point OCCT_XCFRAMEWORK at the PINNED asset, not at Libraries/OCCT.xcframework, which in a
# developer checkout is often a locally built kernel one repin behind:
#   gh release download v4.0.0-kernel.2 --repo SecondMouseAU/OCCTSwift -p OCCT.xcframework.zip
#   swift package compute-checksum OCCT.xcframework.zip   # must be 18b181cc27778520fa...
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
K="${OCCT_XCFRAMEWORK:-$HERE/../../../Libraries/OCCT.xcframework}"
BIN="${TMPDIR:-/tmp}/probe-2860-guard-preconditions"

set -x
clang++ -std=c++17 -ObjC++ -w \
  -I"$K/macos-arm64/Headers" \
  -L"$K/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  "$HERE/probe.mm" -o "$BIN" || exit 1
set +x

for m in thresholds negative-dims zero-dims-accessors \
         uzawa-at-threshold uzawa-one-past uzawa-heap \
         trsf-determinant gtrsf-singular; do
  echo "----- mode $m"
  "$BIN" "$m" 2>&1
  echo "exit=$?"
done
