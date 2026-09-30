#!/usr/bin/env bash
# Compile and run the #2875 probe against the pinned kernel, one case per process so a case that
# corrupts or crashes does not hide the ones after it.
#
# Usage: Scripts/repro/2875/run.sh [path/to/OCCT.xcframework]
# With no argument it uses the xcframework SwiftPM resolved into .build/artifacts, which is the
# pin Package.swift names; Libraries/OCCT.xcframework in a checkout can be older than that pin.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"

xc="${1:-}"
if [ -z "$xc" ]; then
  xc="$(find "$root/.build/artifacts" -maxdepth 3 -type d -name OCCT.xcframework 2>/dev/null | head -1)"
fi
if [ -z "$xc" ] || [ ! -d "$xc" ]; then
  echo "no OCCT.xcframework found; run 'swift build' first, or pass a path" >&2
  exit 2
fi
echo "xcframework: $xc"

out="${TMPDIR:-/tmp}/occt_probe_2875"
clang++ -std=c++17 -ObjC++ -w \
  -I"$xc/macos-arm64/Headers" \
  -L"$xc/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  "$here/probe.mm" -o "$out" || exit 1

for c in 0 1 2 3 4 5 6; do
  echo "----------------------------------------------------------------------"
  "$out" "$c"
  rc=$?
  [ $rc -ne 0 ] && echo "  (case $c exited $rc)"
done
echo "----------------------------------------------------------------------"
