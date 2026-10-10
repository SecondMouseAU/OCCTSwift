#!/bin/bash
# Override-link the three changed kernel files against a released kernel, then link a probe.
#   build.sh <occt-src patched with Scripts/patches/*.patch> <kernel xcframework macos-arm64 dir> <probe.cxx> <out>
# The three .cxx files are compiled from the patched tree; headers come from the xcframework except
# ChFi3d_Builder_0.hxx, which the patch changes, so its directory goes first. No cmake, no full rebuild.
set -e
SRC=$1; XC=$2; PROBE=$3; OUT=$4
mkdir -p "$OUT.obj"
for tu in ChFi3d_Builder_C1 ChFi3d_Builder ChFi3d_Builder_0; do
  clang++ -std=c++17 -w -O1 -I"$SRC/src/ModelingAlgorithms/TKFillet/ChFi3d" -I"$XC/Headers" -c \
    "$SRC/src/ModelingAlgorithms/TKFillet/ChFi3d/$tu.cxx" -o "$OUT.obj/$tu.cxx.o"
done
clang++ -std=c++17 -w -O1 -I"$XC/Headers" "$PROBE" "$OUT.obj"/*.o -L"$XC" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ -o "$OUT"
