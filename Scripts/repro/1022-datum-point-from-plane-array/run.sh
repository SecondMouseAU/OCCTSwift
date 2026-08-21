#!/usr/bin/env bash
# #1022: build and run the reproducer against the pinned kernel as shipped, and with the patched
# XCAFDoc_Datum.cxx override-linked ahead of the archive.
#
#   ./run.sh before      # pinned kernel, unpatched
#   ./run.sh after       # patch 0029 applied to a scratch copy, override-linked
#   ./run.sh both        # both, in that order (default)
#
# Sections C and D dereference the null handle and abort their process, so each lane runs the probe
# three times, once for AB and once for each crashing section. The probe installs its own
# SIGSEGV/SIGBUS handler, which prints the stage and exits 86, so the transcript reads rather than
# the shell reporting a bare signal AND a crash stays a status the caller can act on: the BEFORE
# lane tolerates 86 because it is the defect, the AFTER lane fails on it because it would be a
# regression.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
XCF="$REPO/Libraries/OCCT.xcframework/macos-arm64"
SRCDIR="$REPO/Libraries/occt-src/src/DataExchange/TKXCAF/XCAFDoc"
PATCHFILE="$REPO/Scripts/patches/0029-XCAFDoc_Datum-point-read-from-plane-array-1022.patch"
OUT="${OUT:-$HERE/out}"
mkdir -p "$OUT"

if [ ! -d "$XCF/Headers" ]; then
  echo "no local OCCT.xcframework at $XCF; symlink Libraries/ from the main checkout" >&2
  exit 2
fi
if [ ! -f "$SRCDIR/XCAFDoc_Datum.cxx" ]; then
  echo "no OCCT sources at $SRCDIR; Libraries/occt-src is gitignored, run Scripts/build-occt.sh" >&2
  exit 2
fi

CXXFLAGS=(-std=c++17 -w -O0 -g -I"$XCF/Headers")
LDFLAGS=(-L"$XCF" -lOCCT-macos -framework Foundation -framework AppKit -lz)

run_before() {
  echo "########## BEFORE: pinned kernel, no override ##########"
  clang++ "${CXXFLAGS[@]}" -c "$HERE/occt_1022_datum_point.cxx" -o "$OUT/probe.o"
  clang++ "${CXXFLAGS[@]}" "$OUT/probe.o" "${LDFLAGS[@]}" -o "$OUT/probe_before"
  # 86 is the probe's crash exit, and here it is the expected result.
  "$OUT/probe_before" AB || true
  echo
  "$OUT/probe_before" C || true
  echo
  "$OUT/probe_before" D || true
}

run_after() {
  echo "########## AFTER: patch 0029 override-linked ##########"
  rm -rf "$OUT/patched"
  mkdir -p "$OUT/patched/src/DataExchange/TKXCAF/XCAFDoc"
  cp "$SRCDIR/XCAFDoc_Datum.cxx" "$OUT/patched/src/DataExchange/TKXCAF/XCAFDoc/"
  ( cd "$OUT/patched" && patch -p1 --silent < "$PATCHFILE" )
  clang++ "${CXXFLAGS[@]}" \
    -c "$OUT/patched/src/DataExchange/TKXCAF/XCAFDoc/XCAFDoc_Datum.cxx" -o "$OUT/override.o"
  clang++ "${CXXFLAGS[@]}" -c "$HERE/occt_1022_datum_point.cxx" -o "$OUT/probe_patched.o"
  clang++ "$OUT/override.o" "$OUT/probe_patched.o" "${LDFLAGS[@]}" -o "$OUT/probe_after"
  # No `|| true` here: a crash under `set -e` fails the lane, which is the point of running it.
  "$OUT/probe_after" AB
  echo
  "$OUT/probe_after" C
  echo
  "$OUT/probe_after" D
}

case "${1:-both}" in
  before) run_before ;;
  after)  run_after ;;
  both)   run_before; echo; run_after ;;
  *) echo "usage: $0 [before|after|both]" >&2; exit 2 ;;
esac
