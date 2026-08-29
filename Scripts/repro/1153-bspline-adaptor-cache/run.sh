#!/usr/bin/env bash
# #1153: build and run occt_1153_stress.cpp against the pinned kernel as shipped (BSplCLib_Cache/
# BSplSLib_Cache/GeomAdaptor_Curve/GeomAdaptor_Surface unsynchronized) and against patch 0031
# applied to scratch copies of the four affected .cxx/.hxx files. All four are Standard_EXPORT
# .cxx-defined methods (not header-inline), so unlike #1154's TopoDS_TShape reproducer this one
# needs the four .cxx files themselves compiled into each binary, not just the header.
#
#   ./run.sh before   # pinned kernel, unpatched, under ThreadSanitizer (both scenarios)
#   ./run.sh after     # patch 0031 applied to scratch copies, under ThreadSanitizer (both scenarios)
#   ./run.sh deadlock  # single-threaded proof of finding 1 (self-deadlock), before vs after
#   ./run.sh all       # all of the above (default)
#
# Run from the repo root or from this directory; REPO is resolved either way.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
XCF="$REPO/Libraries/OCCT.xcframework/macos-arm64"
SRC="$REPO/Libraries/occt-src/src"
PATCHFILE="$REPO/Scripts/patches/0031-bspline-adaptor-cache-thread-safety-1153.patch"
OUT="${OUT:-$HERE/out}"
mkdir -p "$OUT"

if [ ! -d "$XCF/Headers" ]; then
  echo "no local OCCT.xcframework at $XCF; symlink Libraries/ from the main checkout" >&2
  exit 2
fi
if [ ! -f "$SRC/FoundationClasses/TKMath/BSplCLib/BSplCLib_Cache.cxx" ]; then
  echo "no OCCT sources at $SRC; Libraries/occt-src is gitignored, run Scripts/build-occt.sh" >&2
  exit 2
fi

GEOM_INC="$SRC/ModelingData/TKG3d/Geom" # GeomAdaptor_{Curve,Surface}.cxx's own quoted "../Geom/*.pxx" includes

setup_scratch() {
  # Patch a scratch copy so Libraries/occt-src stays exactly as build-occt.sh left it.
  rm -rf "$OUT/patched"
  mkdir -p "$OUT/patched/src/FoundationClasses/TKMath/BSplCLib" \
           "$OUT/patched/src/FoundationClasses/TKMath/BSplSLib" \
           "$OUT/patched/src/ModelingData/TKG3d/GeomAdaptor"
  cp "$SRC/FoundationClasses/TKMath/BSplCLib/BSplCLib_Cache.hxx" "$SRC/FoundationClasses/TKMath/BSplCLib/BSplCLib_Cache.cxx" \
    "$OUT/patched/src/FoundationClasses/TKMath/BSplCLib/"
  cp "$SRC/FoundationClasses/TKMath/BSplSLib/BSplSLib_Cache.hxx" "$SRC/FoundationClasses/TKMath/BSplSLib/BSplSLib_Cache.cxx" \
    "$OUT/patched/src/FoundationClasses/TKMath/BSplSLib/"
  cp "$SRC/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Curve.hxx" "$SRC/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Curve.cxx" \
    "$SRC/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Surface.hxx" "$SRC/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Surface.cxx" \
    "$OUT/patched/src/ModelingData/TKG3d/GeomAdaptor/"
  ( cd "$OUT/patched" && patch -p1 --silent < "$PATCHFILE" )
}

tsan_compile_stock() {
  local tag="$1"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w -c -I"$XCF/Headers" \
    "$SRC/FoundationClasses/TKMath/BSplCLib/BSplCLib_Cache.cxx" -o "$OUT/${tag}_bsplc.o"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w -c -I"$XCF/Headers" \
    "$SRC/FoundationClasses/TKMath/BSplSLib/BSplSLib_Cache.cxx" -o "$OUT/${tag}_bspsl.o"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w -c -I"$GEOM_INC" -I"$XCF/Headers" \
    "$SRC/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Curve.cxx" -o "$OUT/${tag}_curve.o"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w -c -I"$GEOM_INC" -I"$XCF/Headers" \
    "$SRC/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Surface.cxx" -o "$OUT/${tag}_surface.o"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w -c -I"$XCF/Headers" \
    "$HERE/occt_1153_stress.cpp" -o "$OUT/${tag}_main.o"
}

