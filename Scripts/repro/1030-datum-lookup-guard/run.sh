#!/bin/bash
# #1030: build occt_1030_tool_table.mm against the REAL bridge objects and run its four sections.
#
# The bridge objects come from `swift build`, so this measures the tree as it stands: run it once
# with the guard in place and once with it removed to see the difference. Each section runs in its
# own process, because two of them take the process down when the guard is absent.
#
#   ./run.sh            all four sections
#   ./run.sh A          one section
#
# Requires a prior `OCCTSWIFT_LOCAL=1 swift build` so .build/ holds current bridge objects, and a
# local Libraries/OCCT.xcframework.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD="$REPO/.build/arm64-apple-macosx/debug"
OBJS="$BUILD/OCCTBridge.build/src"
BIN="${TMPDIR:-/tmp}/occt_1030_tool_table"

if [ ! -d "$OBJS" ]; then
  echo "no bridge objects at $OBJS; run 'OCCTSWIFT_LOCAL=1 swift build' first" >&2
  exit 2
fi

echo "== compiling against $(ls "$OBJS"/*.o | wc -l | tr -d ' ') bridge objects"
clang++ -std=c++17 -ObjC++ -w \
  -I"$REPO/Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -I"$REPO/Sources/OCCTBridge/include" \
  "$REPO/Scripts/repro/1030-datum-lookup-guard/occt_1030_tool_table.mm" \
  "$OBJS"/*.o \
  -L"$REPO/Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  -o "$BIN" || exit 1

run_section() {
  echo "-- section $1"
  "$BIN" "$1"
  local status=$?
  if [ $status -ge 128 ]; then
    echo "   exit $status (signal $((status - 128)))"
  else
    echo "   exit $status"
  fi
}

if [ $# -ge 1 ]; then
  run_section "$1"
else
  for s in A B C D; do run_section "$s"; done
fi
