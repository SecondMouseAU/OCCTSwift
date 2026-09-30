#!/usr/bin/env bash
# #2884: run every probe mode in its own process, so a fault in one does not hide the next.
#
# The kernel under test is the PINNED one (v4.0.0-kernel.3), resolved by SwiftPM into
# .build/artifacts/, not Libraries/OCCT.xcframework, which in a main checkout can lag the pin
# (feedback-local-xcframework-can-lag-remote-pin). Run `swift build` once first.
#
#   Scripts/repro/2884/run.sh            # every mode
#   Scripts/repro/2884/run.sh 5 6 33     # just these
set -u

cd "$(dirname "$0")/../../.." || exit 1
ROOT=$(pwd)

XC=$(find "$ROOT/.build/artifacts" -maxdepth 3 -name OCCT.xcframework -type d 2>/dev/null | head -1)
if [ -z "$XC" ]; then
  XC="$ROOT/Libraries/OCCT.xcframework"
  echo "WARNING: no resolved artifact under .build/artifacts; falling back to $XC," >&2
  echo "         which may not be the kernel Package.swift pins." >&2
fi
echo "kernel: $XC"

BIN=${TMPDIR:-/tmp}/occt_probe_2884
clang++ -std=c++17 -ObjC++ -w \
  -I"$XC/macos-arm64/Headers" \
  -L"$XC/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  "$ROOT/Scripts/repro/2884/probe.mm" -o "$BIN" || exit 1

MODES=${*:-"1 2 3 4 5 6 7 8 9 10 12 20 21 22 23 30 31 33 34 35 36 37 38"}
for m in $MODES; do
  echo "=============================================================== mode $m"
  "$BIN" "$m"
  rc=$?
  [ $rc -ne 0 ] && echo "*** mode $m exited $rc ***"
done
