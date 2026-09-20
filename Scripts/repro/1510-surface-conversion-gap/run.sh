#!/usr/bin/env bash
# Compiles and runs both ground-truth probes for #1510 against the pinned
# OCCT.xcframework. Run from the repo root (or pass REPO_ROOT).
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
HEADERS="$REPO_ROOT/Libraries/OCCT.xcframework/macos-arm64/Headers"
LIB="$REPO_ROOT/Libraries/OCCT.xcframework/macos-arm64"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for name in occt_1510_periodic_gap occt_1510_periodic_gap_perturbed; do
  echo "=== $name ==="
  clang++ -std=c++17 -ObjC++ -w \
    -I"$HEADERS" -L"$LIB" \
    -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
    "$DIR/$name.mm" -o "/tmp/$name"
  "/tmp/$name" || true
  echo
done
