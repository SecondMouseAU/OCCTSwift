#!/usr/bin/env bash
# #2879: run probe.mm once per deflection value, each in its own process under a timeout.
#
# A hang is not catchable in-process (OCC_CATCH_SIGNALS is inert in this build and a spin raises
# nothing at all), so the timeout has to be external. 60 s is generous: a valid request on this
# fixture returns in well under a second.
#
# Usage: Scripts/repro/2879/run.sh        # from the repo root
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

BIN="${TMPDIR:-/tmp}/occt_probe_2879"
clang++ -std=c++17 -ObjC++ -w \
  -I"$XC/macos-arm64/Headers" \
  -L"$XC/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2879/probe.mm -o "$BIN" || exit 1

TIMEOUT=60
for v in 0.1 1e-7 9e-8 1e-12 0.0 -1.0 nan; do
  echo "=== deflection $v ==="
  # No coreutils `timeout` on a stock macOS, so drive the clock from the shell.
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
