#!/usr/bin/env bash
# #2976: compile and run the IsURational/IsVRational axis probe against the pinned kernel.
#
# Run from the repo root. OCCT_XCFRAMEWORK overrides the xcframework location, which a linked
# worktree needs: a worktree's Libraries/ is its own tree and does not carry one.
set -euo pipefail

XC="${OCCT_XCFRAMEWORK:-Libraries/OCCT.xcframework}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${TMPDIR:-/tmp}/occt_2976_probe"

if [ ! -d "$XC/macos-arm64" ]; then
  echo "no xcframework at $XC; set OCCT_XCFRAMEWORK to a checkout that has one" >&2
  exit 2
fi

clang++ -std=c++17 -ObjC++ -w \
  -I"$XC/macos-arm64/Headers" \
  -L"$XC/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  "$HERE/probe.mm" -o "$OUT"

"$OUT"
