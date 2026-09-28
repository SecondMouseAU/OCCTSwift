#!/bin/bash
# Runs the #2773 reachability measurement: can a file carry a surface-less face, and does the
# reloaded shape still take the process down under ShapeUpgrade_ShapeDivide::Perform()?
#
# Usage, from the repository root:
#   Scripts/repro/2773-shapedivide-surfaceless-face/run.sh [path/to/OCCT.xcframework/macos-arm64]
#
# With no argument it looks for the pinned asset SwiftPM resolved under .build/artifacts, and falls
# back to a checked-in Libraries/OCCT.xcframework if one is present.
#
# Every case runs in its OWN process, because a reproducing case is uncatchable and takes the rest
# of the transcript with it. That is the pattern from
# Scripts/repro/2750-analyzer-incontext-guard/run.sh.
#
# It also overwrites the two committed fixtures the Swift regression suite reads,
# Tests/OCCTStressTests/Fixtures/shapedivide-surfaceless-edgeless-{face,bare-face}.brep: the files
# are the deliverable, and this script is how they were made.

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

WORK="${TMPDIR:-/tmp}/occt_2773"
mkdir -p "$WORK"
BIN="$WORK/probe"
FIXTURES="$ROOT/Tests/OCCTStressTests/Fixtures"
BREP="$FIXTURES/shapedivide-surfaceless-edgeless-face.brep"
BARE="$FIXTURES/shapedivide-surfaceless-edgeless-bare-face.brep"
BREPW="$WORK/surfaceless-withwire.brep"
STEP="$WORK/surfaceless.step"
IGES="$WORK/surfaceless.igs"

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

rm -f "$BREP" "$BARE" "$BREPW" "$STEP" "$IGES"

run_case describe

# Step 1: the .brep round trip, the case that turned #2746 into #2750's guarded call sites.
run_case brep-write "$BREP"
run_case brep-read "$BREP"
run_case brep-write-bare "$BARE"
run_case brep-read "$BARE"
run_case brep-write-withwire "$BREPW"
run_case brep-read "$BREPW"

# Step 2: STEP and IGES, the path a consumer's file actually takes.
run_case step-write "$STEP"
run_case step-read "$STEP"
run_case iges-write "$IGES"
run_case iges-read "$IGES"

# Step 3: the outcome that matters. In memory first (the known crash, both signal dispositions),
# then the shape read back off disk if the round trip produced one.
run_case divide-memory no
run_case divide-memory yes
run_case divide-memory-withwire no
run_case divide-memory-withwire yes
if [ -f "$BREP" ]; then
  run_case divide-file "$BREP" no
  run_case divide-file "$BREP" yes
fi
if [ -f "$BARE" ]; then
  run_case divide-file "$BARE" no
  run_case divide-file "$BARE" yes
fi
if [ -f "$BREPW" ]; then
  run_case divide-file "$BREPW" no
  run_case divide-file "$BREPW" yes
fi

# Step 4: which handler absorbs the fault. FaceDivide called directly, so
# ShapeUpgrade_ShapeDivide.cxx:190's OCC_CATCH_SIGNALS is not on the stack.
run_case facedivide-direct no
run_case facedivide-direct yes

# Step 5: the minimal reproducer, and how far the same fault reaches beyond the divide family.
run_case uvbounds no
run_case uvbounds yes
run_case shapefix no
run_case shapefix yes

echo
echo "artifacts left in $WORK"
