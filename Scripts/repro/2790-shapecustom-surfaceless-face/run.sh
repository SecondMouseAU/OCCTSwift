#!/bin/bash
# Runs the #2790 measurement: which of the six ShapeCustom operations the bridge wraps fault on a
# surface-less face, at which line each one faults, and whether the predicate needs #2773's edge
# clause the way #2773's own guard did.
#
# Usage, from the repository root:
#   Scripts/repro/2790-shapecustom-surfaceless-face/run.sh [path/to/OCCT.xcframework/macos-arm64]
#
# With no argument it looks for the pinned asset SwiftPM resolved under .build/artifacts, and falls
# back to a checked-in Libraries/OCCT.xcframework if one is present.
#
# Every case runs in its OWN process, because a reproducing case is uncatchable and takes the rest
# of the transcript with it. That is the pattern from
# Scripts/repro/2777-iges-writer-surfaceless-face/run.sh.
#
# It writes no fixture: all three .brep fixtures the Swift regression suite reads already exist,
# written by #2773's and #2777's run.sh, and this issue needs no new one.

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

WORK="${TMPDIR:-/tmp}/occt_2790"
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

# Step 0: the fixtures, in memory and as the committed .brep files the Swift suite reads. The two
# predicate columns are SURFACELESS and BOTH, and a fixture where they disagree is the row that
# decides whether #2773's narrower pair can be reused here.
run_case describe
for F in surfaceless-face-with-wire.brep \
         shapedivide-surfaceless-edgeless-face.brep \
         shapedivide-surfaceless-edgeless-bare-face.brep; do
  run_case describe-file "$FIXTURES/$F"
done

# Step 1: the whole ShapeCustom family the bridge wraps, over every fixture, both signal
# dispositions. This re-confirms #2777's table on the same pin rather than trusting it, and it
# re-confirms the two operations recorded as measured safe, which is the point of that record.
for OP in DirectFaces ScaleShape SweptToElementary ConvertToRevolution ConvertToBSpline \
          BSplineRestriction; do
  for FIX in bare compound barewithwire withwire box; do
    run_case shapecustom "$OP" "$FIX" no
  done
done

# Step 1b: the same three crashing operations with a signal handler installed, to show whether the
# kernel has a correct answer at all on this input. ShapeCustom::ApplyModifier carries no
# OCC_CATCH_SIGNALS, unlike ShapeUpgrade_ShapeDivide::Perform, so the prediction is that this axis
# changes nothing here where it changed everything for #2773.
for OP in SweptToElementary ConvertToRevolution ConvertToBSpline; do
  for FIX in bare barewithwire; do
    run_case shapecustom "$OP" "$FIX" yes
  done
done

# Step 2: down to the frame. NewSurface called directly on each face, with the surface handle printed
# null in the same process. Nothing runs inside NewSurface before the statements named at the top of
# probe.mm, so a fault here is those lines and no other. The two subclasses that hold their own null
# test are in the list, because a negative measured the same way is the evidence for the upstream fix.
for WHICH in SweptToElementary ConvertToRevolution ConvertToBSpline \
             BSplineRestriction TrsfModification DirectModification; do
  for FIX in bare barewithwire box; do
    run_case newsurface "$WHICH" "$FIX" no
  done
done

# Step 3: BRepTools_Modifier over the subclass with no ShapeCustom::ApplyModifier above it. This is
# the shape of two bridge functions neither #2777's nor #2790's derived population contains, because
# both derivations looked for `ShapeCustom::` free-function calls:
# OCCTShapeConvertToBSplineAdvanced and OCCTShapeCustomDirectModification.
for WHICH in ConvertToBSpline DirectModification TrsfModification BSplineRestriction; do
  for FIX in bare barewithwire compound withwire box; do
    run_case modifier "$WHICH" "$FIX" no
  done
done

# Step 4: the duplicate question. Do the three ConvertToBSpline spellings agree, on a shape healthy
# enough to convert? Measured on a cylinder, which has one convertible lateral face and two planar
# caps the default flags leave alone, and on a compound of two cylinders, which is the input
# ShapeCustom::ApplyModifier's per-child recursion exists for.
for FIX in cylinder twocylinders box; do
  run_case equivalence "$FIX"
done

echo
echo "artifacts left in $WORK"
