#!/bin/bash
# Builds and runs every case of the #2746 probe, one process per case, and prints the exit status
# of each. A case that reproduces the defect kills its own process, which is why they cannot be
# sequenced inside one run: OCC_CATCH_SIGNALS is inert in this build.
#
# Usage, from the repository root:
#   Scripts/repro/2746-brepcheck-incontext-sigsegv/run.sh [path/to/OCCT.xcframework/macos-arm64]
#
# With no argument it looks for the pinned asset SwiftPM resolved under .build/artifacts, and falls
# back to a checked-in Libraries/OCCT.xcframework if one is present.

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

BIN="${TMPDIR:-/tmp}/occt_probe_2746"

echo "xcframework: $XCF"
echo "compiling..."
# -g -O0 so the SIGSEGV handler's backtrace names the faulting frame. lldb is unavailable here.
clang++ -std=c++17 -ObjC++ -g -O0 -w \
  -I"$XCF/Headers" \
  -L"$XCF" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  "$HERE/probe.mm" -o "$BIN" || exit 1

CASES="
healthy-edge-incontext
nulled-edge-incontext-face0
nulled-edge-incontext-face1
nulled-edge-no-minimum
nulled-edge-gctrl-off
nulled-edge-cylindrical-face
removed-rep-edge-incontext
fresh-edge-zero-reps
nulled-edge-detached
nulled-edge-vertex-incontext
nulled-edge-wire-incontext
healthy-edge-analyzer
nulled-edge-analyzer
brep-roundtrip-analyzer
downcast-corroboration
guard-predicate
"

for CASE in $CASES; do
  echo
  echo "--------------------------------------------------------------------------"
  "$BIN" "$CASE" 2>&1
  echo "[exit $?]"
done
