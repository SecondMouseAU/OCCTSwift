#!/bin/bash
# Compiles occt_1190_test.mm alongside the REAL Sources/OCCTBridge/src/OCCTBridge_HLR.mm (not a
# copy of it) against the pinned xcframework, and runs it. See occt_1190_test.mm's header comment
# and README.md for what this proves and why it can't be a Swift-level test.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

OUT="/tmp/occt_1190_test"

# Prefer a checked-out Libraries/OCCT.xcframework (main checkout); fall back to the artifact
# SwiftPM resolved under .build (linked worktrees don't get their own Libraries/ tree, see
# CLAUDE.md / the worktree-local-xcframework memory notes).
XCFW="Libraries/OCCT.xcframework"
if [ ! -d "$XCFW" ]; then
  XCFW=$(find .build/artifacts -maxdepth 3 -iname "OCCT.xcframework" | head -1)
fi
SLICE="$XCFW/macos-arm64"

clang++ -std=c++17 -ObjC++ -w \
  -I"$SLICE/Headers" \
  -I"Sources/OCCTBridge/include" \
  -I"Sources/OCCTBridge/src" \
  -L"$SLICE" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Sources/OCCTBridge/src/OCCTBridge_HLR.mm \
  Scripts/repro/1190-drawinggetedges-guard-helper/occt_1190_test.mm \
  -o "$OUT"

"$OUT"
