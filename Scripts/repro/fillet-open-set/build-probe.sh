#!/bin/bash
# build-probe.sh <macos-arm64 slice dir of an OCCT.xcframework> <outdir> : build every program here against it.
# Example: build-probe.sh Libraries/OCCT.xcframework/macos-arm64 /tmp/probes
set -e
XC=$1; OUT=${2:-.}; HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
for src in dprobe pr_ports offprobe histprobe occt1371 occt1431 occt1494; do
  clang++ -std=c++17 -Wno-deprecated-declarations -O1 -I"$XC/Headers" "$HERE/$src.cxx" -L"$XC" -lOCCT-macos \
    -framework Foundation -framework AppKit -lz -lc++ -o "$OUT/$src"
done
