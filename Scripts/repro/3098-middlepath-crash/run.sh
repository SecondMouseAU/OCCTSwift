#!/bin/bash
# Compiles probe.mm against the pinned xcframework and runs every case in its own process.
# usage: Scripts/repro/3098-middlepath-crash/run.sh [path-to-OCCT.xcframework]
set -u
cd "$(dirname "$0")"
XC="${1:-../../../.build/artifacts/$(basename "$(cd ../../.. && pwd)")/OCCT/OCCT.xcframework}"
clang++ -std=c++17 -ObjC++ -w -g -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ probe.mm -o "${TMPDIR:-/tmp}/probe3098" || exit 1
for c in oppositeBox cylinder cylSideCap wireOpposite sphere sameFace sameWire adjacentFaces nullEnds nullStart nullEnd nullShape nonFaceWire edgeStart vertexStart shellStart; do
  "${TMPDIR:-/tmp}/probe3098" "$c" 2>"${TMPDIR:-/tmp}/probe3098.err"
  rc=$?
  echo "  $c exit=$rc"
  [ $rc -ne 0 ] && head -12 "${TMPDIR:-/tmp}/probe3098.err" | sed 's/^/      /'
done
