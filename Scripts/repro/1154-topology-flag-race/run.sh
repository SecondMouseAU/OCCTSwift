#!/usr/bin/env bash
# #1154: build and run occt_1154_stress.cpp under ThreadSanitizer, once against the pinned kernel as
# shipped (myState a plain uint16_t) and once with patch 0030's TopoDS_TShape.hxx placed ahead of the
# xcframework's copy on the include path. TopoDS_TShape's flag getters/setter/setBit are all inline,
# defined entirely in the header, so this TU is fully TSan-instrumented for the code path in question
# regardless of whether the prebuilt archive itself was built with -fsanitize=thread.
#
#   ./run.sh before      # pinned kernel, unpatched
#   ./run.sh after       # patch 0030 applied to a scratch copy of the header, override-linked
#   ./run.sh both        # both, in that order (default)
#
# Run from the repo root or from this directory; REPO is resolved either way.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
XCF="$REPO/Libraries/OCCT.xcframework/macos-arm64"
SRCDIR="$REPO/Libraries/occt-src/src/ModelingData/TKBRep/TopoDS"
PATCHFILE="$REPO/Scripts/patches/0030-TopoDS_TShape-myState-atomic-1154.patch"
OUT="${OUT:-$HERE/out}"
mkdir -p "$OUT"

if [ ! -d "$XCF/Headers" ]; then
  echo "no local OCCT.xcframework at $XCF; symlink Libraries/ from the main checkout" >&2
  exit 2
fi
if [ ! -f "$SRCDIR/TopoDS_TShape.hxx" ]; then
  echo "no OCCT sources at $SRCDIR; Libraries/occt-src is gitignored, run Scripts/build-occt.sh" >&2
  exit 2
fi

CXXFLAGS=(-std=c++17 -fsanitize=thread -g -O1 -w)
LDFLAGS=(-L"$XCF" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++)

run_scenario() {
  local aBin="$1" aScenario="$2" aThreads="$3" aIterations="$4"
  echo "--- scenario=$aScenario threads=$aThreads iterations=$aIterations ---"
  set +e
  TSAN_OPTIONS="halt_on_error=0" "$aBin" "$aScenario" "$aThreads" "$aIterations"
  local aStatus=$?
  set -e
  echo "exit status $aStatus (134 is 128+SIGABRT, TSan's default when it finds a race)"
}

run_before() {
  echo "########## BEFORE: pinned kernel, no override ##########"
  clang++ "${CXXFLAGS[@]}" -I"$XCF/Headers" "$HERE/occt_1154_stress.cpp" \
    "${LDFLAGS[@]}" -o "$OUT/stress_before"
  run_scenario "$OUT/stress_before" tshape_myState_race 8 2000
  run_scenario "$OUT/stress_before" boolean_shared_topology 8 3
}

run_after() {
  echo "########## AFTER: patch 0030 override-linked ##########"
  # Patch a scratch copy so Libraries/occt-src stays exactly as build-occt.sh left it.
  rm -rf "$OUT/patched"
  mkdir -p "$OUT/patched/src/ModelingData/TKBRep/TopoDS"
  cp "$SRCDIR/TopoDS_TShape.hxx" "$OUT/patched/src/ModelingData/TKBRep/TopoDS/"
  ( cd "$OUT/patched" && patch -p1 --silent < "$PATCHFILE" )
  # The patched header must precede the xcframework's copy on the include path.
  clang++ "${CXXFLAGS[@]}" -I"$OUT/patched/src/ModelingData/TKBRep/TopoDS" -I"$XCF/Headers" \
    "$HERE/occt_1154_stress.cpp" "${LDFLAGS[@]}" -o "$OUT/stress_after"
  run_scenario "$OUT/stress_after" tshape_myState_race 16 3000
  run_scenario "$OUT/stress_after" boolean_shared_topology 12 5
}

case "${1:-both}" in
  before) run_before ;;
  after)  run_after ;;
  both)   run_before; echo; run_after ;;
  *) echo "usage: $0 [before|after|both]" >&2; exit 2 ;;
esac
