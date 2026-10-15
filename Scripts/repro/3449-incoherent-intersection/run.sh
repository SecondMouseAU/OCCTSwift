#!/usr/bin/env bash
# Builds probe.cpp twice against the repo's xcframework: once as is, once with the patched
# BRepFill_TrimSurfaceTool.cxx override-linked (Libraries/occt-src must hold patch 0068, built
# -O2 -DNo_Exception like the Release kernel). Arguments: px py face cx cy mode dx dy dz axeProf.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
XCF="$REPO/Libraries/OCCT.xcframework/macos-arm64"
SRC="$REPO/Libraries/occt-src/src/ModelingAlgorithms/TKBool/BRepFill/BRepFill_TrimSurfaceTool.cxx"
OUT="${OUT:-$HERE/out}"
mkdir -p "$OUT"
LIBS=(-L"$XCF" -lOCCT-macos -framework Foundation -framework AppKit -lz)
clang++ -std=c++17 -w -O0 -g -I"$XCF/Headers" "$HERE/probe.cpp" "${LIBS[@]}" -o "$OUT/unpatched"
clang++ -std=c++17 -w -O2 -DNo_Exception -I"$XCF/Headers" "$HERE/probe.cpp" "$SRC" "${LIBS[@]}" \
  -o "$OUT/patched"
echo "-- unpatched"; "$OUT/unpatched" "$@" 2>&1 | head -4 || true
echo "-- patched";   "$OUT/patched" "$@" 2>&1 | head -4
