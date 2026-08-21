#!/usr/bin/env bash
# #1018: compile the upstream GTests for GeomPlate_BuildPlateSurface and run them against the
# pristine sources and against the patched ones. This is the "prove the test fails" step: the four
# new cases must fail unpatched and pass patched, and the file's pre-existing cases must pass in
# both, which is why neither run is filtered.
#
#   OCCT_UPSTREAM=~/Projects/occt-upstream ./run-gtest.sh before|after|both
#
# Both runs compile GeomPlate_BuildPlateSurface.cxx/.hxx out of Libraries/occt-src, which is the
# pinned V8_0_1 tree and is byte-identical to upstream master for this class. `after` applies
# Scripts/patches/0028 to a scratch copy first, exactly as run.sh does, so neither run depends on
# which branch the upstream checkout happens to be sitting on.
#
# The only thing taken from the upstream checkout is the GTest source itself, which this repo does
# not carry (neither does 0026's nor 0027's). Its four new cases are checked for by name below, so
# a checkout on the wrong branch fails loudly instead of reporting a pristine result under an
# "AFTER" banner.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
UP="${OCCT_UPSTREAM:-$HOME/Projects/occt-upstream}"
XCF="$REPO/Libraries/OCCT.xcframework/macos-arm64"
SRCDIR="$REPO/Libraries/occt-src/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate"
PATCHFILE="$REPO/Scripts/patches/0028-GeomPlate_BuildPlateSurface-uninitialised-G0-G1-G2-errors-1018.patch"
TESTSRC="$UP/src/ModelingAlgorithms/TKGeomAlgo/GTests/GeomPlate_BuildPlateSurface_Test.cxx"
OUT="${OUT:-$HERE/out/gtest}"
mkdir -p "$OUT"

if [ ! -d "$XCF/Headers" ]; then
  echo "no local OCCT.xcframework at $XCF; symlink Libraries/ from the main checkout" >&2
  exit 2
fi
if [ ! -f "$SRCDIR/GeomPlate_BuildPlateSurface.cxx" ]; then
  echo "no OCCT sources at $SRCDIR; Libraries/occt-src is gitignored, run Scripts/build-occt.sh" >&2
  exit 2
fi
GT="$(brew --prefix googletest 2>/dev/null || true)"
if [ -z "$GT" ] || [ ! -d "$GT/include" ]; then
  echo "googletest not found; brew install googletest" >&2
  exit 2
fi
if [ ! -f "$TESTSRC" ]; then
  echo "no GTest source at $TESTSRC; set OCCT_UPSTREAM to the checkout of gsdali/OCCT" >&2
  exit 2
fi
for aCase in PointOnlyConstraintsReportMeasuredErrors \
             PointOnlyErrorsAreMaximaNotTheLastConstraint \
             ErrorsAreZeroBeforePerform \
             CancelledRebuildDoesNotReportThePreviousErrors; do
  if ! grep -q "$aCase" "$TESTSRC"; then
    echo "$TESTSRC has no $aCase; the upstream checkout is not on fix/1018-*" >&2
    exit 2
  fi
done

LDFLAGS=(-L"$XCF" -L"$GT/lib" -lOCCT-macos -lgtest -lgtest_main
         -framework Foundation -framework AppKit -lz)

# $1 = tag, $2 = directory holding the GeomPlate_BuildPlateSurface sources to compile.
# Building is separate from running on purpose: the BEFORE lane expects a non-zero exit from the
# test binary, and a compile failure must not be able to hide inside that expectation.
build_gtest() {
  local aTag="$1" aSrc="$2"
  clang++ -std=c++17 -w -O0 -g -I"$aSrc" -I"$XCF/Headers" \
    -c "$aSrc/GeomPlate_BuildPlateSurface.cxx" -o "$OUT/${aTag}_override.o"
  clang++ -std=c++17 -w -O0 -g -I"$aSrc" -I"$XCF/Headers" -I"$GT/include" \
    -c "$TESTSRC" -o "$OUT/${aTag}_test.o"
  clang++ "$OUT/${aTag}_override.o" "$OUT/${aTag}_test.o" "${LDFLAGS[@]}" -o "$OUT/gtest_$aTag"
}

stage_sources() {
  local aDir="$1"
  rm -rf "$aDir"
  mkdir -p "$aDir/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate"
  cp "$SRCDIR/GeomPlate_BuildPlateSurface.cxx" "$SRCDIR/GeomPlate_BuildPlateSurface.hxx" \
     "$aDir/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate/"
}

run_before() {
  echo "########## GTests BEFORE: unpatched sources ##########"
  stage_sources "$OUT/pristine"
  build_gtest pristine "$OUT/pristine/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate"
  # Only the run may fail here, and failing is the point.
  "$OUT/gtest_pristine" || true
}

run_after() {
  echo "########## GTests AFTER: patch 0028 applied ##########"
  stage_sources "$OUT/patched"
  ( cd "$OUT/patched" && patch -p1 --silent < "$PATCHFILE" )
  build_gtest patched "$OUT/patched/src/ModelingAlgorithms/TKGeomAlgo/GeomPlate"
  "$OUT/gtest_patched"
}

case "${1:-both}" in
  before) run_before ;;
  after)  run_after ;;
  both)   run_before; echo; run_after ;;
  *) echo "usage: $0 [before|after|both]" >&2; exit 2 ;;
esac
