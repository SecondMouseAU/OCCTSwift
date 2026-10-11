#!/bin/bash
# Link gprobe against a released kernel, overriding the TKFillet translation units of a patched tree.
#   build.sh <patched TKFillet tree root (the dir holding src/)> <xcframework macos-arm64 dir> <out> [TU ...]
# TU = <Package>/<name> under src/ModelingAlgorithms/TKFillet (default: every .cxx of ChFi3d and BRepFilletAPI, so
# every unit that sees the patched headers is compiled from the same tree). OVERRIDE=none links the release untouched.
# No cmake, no full kernel rebuild.
set -e
SRC=$1; XC=$2; OUT=$3; shift 3
HERE=$(cd "$(dirname "$0")" && pwd)
T=$SRC/src/ModelingAlgorithms/TKFillet
if [ "$OVERRIDE" = none ]; then TUS=""; else
  TUS=${@:-$(cd $T && ls ChFi3d/*.cxx BRepFilletAPI/*.cxx | sed 's/\.cxx$//')}; fi
mkdir -p "$OUT.obj"; rm -f "$OUT.obj"/*.o
pids=""
for tu in $TUS; do
  pkg=${tu%/*}; n=${tu##*/}
  clang++ -arch arm64 -mmacosx-version-min=12.0 -std=c++17 -w -O2 -DNDEBUG -I"$T/ChFi3d" -I"$T/$pkg" -I"$XC/Headers" \
    -c "$T/$pkg/$n.cxx" -o "$OUT.obj/$n.cxx.o" & pids="$pids $!"
done
for p in $pids; do wait $p; done
clang++ -arch arm64 -mmacosx-version-min=12.0 -std=c++17 -w -O1 -I"$XC/Headers" "${PROBE:-$HERE/gprobe.cxx}" $(ls "$OUT.obj"/*.o 2>/dev/null) \
  -L"$XC" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o "$OUT"
