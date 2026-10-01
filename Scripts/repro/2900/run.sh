#!/usr/bin/env bash
# #2900: run probe.mm once per angular-deflection value, each in its own process under a timeout.
#
# A non-returning mesh is not catchable in-process (OCC_CATCH_SIGNALS is inert in this build), so
# the timeout has to be external. 60 s is generous: a valid request on these fixtures returns in
# well under a second. Twin of Scripts/repro/2879/run.sh, which measures the linear half.
#
# Usage: Scripts/repro/2900/run.sh        # from the repo root
set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1

# SwiftPM names the artifacts directory after the package checkout, which in a worktree is the
# worktree's own name rather than "occtswift", so glob rather than hardcode it.
XC="$(find .build/artifacts -maxdepth 3 -name OCCT.xcframework -type d 2>/dev/null | head -1)"
if [ -z "$XC" ]; then
  XC="Libraries/OCCT.xcframework"
fi
if [ ! -d "$XC" ]; then
  echo "no xcframework found; run 'swift build' first" >&2
  exit 1
fi
echo "kernel: $XC"

BIN="${TMPDIR:-/tmp}/occt_probe_2900"
clang++ -std=c++17 -ObjC++ -w \
  -I"$XC/macos-arm64/Headers" \
  -L"$XC/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2900/probe.mm -o "$BIN" || exit 1

TIMEOUT=${TIMEOUT:-60}

run_case() {
  echo "=== angle $1  shape $2  mode $3  linear ${4:-0.1} ==="
  # No coreutils `timeout` on a stock macOS, so drive the clock from the shell.
  "$BIN" "$1" "$2" "$3" "${4:-0.1}" &
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
}

for shape in cylinder box; do
  for mode in ctor params; do
    for v in 0.5 9e-13 0.0 -1.0 nan; do
      run_case "$v" "$shape" "$mode"
    done
  done
done

# AngleInterior alone, Angle held valid: the branch initParameters rewrites rather than refuses.
for shape in cylinder box; do
  for v in 9e-13 0.0 -1.0 nan; do
    run_case "$v" "$shape" interior
  done
done

# Second sweep: a coarse linear deflection, so the ANGULAR criterion is the one deciding the
# tessellation. At linear 0.1 a cylinder of radius 10 is already subdivided finely enough by the
# linear rule that every valid angle gives the same node count, which hides what a NaN angle does.
for v in 0.05 0.2 0.5 1.0 nan; do
  run_case "$v" cylinder ctor 10.0
done

# And the same coarse-linear question for AngleInterior alone, with Angle held at 0.5, so the
# "does AngleInterior need its own guard" decision rests on a measurement rather than on reading
# the `params.angleInterior > 0` filter in OCCTShapeCreateMeshWithParams.
for v in 0.05 1.0 nan; do
  run_case "$v" cylinder interior 10.0
done
