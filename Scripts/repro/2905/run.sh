#!/usr/bin/env bash
# #2905: measure ComputeNormals and EnsureNormalConsistency against the pinned kernel, on a
# planar solid and two curved ones. The values this prints are the ones
# Tests/OCCTTopologyTests/BRepLib/BRepLibToolTriangulatedShapeTests.swift and BRepLibExtendedTests.swift
# pin, so re-run it before changing either of those expectations.
#
# Usage: Scripts/repro/2905/run.sh        # from the repo root
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

BIN="${TMPDIR:-/tmp}/occt_probe_2905"
clang++ -std=c++17 -ObjC++ -w \
  -I"$XC/macos-arm64/Headers" \
  -L"$XC/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2905/probe.mm -o "$BIN" || exit 1

for shape in box cylinder sphere; do
  echo "=== $shape ==="
  "$BIN" "$shape"
done
