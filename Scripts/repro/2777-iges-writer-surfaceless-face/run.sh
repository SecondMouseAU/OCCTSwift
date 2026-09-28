#!/bin/bash
# Runs the #2777 measurement: where IGESControl_Writer::AddShape faults on a surface-less face, and
# whether the fault needs the face to be edgeless the way #2773's did.
#
# Usage, from the repository root:
#   Scripts/repro/2777-iges-writer-surfaceless-face/run.sh [path/to/OCCT.xcframework/macos-arm64]
#
# With no argument it looks for the pinned asset SwiftPM resolved under .build/artifacts, and falls
# back to a checked-in Libraries/OCCT.xcframework if one is present.
#
# Every case runs in its OWN process, because a reproducing case is uncatchable and takes the rest
# of the transcript with it. That is the pattern from
# Scripts/repro/2773-shapedivide-surfaceless-face/run.sh.
#
# It also overwrites the committed fixture the Swift regression suite reads,
# Tests/OCCTStressTests/Fixtures/surfaceless-face-with-wire.brep: the file is the deliverable, and
# this script is how it was made. The other two fixtures that suite reads belong to #2773 and are
# written by that directory's run.sh, not this one.

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

WORK="${TMPDIR:-/tmp}/occt_2777"
mkdir -p "$WORK"
BIN="$WORK/probe"
FIXTURES="$ROOT/Tests/OCCTStressTests/Fixtures"
WITHWIRE="$FIXTURES/surfaceless-face-with-wire.brep"

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

rm -f "$WORK"/*.igs "$WORK"/*.step "$WORK"/*.brep

run_case describe

# Step 0: the baseline. The pin carries patch 0042, so #2773's divide rows must now report FAIL2
# rather than exiting 139. If they still exit 139, the pin is not what Package.swift says it is.
run_case divide compound no
run_case divide withwire no

# Step 1: the export, at both write modes the bridge uses (0 = Faces, 1 = BRep), both signal
# dispositions, and every fixture. `withwire` is the row that decides the predicate.
for FIX in box compound bare withwire barewithwire; do
  for MODE in 0 1; do
    for SIG in no yes; do
      run_case iges-write "$FIX" "$MODE" "$SIG" "$WORK/$FIX-$MODE-$SIG.igs"
    done
  done
done

# Step 1b: the gate that already stands in front of all five bridge export functions. It decides
# whether the fault above is reachable from Swift at all, and on two fixtures it is the fault.
for FIX in box compound bare withwire barewithwire; do
  run_case analyzer "$FIX"
done

# Step 2: narrowing the fault to the shape processor rather than to BRepToIGES.
for FIX in compound withwire bare barewithwire box; do
  run_case processshape "$FIX" no
  run_case processshape "$FIX" yes
done

# Step 3: down to the frame. ShapeCustom::DirectFaces with no writer above it at all, then
# ShapeCustom_DirectModification::NewSurface, whose first two statements are the whole fault.
for FIX in compound withwire bare barewithwire box; do
  run_case directfaces "$FIX" no
  run_case directfaces "$FIX" yes
done
for FIX in bare barewithwire; do
  run_case newsurface "$FIX" no
  run_case newsurface "$FIX" yes
done

# Step 3a: the rest of the ShapeCustom family, which the bridge also wraps. Each of these drives its
# own BRepTools_Modification subclass with its own NewSurface, so this is a separate question from
# DirectFaces' line, asked of every fixture because the answer decides three more guarded sites.
for OP in ScaleShape SweptToElementary ConvertToRevolution ConvertToBSpline BSplineRestriction; do
  for FIX in compound withwire bare barewithwire box; do
    run_case shapecustom "$OP" "$FIX" no
  done
done

# Step 3b: which of the writer's two layers is unsafe. BRepToIGES on its own guards the surface it
# reads, so a FORWARD surface-less face survives it; its REVERSED branch does not.
for FIX in bare barewithwire barereversed box; do
  run_case transferface "$FIX" no
done

# Step 4: the STEP answer #2777 asks for. Write, then read back what survived.
for FIX in compound withwire bare barewithwire box; do
  run_case step-write "$FIX" no "$WORK/$FIX.step"
  if [ -f "$WORK/$FIX.step" ]; then
    run_case step-read "$WORK/$FIX.step"
  fi
done

# Step 5: the committed fixture for the Swift regression suite, and the proof it round-trips with
# the state intact.
run_case brep-write withwire "$WITHWIRE"
run_case describe-file "$WITHWIRE"

echo
echo "artifacts left in $WORK"
