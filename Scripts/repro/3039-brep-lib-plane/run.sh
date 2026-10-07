#!/bin/bash
# #3039: build the probe against an OCCT xcframework and count what N fresh processes do.
#
#   Scripts/repro/3039-brep-lib-plane/run.sh [--runs N] [--xcframework DIR] [--occt-src DIR]
#
# Four rows per thread count, each in N fresh processes (default 3000; the race can only happen on
# the first BRepLib::Plane() call of a process, so one process is one draw):
#
#   asset    the archive as shipped: the kernel a consumer runs
#   control  the UNMODIFIED BRepLib.cxx from --occt-src recompiled with the kernel's flags and linked
#            ahead of the archive. It shows the same defect as `asset`, at a higher rate (the flags
#            are CMake's Release flags as far as they can be reproduced here, not the same
#            binary), which is what shows the override toolchain is not what creates the race.
#   patched  the same file with Scripts/patches/0056-*.patch applied to a copy
#   warm     control, but BRepLib::Plane() is called once on the main thread before the threads
#            start: the control for "the lazy initialisation is the cause"
#
# Exits 1 unless `control` shows the defect (any non-clean process at 16 threads) and `patched` and
# `warm` are clean at both thread counts. Built in a temporary directory that is removed on exit;
# nothing is written to the repository. macOS arm64 only, like every probe here.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
RUNS=3000
XC="$REPO/Libraries/OCCT.xcframework/macos-arm64"
SRC="$REPO/Libraries/occt-src"
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) RUNS=$2; shift 2 ;;
    --xcframework) XC=$2/macos-arm64; shift 2 ;;
    --occt-src) SRC=$2; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

FILE=src/ModelingAlgorithms/TKTopAlgo/BRepLib/BRepLib.cxx
PATCH=$(echo "$REPO"/Scripts/patches/0056-*.patch)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
# The kernel is a Release build for arm64 macOS 12; -O3 -DNDEBUG is what CMake's Release adds.
FLAGS=(-std=c++17 -w -O3 -DNDEBUG -arch arm64 -mmacosx-version-min=12.0 -I"$XC/Headers")
LINK=(-L"$XC" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++)

echo "== kernel: $XC/libOCCT-macos.a"
shasum -a 256 "$XC/libOCCT-macos.a"

# Two trees, each a git repo of one file: the file as V8_0_1 has it, and with 0056 applied.
for v in control patched; do
  mkdir -p "$OUT/tree-$v/$(dirname $FILE)"
  cp "$SRC/$FILE" "$OUT/tree-$v/$FILE"
  ( cd "$OUT/tree-$v" && git init -q . )
done
if ( cd "$OUT/tree-control" && git apply --check -R "$PATCH" ) 2>/dev/null; then
  ( cd "$OUT/tree-control" && git apply -R "$PATCH" )   # --occt-src already carries 0056
  echo "(--occt-src already holds 0056; reversed on the control copy)"
fi
( cd "$OUT/tree-patched" && git apply --check "$PATCH" 2>/dev/null && git apply "$PATCH" || true )
grep -q 'thePlane()' "$OUT/tree-patched/$FILE" && echo "patched copy carries 0056" || { echo "0056 not applied"; exit 2; }
! grep -q 'thePlane()' "$OUT/tree-control/$FILE" || { echo "control copy still has 0056"; exit 2; }

for v in control patched; do clang++ "${FLAGS[@]}" -c "$OUT/tree-$v/$FILE" -o "$OUT/$v.o"; done
clang++ "${FLAGS[@]}" "$HERE/probe.cxx" "${LINK[@]}" -o "$OUT/asset"
for v in control patched; do clang++ "${FLAGS[@]}" "$HERE/probe.cxx" "$OUT/$v.o" "${LINK[@]}" -o "$OUT/$v"; done

# row <label> <binary> <threads> [warm]: one line of counts; sets rc to the harness exit (0 = all clean)
row() { rc=0; printf "%-8s " "$1"; python3 "$HERE/harness.py" "$RUNS" "${@:2}" || rc=$?; }
verdict=0
for t in 4 16; do
  echo "== $t threads"
  row asset "$OUT/asset" "$t"
  row control "$OUT/control" "$t"
  [ "$t" = 16 ] && [ "$rc" = 0 ] && { echo "control showed no defect at 16 threads"; verdict=1; }
  row patched "$OUT/patched" "$t"
  [ "$rc" = 0 ] || verdict=1
  row warm "$OUT/control" "$t" warm
  [ "$rc" = 0 ] || verdict=1
done
echo "== verdict: $([ $verdict = 0 ] && echo 'control fails, patched and warm are clean' || echo 'UNEXPECTED, see rows')"
exit $verdict
