#!/usr/bin/env bash
# #1502 finding 1: build and run the Darboux-trihedron probe against the pinned OCCT.xcframework,
# once with the original (buggy) SetCurve pattern and once with the fixed one.
#
#   ./run.sh old   # original bridge code: plain BRepAdaptor_Curve -> SetCurve -> D0
#   ./run.sh new   # fixed bridge code: real Adaptor3d_CurveOnSurface -> SetCurve -> D0
#   ./run.sh both  # both, in that order (default)
#
# This is a bridge-only fix (no OCCT kernel patch), so there is nothing to override-link: both
# lanes compile the exact call sequence OCCTGeomFillDarbouxTrihedron used before/after the fix,
# straight against the pinned OCCT.xcframework. The probe installs its own SIGBUS/SIGSEGV handler
# and exits 86 on a crash, so a crash reads as a transcript line rather than a bare shell signal.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
XCF="$REPO/Libraries/OCCT.xcframework/macos-arm64"
OUT="${OUT:-$HERE/out}"
mkdir -p "$OUT"

if [ ! -d "$XCF/Headers" ]; then
  echo "no local OCCT.xcframework at $XCF; symlink Libraries/ from the main checkout" >&2
  exit 2
fi

clang++ -std=c++17 -ObjC++ -w -O0 -g -I"$XCF/Headers" \
  "$HERE/occt_1502_darboux_crash.mm" \
  -L"$XCF" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  -o "$OUT/probe"

run_old() {
  echo "########## OLD: plain BRepAdaptor_Curve handed to GeomFill_Darboux::SetCurve ##########"
  # 86 (the probe's crash exit) is the expected result here -- that is the defect.
  "$OUT/probe" old
  local status=$?
  echo "exit: $status"
  return 0
}

run_new() {
  echo "########## NEW: real Adaptor3d_CurveOnSurface handed to SetCurve ##########"
  "$OUT/probe" new
  local status=$?
  echo "exit: $status"
  if [ "$status" -ne 0 ]; then
    echo "FAIL: fixed path did not succeed (exit $status)" >&2
    return 1
  fi
  return 0
}

case "${1:-both}" in
  old)  run_old ;;
  new)  run_new ;;
  both) run_old; echo; run_new ;;
  *) echo "usage: $0 [old|new|both]" >&2; exit 2 ;;
esac
