#!/bin/bash
# usage: build.sh <OCCT.xcframework> <out-binary>
K=$1/macos-arm64
clang++ -std=c++17 -ObjC++ -w -g -I "$K/Headers" -L "$K" -lOCCT-macos -framework Foundation \
  -framework AppKit -lz -lc++ "$(dirname "$0")/probe.mm" -o "$2"
