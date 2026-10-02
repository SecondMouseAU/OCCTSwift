#!/bin/bash
# Reproducer for #2875, carried OCCT patch 0045.
#
# Override-links Geom2d_BezierCurve.cxx and Geom_BezierCurve.cxx ahead of the pinned macOS slice,
# once pristine and once with 0045 applied, in both build configurations: the shipped one, which
# defines No_Exception, and one with exceptions enabled. Needs Libraries/occt-src and
# Libraries/OCCT.xcframework, so run it from a checkout that has built the kernel at least once.
#
# Run from the repo root: Scripts/repro/2875-bezier-insertpole-bound/run.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
SRC="$ROOT/Libraries/occt-src"
XCF="$ROOT/Libraries/OCCT.xcframework"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

TUS="src/ModelingData/TKG2d/Geom2d/Geom2d_BezierCurve.cxx src/ModelingData/TKG3d/Geom/Geom_BezierCurve.cxx"
for f in $TUS; do
  mkdir -p "$WORK/pristine/$(dirname "$f")" "$WORK/patched/$(dirname "$f")"
  cp "$SRC/$f" "$WORK/pristine/$f"
  cp "$SRC/$f" "$WORK/patched/$f"
done
# The tree may or may not already carry 0045; normalise both sides from it.
patch -s -p1 -R --forward -d "$WORK/pristine" < "$ROOT/Scripts/patches/0045-Geom-Bezier-InsertPoleAfter-pole-bound-2875.patch" 2>/dev/null
patch -s -p1 --forward -d "$WORK/patched" < "$ROOT/Scripts/patches/0045-Geom-Bezier-InsertPoleAfter-pole-bound-2875.patch" 2>/dev/null

MACSDK=$(xcrun --sdk macosx --show-sdk-path)
BASE="-std=c++17 -O1 -g -DNDEBUG -arch arm64 -isysroot $MACSDK -mmacosx-version-min=12.0"
INC="-I$XCF/macos-arm64/Headers -I$SRC/src/ModelingData/TKG2d/Geom2dEval -I$SRC/src/ModelingData/TKG3d/GeomEval"
LINK="-L$XCF/macos-arm64 -lOCCT-macos -framework Foundation -framework AppKit -lz"

for config in "shipped:-DNo_Exception" "exceptions:"; do
  name="${config%%:*}"
  extra="${config#*:}"
  for side in pristine patched; do
    objs=""
    for f in $TUS; do
      o="$WORK/$(basename "$f" .cxx)-$side-$name.o"
      clang++ $BASE $extra $INC -c "$WORK/$side/$f" -o "$o" || exit 1
      objs="$objs $o"
    done
    clang++ $BASE $extra $INC -c "$HERE/probe.cxx" -o "$WORK/probe-$side-$name.o" || exit 1
    clang++ $BASE $objs "$WORK/probe-$side-$name.o" $LINK -o "$WORK/run-$side-$name" || exit 1
    echo "--- $name / $side"
    "$WORK/run-$side-$name"
    echo "exit=$?"
  done
done
