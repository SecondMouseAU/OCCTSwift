#!/bin/bash
# Override-link changed kernel translation units against a released kernel, then link a probe.
#   build.sh <occt-src patched with Scripts/patches/*.patch> <xcframework macos-arm64 dir> <probe.cxx> <out> [TU ...]
# TUs are ChFi3d basenames (default: the three that patch 0059 changes). Each is compiled from the patched
# tree; headers come from the xcframework except those of ChFi3d/, which the patch changes, so that
# directory goes first. No cmake, no full kernel rebuild. With no TU given and OVERRIDE=none the probe is
# linked against the unmodified release.
set -e
SRC=$1; XC=$2; PROBE=$3; OUT=$4; shift 4
TUS=${@:-ChFi3d_Builder_C1 ChFi3d_Builder ChFi3d_Builder_0}
[ "$OVERRIDE" = none ] && TUS=""
mkdir -p "$OUT.obj"; rm -f "$OUT.obj"/*.o
for tu in $TUS; do
  clang++ -std=c++17 -w -O1 -I"$SRC/src/ModelingAlgorithms/TKFillet/ChFi3d" -I"$XC/Headers" -c \
    "$SRC/src/ModelingAlgorithms/TKFillet/ChFi3d/$tu.cxx" -o "$OUT.obj/$tu.cxx.o"
done
clang++ -std=c++17 -w -O1 -I"$XC/Headers" "$PROBE" $(ls "$OUT.obj"/*.o 2>/dev/null) -L"$XC" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ -o "$OUT"
