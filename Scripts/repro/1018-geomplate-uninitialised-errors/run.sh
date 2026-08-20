#!/usr/bin/env bash
# #1018: build and run the reproducer twice, once against the pinned kernel as shipped and once
# with the patched GeomPlate_BuildPlateSurface.cxx override-linked ahead of the archive.
#
#   ./run.sh before      # pinned kernel, unpatched
#   ./run.sh after       # patch 0028 applied to a scratch copy, override-linked
#   ./run.sh both        # both, in that order (default)
#
# Run from the repo root or from this directory; REPO is resolved either way.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
XCF="$REPO/Libraries/OCCT.xcframework/macos-arm64"
SRCDIR="$REPO/Libraries/occt-src/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate"
PATCHFILE="$REPO/Scripts/patches/0028-GeomPlate_BuildPlateSurface-uninitialised-G0-G1-G2-errors-1018.patch"
OUT="${OUT:-$HERE/out}"
mkdir -p "$OUT"

if [ ! -d "$XCF/Headers" ]; then
  echo "no local OCCT.xcframework at $XCF; symlink Libraries/ from the main checkout" >&2
  exit 2
fi
if [ ! -f "$SRCDIR/GeomPlate_BuildPlateSurface.cxx" ]; then
  echo "no OCCT sources at $SRCDIR; Libraries/occt-src is gitignored, run Scripts/build-occt.sh" >&2
  exit 2
fi

CXXFLAGS=(-std=c++17 -w -O0 -g -I"$XCF/Headers")
LDFLAGS=(-L"$XCF" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++)

build_probe() {
  clang++ "${CXXFLAGS[@]}" -c "$HERE/occt_1018_plate_errors.cxx" -o "$OUT/probe.o"
}

run_before() {
  echo "########## BEFORE: pinned kernel, no override ##########"
  build_probe
  clang++ "${CXXFLAGS[@]}" "$OUT/probe.o" "${LDFLAGS[@]}" -o "$OUT/probe_before"
  "$OUT/probe_before"
}

run_after() {
  echo "########## AFTER: patch 0028 override-linked ##########"
  # Patch a scratch copy so Libraries/occt-src stays exactly as build-occt.sh left it.
  rm -rf "$OUT/patched"
  mkdir -p "$OUT/patched/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate"
  cp "$SRCDIR/GeomPlate_BuildPlateSurface.cxx" "$SRCDIR/GeomPlate_BuildPlateSurface.hxx" \
     "$OUT/patched/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate/"
  ( cd "$OUT/patched" && patch -p1 --silent < "$PATCHFILE" )
  # The patched header must precede the xcframework's copy on the include path.
  clang++ -std=c++17 -w -O0 -g \
    -I"$OUT/patched/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate" -I"$XCF/Headers" \
    -c "$OUT/patched/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate/GeomPlate_BuildPlateSurface.cxx" \
    -o "$OUT/override.o"
  clang++ -std=c++17 -w -O0 -g \
    -I"$OUT/patched/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate" -I"$XCF/Headers" \
    -c "$HERE/occt_1018_plate_errors.cxx" -o "$OUT/probe_patched.o"
  clang++ "$OUT/override.o" "$OUT/probe_patched.o" "${LDFLAGS[@]}" -o "$OUT/probe_after"
  "$OUT/probe_after"
}

case "${1:-both}" in
  before) run_before ;;
  after)  run_after ;;
  both)   run_before; echo; run_after ;;
  *) echo "usage: $0 [before|after|both]" >&2; exit 2 ;;
esac
