#!/usr/bin/env bash
# #1022: compile the upstream GTests for XCAFDoc's GD&T surface and run them against the unpatched
# sources and against the patched ones. This is the "prove the test fails" step: the three new
# cases must fail unpatched and pass patched, and the file's eight pre-existing cases must pass in
# both, which is why the AFTER run is unfiltered. The BEFORE run cannot be: GdtDatum_PointWithoutPlane
# takes the whole process down with a SIGSEGV, so it is split into its own invocation and everything
# else runs in a second one.
#
#   OCCT_UPSTREAM=~/Projects/occt-upstream ./run-gtest.sh before|after|both
#
# Both runs compile XCAFDoc_Datum.cxx out of Libraries/occt-src, which is the pinned V8_0_1 tree and
# is byte-identical to upstream master for this file. `after` applies Scripts/patches/0029 to a
# scratch copy first, so neither run depends on which branch the upstream checkout is sitting on.
#
# The only thing taken from the upstream checkout is the GTest source, which this repo does not
# carry. Its three new cases are checked for by name below, so a checkout on the wrong branch fails
# loudly instead of reporting a pristine result under an "AFTER" banner.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
UP="${OCCT_UPSTREAM:-$HOME/Projects/occt-upstream}"
XCF="$REPO/Libraries/OCCT.xcframework/macos-arm64"
SRCDIR="$REPO/Libraries/occt-src/src/DataExchange/TKXCAF/XCAFDoc"
PATCHFILE="$REPO/Scripts/patches/0029-XCAFDoc_Datum-point-read-from-plane-array-1022.patch"
TESTSRC="$UP/src/DataExchange/TKXCAF/GTests/XCAFDoc_GDT_Test.cxx"
OUT="${OUT:-$HERE/out/gtest}"
mkdir -p "$OUT"

if [ ! -d "$XCF/Headers" ]; then
  echo "no local OCCT.xcframework at $XCF; symlink Libraries/ from the main checkout" >&2
  exit 2
fi
if [ ! -f "$SRCDIR/XCAFDoc_Datum.cxx" ]; then
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
for aCase in GdtDatum_PointIsReadFromItsOwnArray \
             GdtDatum_PointWithoutPlane \
             GdtDatum_PlaneWithoutPoint; do
  if ! grep -q "$aCase" "$TESTSRC"; then
    echo "$TESTSRC has no $aCase; the upstream checkout is not on fix/1022-*" >&2
    exit 2
  fi
done

LDFLAGS=(-L"$XCF" -L"$GT/lib" -lOCCT-macos -lgtest -lgtest_main
         -framework Foundation -framework AppKit -lz)

# Building is separate from running on purpose: the BEFORE lane expects a non-zero exit from the
# test binary, and a compile failure must not be able to hide inside that expectation.
build_gtest() {
  local aTag="$1" aSrc="$2"
  clang++ -std=c++17 -w -O0 -g -I"$XCF/Headers" \
    -c "$aSrc/XCAFDoc_Datum.cxx" -o "$OUT/${aTag}_override.o"
  clang++ -std=c++17 -w -O0 -g -I"$XCF/Headers" -I"$GT/include" \
    -c "$TESTSRC" -o "$OUT/${aTag}_test.o"
  clang++ "$OUT/${aTag}_override.o" "$OUT/${aTag}_test.o" "${LDFLAGS[@]}" -o "$OUT/gtest_$aTag"
}

stage_sources() {
  local aDir="$1"
  rm -rf "$aDir"
  mkdir -p "$aDir/src/DataExchange/TKXCAF/XCAFDoc"
  cp "$SRCDIR/XCAFDoc_Datum.cxx" "$aDir/src/DataExchange/TKXCAF/XCAFDoc/"
}

run_before() {
  echo "########## GTests BEFORE: unpatched sources ##########"
  stage_sources "$OUT/pristine"
  build_gtest pristine "$OUT/pristine/src/DataExchange/TKXCAF/XCAFDoc"
  # GdtDatum_PointWithoutPlane takes the whole process down with a SIGSEGV, which gtest cannot
  # catch, so it runs on its own and everything else runs without it. Two invocations rather than
  # one is what makes the other ten results readable.
  echo "--- every case except GdtDatum_PointWithoutPlane ---"
  "$OUT/gtest_pristine" --gtest_filter=-XCAFDoc_GDT_Test.GdtDatum_PointWithoutPlane || true
  echo "--- GdtDatum_PointWithoutPlane on its own ---"
  set +e
  "$OUT/gtest_pristine" --gtest_filter=XCAFDoc_GDT_Test.GdtDatum_PointWithoutPlane
  local aStatus=$?
  set -e
  echo "exit status $aStatus (139 is 128 + SIGSEGV)"
}

run_after() {
  echo "########## GTests AFTER: patch 0029 applied ##########"
  stage_sources "$OUT/patched"
  ( cd "$OUT/patched" && patch -p1 --silent < "$PATCHFILE" )
  build_gtest patched "$OUT/patched/src/DataExchange/TKXCAF/XCAFDoc"
  "$OUT/gtest_patched"
}

case "${1:-both}" in
  before) run_before ;;
  after)  run_after ;;
  both)   run_before; echo; run_after ;;
  *) echo "usage: $0 [before|after|both]" >&2; exit 2 ;;
esac
