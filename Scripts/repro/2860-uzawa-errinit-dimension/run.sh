#!/bin/bash
# Reproducer for #2860's math_Uzawa finding, carried OCCT patch 0046.
#
# Override-links math_Uzawa.cxx ahead of the pinned macOS slice, once pristine and once with 0046
# applied, and runs each size in its own process, because the largest one faults unpatched. Needs
# Libraries/occt-src and Libraries/OCCT.xcframework, so run it from a checkout that has built the
# kernel at least once.
#
# Run from the repo root: Scripts/repro/2860-uzawa-errinit-dimension/run.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
SRC="$ROOT/Libraries/occt-src"
XCF="$ROOT/Libraries/OCCT.xcframework"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

TU="src/FoundationClasses/TKMath/math/math_Uzawa.cxx"
for side in pristine patched; do
  mkdir -p "$WORK/$side/$(dirname "$TU")"
  cp "$SRC/$TU" "$WORK/$side/$TU"
done
# The tree may or may not already carry 0046; normalise both sides from it.
patch -s -p1 -R --forward -d "$WORK/pristine" < "$ROOT/Scripts/patches/0046-math_Uzawa-Errinit-row-dimension-2860.patch" 2>/dev/null
patch -s -p1 --forward -d "$WORK/patched" < "$ROOT/Scripts/patches/0046-math_Uzawa-Errinit-row-dimension-2860.patch" 2>/dev/null

MACSDK=$(xcrun --sdk macosx --show-sdk-path)
BASE="-std=c++17 -O1 -g -DNDEBUG -DNo_Exception -arch arm64 -isysroot $MACSDK -mmacosx-version-min=12.0"
INC="-I$XCF/macos-arm64/Headers"
LINK="-L$XCF/macos-arm64 -lOCCT-macos -framework Foundation -framework AppKit -lz"

for side in pristine patched; do
  clang++ $BASE $INC -c "$WORK/$side/$TU" -o "$WORK/uzawa-$side.o" || exit 1
  clang++ $BASE $INC -c "$HERE/probe.cxx" -o "$WORK/probe-$side.o" || exit 1
  clang++ $BASE "$WORK/uzawa-$side.o" "$WORK/probe-$side.o" $LINK -o "$WORK/run-$side" || exit 1
  echo "--- $side"
  for mode in square small-over edge-over heap-over far-over; do
    printf '%-12s ' "$mode"
    "$WORK/run-$side" "$mode"
    echo "             exit=$?"
  done
done
