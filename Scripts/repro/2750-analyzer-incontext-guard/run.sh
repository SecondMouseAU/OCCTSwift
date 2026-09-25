#!/bin/bash
# Regenerates the #2750 test fixture and prints the measurement that justifies its predicate.
#
# Usage, from the repository root:
#   Scripts/repro/2750-analyzer-incontext-guard/run.sh [path/to/OCCT.xcframework/macos-arm64]
#
# With no argument it looks for the pinned asset SwiftPM resolved under .build/artifacts, and falls
# back to a checked-in Libraries/OCCT.xcframework if one is present.
#
# It overwrites Tests/OCCTStressTests/Fixtures/brepcheck-incontext-pcurve-only-edge.brep, which is
# committed: the .brep is the deliverable, and this script is how it was made.

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

BIN="${TMPDIR:-/tmp}/occt_make_fixture_2750"
OUT="$ROOT/Tests/OCCTStressTests/Fixtures/brepcheck-incontext-pcurve-only-edge.brep"

echo "xcframework: $XCF"
echo "compiling..."
clang++ -std=c++17 -ObjC++ -w \
  -I"$XCF/Headers" \
  -L"$XCF" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  "$HERE/make-fixture.mm" -o "$BIN" || exit 1

echo
"$BIN" "$OUT"
echo "[exit $?]"

SIGBIN="${TMPDIR:-/tmp}/occt_signal_probe_2750"
echo
echo "compiling signal-probe..."
clang++ -std=c++17 -ObjC++ -g -O0 -w \
  -I"$XCF/Headers" \
  -L"$XCF" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  "$HERE/signal-probe.mm" -o "$SIGBIN" || exit 1

# One process per case: the first is expected to take its own process with it.
for CASE in without-setsignal with-setsignal; do
  echo
  echo "--------------------------------------------------------------------------"
  "$SIGBIN" "$CASE" "$OUT" 2>&1
  echo "[exit $?]"
done
