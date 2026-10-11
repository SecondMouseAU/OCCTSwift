#!/bin/bash
# build-probe.sh <xcframework dir> <out> : compile cprobe.cxx against the macOS slice of an xcframework and link it.
set -e
XC=$1/macos-arm64; OUT=$2; HERE=$(cd "$(dirname "$0")" && pwd)
clang++ -std=c++17 -w -O1 -I"$XC/Headers" "$HERE/cprobe.cxx" -L"$XC" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o "$OUT"
