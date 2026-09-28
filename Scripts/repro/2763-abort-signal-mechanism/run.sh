#!/bin/bash
# #2763: measures which branch of Standard_ErrorHandler::Abort the PINNED kernel took, two ways.
#
# Usage, from the repository root:
#   Scripts/repro/2763-abort-signal-mechanism/run.sh [path/to/OCCT.xcframework/macos-arm64]
#
# With no argument it looks for the pinned asset SwiftPM resolved under .build/artifacts, and
# falls back to a checked-in Libraries/OCCT.xcframework if one is present. Run `swift build`
# once first if neither exists.
#
# Part 1 reads the shipped archive: the OSD_signal object is the only translation unit that
# instantiates the Abort template, so which symbols it references settles which branch was
# compiled without running anything.
#
# Part 2 runs the three probe cases, one process each, because two of them are expected to end
# the process. Expected exit codes are checked rather than eyeballed.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"

XCF="${1:-}"
if [ -z "$XCF" ]; then
  XCF="$(find "$ROOT/.build/artifacts" -type d -path '*OCCT.xcframework/macos-arm64' 2>/dev/null | head -1)"
fi
if [ -z "$XCF" ] && [ -d "$ROOT/Libraries/OCCT.xcframework/macos-arm64" ]; then
  XCF="$ROOT/Libraries/OCCT.xcframework/macos-arm64"
fi
if [ -z "$XCF" ] || [ ! -d "$XCF" ]; then
  echo "No OCCT.xcframework found. Run 'swift build' once to resolve the pinned asset, or pass"
  echo "the macos-arm64 slice as the first argument."
  exit 2
fi

echo "xcframework: $XCF"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo
echo "=== part 1: what the shipped OSD_signal object references ==="
( cd "$WORK" && ar x "$XCF/libOCCT-macos.a" OSD_signal.cxx.o ) || exit 1
echo "--- the #else branch's own string, present only when OCC_CONVERT_SIGNALS was defined:"
strings "$WORK/OSD_signal.cxx.o" | grep -F "no catch was found" || echo "    (absent)"
echo "--- undefined symbols that tell the two branches apart:"
nm -u "$WORK/OSD_signal.cxx.o" | grep -E "FindHandler|longjmp" || echo "    (none: the throw branch)"

echo
echo "=== part 2: what the installed handler does at runtime ==="
for VARIANT in plain converts; do
  BIN="$WORK/abort-branch-probe-$VARIANT"
  DEFS=""
  [ "$VARIANT" = converts ] && DEFS="-DOCC_CONVERT_SIGNALS"
  # -O0 keeps the volatile null read where it was written.
  clang++ -std=c++17 -ObjC++ -g -O0 -w $DEFS \
    -I"$XCF/Headers" \
    -L"$XCF" \
    -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
    "$HERE/abort-branch-probe.mm" -o "$BIN" || exit 1
done

run_case() {
  local BIN="$1" CASE="$2" WANT="$3"
  echo
  echo "--------------------------------------------------------------------------"
  "$BIN" "$CASE" 2>&1
  local RC=$?
  if [ "$RC" = "$WANT" ]; then
    echo "[exit $RC, as expected]"
  else
    echo "[exit $RC, EXPECTED $WANT: the mechanism is not what this probe's README records]"
  fi
}

# 139 = 128 + SIGSEGV.
run_case "$WORK/abort-branch-probe-plain" bare-segv 139
# 1 = OCCT's own "no catch was found" exit, i.e. the longjmp branch with FindHandler() null.
run_case "$WORK/abort-branch-probe-plain" no-handler 1
# 3 = SKIPPED, because OCC_CATCH_SIGNALS is inert in a TU without the define. The bridge's own
# OCC_CATCH_SIGNALS is in exactly this state.
run_case "$WORK/abort-branch-probe-plain" with-handler 3
# 0 = the handler was found and the fault came back as a catchable Standard_Failure.
run_case "$WORK/abort-branch-probe-converts" with-handler 0
