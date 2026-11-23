#!/bin/bash
# #3509: BRepAlgoAPI_Check and BOPAlgo_CheckerSI SIGSEGV on a face with no surface that carries a
# wire, in IntTools_FaceFace.cxx's CorrectSurfaceBoundaries.
#
# Usage, from the repository root:
#   Scripts/repro/3509/run.sh <OCCT.xcframework> [patched-object.o ...]
#
# To measure the fix without a kernel rebuild, pass IntTools_FaceFace.cxx compiled with the
# kernel's own flags (it links ahead of the archive):
#   clang++ -std=c++17 -w -O3 -DNDEBUG -DNo_Exception -arch arm64 -I <xcf>/macos-arm64/Headers \
#     -c <patched tree>/src/ModelingAlgorithms/TKBO/IntTools/IntTools_FaceFace.cxx \
#     -o IntTools_FaceFace.cxx.o
#
# One process per case: a fault is uncatchable. Nothing here installs OSD::SetSignal, which the
# bridge does only after one of its entry points has run, so an unpatched kernel dies with 139 and
# not with a converted exception. The fixture belongs to #2777; this reads it.
set -u

XCF="${1:?usage: run.sh <OCCT.xcframework> [patched-object.o ...]}"
shift
K="$XCF/macos-arm64"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
FIXTURE="$ROOT/Tests/OCCTStressTests/Fixtures/surfaceless-face-with-wire.brep"
WORK="$(mktemp -d)"

clang++ -std=c++17 -w -g -I "$K/Headers" "$HERE/probe.cxx" "$@" -L "$K" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ -o "$WORK/probe" || exit 1

for c in check1 check2 fuse common cut section self; do
  ( "$WORK/probe" "$c" "$FIXTURE" > "$WORK/out.txt" 2>&1 )
  rc=$?
  printf "  %-8s exit=%-4s %s\n" "$c" "$rc" "$(grep -m1 -E 'IsValid|IsDone|HasErrors' "$WORK/out.txt")"
done 2>&1 | grep -v 'Segmentation fault'

rm -rf "$WORK"
