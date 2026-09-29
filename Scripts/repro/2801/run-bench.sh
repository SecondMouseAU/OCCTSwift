#!/bin/bash
# #2801: time bench.mm with and without -DNo_Exception, at -O2, three runs each, interleaved so a
# thermal or load drift shows up as spread rather than as a difference between the two builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
xc="${OCCT_XCFRAMEWORK:-$repo/Libraries/OCCT.xcframework}"
out="${TMPDIR:-/tmp}"

if [ ! -d "$xc/macos-arm64/Headers" ]; then
  echo "no xcframework at $xc; set OCCT_XCFRAMEWORK to one" >&2
  exit 2
fi

build () {
  clang++ -std=c++17 -ObjC++ -w -O2 \
    -I"$xc/macos-arm64/Headers" -L"$xc/macos-arm64" \
    -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
    "$@" "$here/bench.mm"
}

build -o "$out/bench_2801_checks_on"
build -DNo_Exception -o "$out/bench_2801_checks_off"

for run in 1 2 3; do
  echo "=== run $run ==="
  "$out/bench_2801_checks_on"
  "$out/bench_2801_checks_off"
done
