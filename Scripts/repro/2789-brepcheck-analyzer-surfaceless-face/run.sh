#!/bin/bash
# Runs the #2789 measurement: where BRepCheck_Analyzer faults on a face with no surface that carries
# a wire. #2777 measured the fault and deliberately did not locate it; this directory locates it,
# kills the prediction that reading the source produced, and derives the population of bridge sites
# that reach it, including the two no search for `BRepCheck_Analyzer` would have found.
#
# Usage, from the repository root:
#   Scripts/repro/2789-brepcheck-analyzer-surfaceless-face/run.sh [path/to/OCCT.xcframework/macos-arm64]
#
# With no argument it looks for the pinned asset SwiftPM resolved under .build/artifacts, and falls
# back to a checked-in Libraries/OCCT.xcframework if one is present.
#
# Every case runs in its OWN process, because a reproducing case is uncatchable and takes the rest
# of the transcript with it. That is #2777's pattern, which is #2773's, which is #2750's.
#
# It writes no fixture. The one the Swift regression suite reads,
# Tests/OCCTStressTests/Fixtures/surfaceless-face-with-wire.brep, belongs to #2777 and is written by
# Scripts/repro/2777-iges-writer-surfaceless-face/run.sh; the pcurve-only one belongs to #2750.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"

XCF="${1:-}"
if [ -z "$XCF" ]; then
  XCF="$(find "$ROOT/.build/artifacts" -type d -path '*OCCT.xcframework/macos-arm64' 2>/dev/null | head -1)"
fi
if [ -z "$XCF" ] && [ -d "$ROOT/Libraries/OCCT.xcframework/macos-arm64" ]; then
  XCF="$ROOT/Libraries/OCCT.xcframework/macos-arm64"
fi
if [ -z "$XCF" ] || [ ! -d "$XCF" ]; then
  echo "No OCCT.xcframework found. Run 'swift build' once to resolve the pinned asset, or pass"
  echo "the macos-arm64 slice as the first argument."
  exit 2
fi

WORK="${TMPDIR:-/tmp}/occt_2789"
mkdir -p "$WORK"
BIN="$WORK/probe"
FIXTURES="$ROOT/Tests/OCCTStressTests/Fixtures"

echo "xcframework: $XCF"
echo "compiling..."
clang++ -std=c++17 -ObjC++ -g -O0 -w \
  -I"$XCF/Headers" \
  -L"$XCF" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  "$HERE/probe.mm" -o "$BIN" || exit 1

run_case() {
  echo
  echo "--- $* -----------------------------------------------------------------"
  "$BIN" "$@" 2>&1
  echo "[exit $?]"
}

run_case describe

# Step 0: reproduce #2777's table on the pin, then add the two fixtures it did not have. `geom` 0 is
# the row that kills the prediction from reading: the fault is not behind the analyzer's own
# geometric-controls flag.
for FIX in box compound bare withwire barewithwire withpolywire surfnopcurve; do
  run_case analyzer "$FIX" no 1
  run_case analyzer "$FIX" no 0
done

# Step 0b: the signal axis. With an OSD handler installed, OCCT converts the fault and the analyzer's
# own catch absorbs it, so the same input kills one process and answers false in another (#2763).
for FIX in box compound bare withwire barewithwire; do
  run_case analyzer "$FIX" yes 1
done

# Step 1: which of the four calls BRepCheck_ParallelAnalyzer's FACE branch makes, in its own order.
for FIX in barewithwire withpolywire surfnopcurve box; do
  run_case vertex-incontext "$FIX" no
  run_case edge-incontext "$FIX" no 1
  run_case edge-incontext "$FIX" no 0
  run_case wire-incontext "$FIX" no 1
  run_case wire-incontext "$FIX" no 0
  run_case face-wires "$FIX" no
done

# Step 2: inside BRepCheck_Wire::InContext, the prediction that was wrong. SelfIntersect returns
# early on a null pcurve, Closed and Orientation answer NoError, and Closed2d raises catchably.
for FIX in barewithwire box; do
  run_case wire-selfintersect "$FIX" no
  run_case wire-closed "$FIX" no
  run_case wire-orientation "$FIX" no
  run_case wire-closed2d "$FIX" no
done

# Step 3: the line. BRepCheck_Edge.cxx:463 on its own, and the two facts that make the branch the
# one taken: no pcurve of these edges is on THIS face, and myCref is non-null so the FACE branch runs.
for FIX in barewithwire withpolywire surfnopcurve box; do
  run_case dynamictype "$FIX" no
  run_case pcurve "$FIX"
  run_case crefs "$FIX"
done

# Step 3b: the killed prediction, kept because it is a SECOND untested dereference in the same file
# and it is upstream-reportable on its own. BRepAdaptor_Surface::Initialize returns silently on a null
# surface and BRepCheck_Wire.cxx:1203's HS->Value() would fault, if SelfIntersect ever got that far.
for FIX in barewithwire surfnopcurve box; do
  run_case adaptor "$FIX" no
done

# Step 4: the population. Everything else in the bridge that reaches BRepCheck, driven the way the
# bridge drives it, because the answer decides whether a site needs a guard or would only get noise.
for FIX in barewithwire withwire bare box; do
  run_case subchecker "$FIX" no
done

# Step 4b: the two sites a search for `BRepCheck_Analyzer` in Sources/OCCTBridge/src/ does not find.
# BRepAlgoAPI_Check::Perform builds one at BRepAlgoAPI_Check.cxx:92, so both of the analyzer's fatal
# inputs reach OCCTShapeBooleanCheckSingle / Pair. Both committed fixtures, because these two were
# unguarded against #2746 as well.
for FIX in barewithwire withwire bare box; do
  run_case algocheck "$FIX" no
done
run_case algocheck "$FIXTURES/brepcheck-incontext-pcurve-only-edge.brep" no
run_case algocheck "$FIXTURES/surfaceless-face-with-wire.brep" no
run_case analyzer "$FIXTURES/brepcheck-incontext-pcurve-only-edge.brep" no 1

# Step 4c: the one guard site where the surface clause is provably vacuous, measured rather than
# argued, so the comment at OCCTBridge.mm's inner analyzer can say so.
for FIX in barewithwire withpolywire box; do
  run_case makefaceplane "$FIX"
done

# Step 5: the committed fixtures, so the Swift suite's inputs are measured and not assumed to match
# the in-memory ones.
run_case describe-file "$FIXTURES/surfaceless-face-with-wire.brep"
run_case describe-file "$FIXTURES/shapedivide-surfaceless-edgeless-face.brep"
run_case analyzer "$FIXTURES/surfaceless-face-with-wire.brep" no 1
run_case edge-incontext "$FIXTURES/surfaceless-face-with-wire.brep" no 1
run_case dynamictype "$FIXTURES/surfaceless-face-with-wire.brep" no

# Step 6: #2755's premise. Asking after one sub-shape is not a narrower operation than asking after
# the shape: it is the same walk, and it dies the same way.
for FIX in barewithwire withpolywire box; do
  run_case analyzer-sub "$FIX" no
done

echo
echo "artifacts left in $WORK"
