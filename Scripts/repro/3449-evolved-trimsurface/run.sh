#!/usr/bin/env bash
# Builds probe.cpp against the repo's xcframework and runs it. Arguments: px py face(0|1).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
XCF="$REPO/Libraries/OCCT.xcframework/macos-arm64"
OUT="${OUT:-$HERE/out}"
mkdir -p "$OUT"
clang++ -std=c++17 -w -O0 -g -I"$XCF/Headers" "$HERE/probe.cpp" -L"$XCF" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -o "$OUT/probe"
"$OUT/probe" "$@"