tsan_compile_patched() {
  local tag="$1"
  local pinc="$OUT/patched/src"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w -c -I"$pinc/FoundationClasses/TKMath/BSplCLib" -I"$XCF/Headers" \
    "$pinc/FoundationClasses/TKMath/BSplCLib/BSplCLib_Cache.cxx" -o "$OUT/${tag}_bsplc.o"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w -c -I"$pinc/FoundationClasses/TKMath/BSplSLib" -I"$XCF/Headers" \
    "$pinc/FoundationClasses/TKMath/BSplSLib/BSplSLib_Cache.cxx" -o "$OUT/${tag}_bspsl.o"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w -c -I"$pinc/ModelingData/TKG3d/GeomAdaptor" -I"$GEOM_INC" -I"$XCF/Headers" \
    "$pinc/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Curve.cxx" -o "$OUT/${tag}_curve.o"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w -c -I"$pinc/ModelingData/TKG3d/GeomAdaptor" -I"$GEOM_INC" -I"$XCF/Headers" \
    "$pinc/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Surface.cxx" -o "$OUT/${tag}_surface.o"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w -c -I"$pinc/ModelingData/TKG3d/GeomAdaptor" -I"$XCF/Headers" \
    "$HERE/occt_1153_stress.cpp" -o "$OUT/${tag}_main.o"
}

tsan_link() {
  local tag="$1"
  clang++ -std=c++17 -fsanitize=thread -g -O1 -w \
    "$OUT/${tag}_main.o" "$OUT/${tag}_bsplc.o" "$OUT/${tag}_bspsl.o" "$OUT/${tag}_curve.o" "$OUT/${tag}_surface.o" \
    -L"$XCF" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o "$OUT/${tag}"
}


# macOS has no GNU `timeout` by default; this is the portable equivalent used below.
portable_timeout() {
  local aSeconds="$1"; shift
  "$@" & local aPid=$!
  ( sleep "$aSeconds"; kill -9 "$aPid" 2>/dev/null ) & local aWatcher=$!
  if wait "$aPid" 2>/dev/null; then
    kill "$aWatcher" 2>/dev/null; wait "$aWatcher" 2>/dev/null
    return 0
  fi
  return 124
}

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
  tsan_compile_stock before
  tsan_link before
  run_scenario "$OUT/before" shared_adaptor_curve 16 3000
  run_scenario "$OUT/before" shared_adaptor_surface 16 3000
}

run_after() {
  echo "########## AFTER: patch 0031 override-linked ##########"
  setup_scratch
  tsan_compile_patched after
  tsan_link after
  run_scenario "$OUT/after" shared_adaptor_curve 16 3000
  run_scenario "$OUT/after" shared_adaptor_surface 16 3000
}

run_deadlock() {
  echo "########## Finding 1: single-threaded deadlock proof (no TSan needed) ##########"
  echo "--- before: stock header (no fix at all -- sanity baseline) ---"
  clang++ -std=c++17 -w -O0 -g -c -I"$XCF/Headers" \
    "$SRC/FoundationClasses/TKMath/BSplCLib/BSplCLib_Cache.cxx" -o "$OUT/deadlock_stock.o"
  clang++ -std=c++17 -w -O0 -g -c -I"$XCF/Headers" "$HERE/deadlock_probe.cpp" -o "$OUT/deadlock_probe_stock.o"
  clang++ -std=c++17 -w -O0 -g "$OUT/deadlock_probe_stock.o" "$OUT/deadlock_stock.o" \
    -L"$XCF" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o "$OUT/deadlock_stock"
  portable_timeout 5 "$OUT/deadlock_stock" || echo "(stock has no mutex at all; finishes fine, single-threaded)"

  echo "--- after: patch 0031 (recursive_mutex) -- must return promptly ---"
  setup_scratch
  clang++ -std=c++17 -w -O0 -g -c -I"$OUT/patched/src/FoundationClasses/TKMath/BSplCLib" -I"$XCF/Headers" \
    "$OUT/patched/src/FoundationClasses/TKMath/BSplCLib/BSplCLib_Cache.cxx" -o "$OUT/deadlock_after.o"
  clang++ -std=c++17 -w -O0 -g -c -I"$OUT/patched/src/FoundationClasses/TKMath/BSplCLib" -I"$XCF/Headers" \
    "$HERE/deadlock_probe.cpp" -o "$OUT/deadlock_probe_after.o"
  clang++ -std=c++17 -w -O0 -g "$OUT/deadlock_probe_after.o" "$OUT/deadlock_after.o" \
    -L"$XCF" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o "$OUT/deadlock_after"
  portable_timeout 5 "$OUT/deadlock_after"
  echo "(finding 1's actual regression test is against the ORIGINAL PR's non-recursive-mutex"
  echo " content, which is not carried anywhere in this repo; see deadlock_before.txt for that"
  echo " transcript, captured against the exact #1322 diff before it was rewritten.)"
}

case "${1:-all}" in
  before)   run_before ;;
  after)    run_after ;;
  deadlock) run_deadlock ;;
  all)      run_deadlock; echo; run_before; echo; run_after ;;
  *) echo "usage: $0 [before|after|deadlock|all]" >&2; exit 2 ;;
esac
