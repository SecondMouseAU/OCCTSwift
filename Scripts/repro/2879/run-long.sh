#!/usr/bin/env bash
# #2879, second sweep: the values that survived BRepMesh_IncrementalMesh::initParameters, given
# ten minutes each rather than one, so "did not return in 60 s" can be separated from "never
# returns". Same probe, same kernel, longer clock.
#
# Usage: Scripts/repro/2879/run-long.sh        # from the repo root
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1

XC="$(find .build/artifacts -maxdepth 3 -name OCCT.xcframework -type d 2>/dev/null | head -1)"
if [ -z "$XC" ]; then
  XC="Libraries/OCCT.xcframework"
fi
echo "kernel: $XC"

BIN="${TMPDIR:-/tmp}/occt_probe_2879"
clang++ -std=c++17 -ObjC++ -w \
  -I"$XC/macos-arm64/Headers" \
  -L"$XC/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2879/probe.mm -o "$BIN" || exit 1

TIMEOUT=${TIMEOUT:-600}
for v in 1e-4 1e-5 1e-6 1e-7 nan; do
  echo "=== deflection $v ==="
  "$BIN" "$v" &
  pid=$!
  waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$TIMEOUT" ]; do
    sleep 1
    waited=$((waited + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    echo "DID NOT RETURN within ${TIMEOUT}s (killed)"
  else
    wait "$pid"
    echo "exit=$?  after ${waited}s"
  fi
done
