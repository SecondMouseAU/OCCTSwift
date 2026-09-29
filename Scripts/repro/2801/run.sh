#!/bin/bash
# #2801: compile and run probe.mm twice, once as SwiftPM compiles the bridge and once as OCCT's
# cmake compiles the kernel. The difference between the two runs is the finding.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
xc="${OCCT_XCFRAMEWORK:-$repo/Libraries/OCCT.xcframework}"
out="${TMPDIR:-/tmp}"

if [ ! -d "$xc/macos-arm64/Headers" ]; then
  echo "no xcframework at $xc; set OCCT_XCFRAMEWORK to one (a sibling checkout's is fine)" >&2
  exit 2
fi

build () {
  clang++ -std=c++17 -ObjC++ -w \
    -I"$xc/macos-arm64/Headers" -L"$xc/macos-arm64" \
    -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
    "$@" "$here/probe.mm"
}

build -o "$out/probe_2801"
build -DNo_Exception -o "$out/probe_2801_noexc"

status=0
"$out/probe_2801" || status=1
echo
"$out/probe_2801_noexc" || status=1
exit $status
