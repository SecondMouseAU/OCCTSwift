#!/bin/bash
# #3029: build the probe against an OCCT xcframework and run its scenarios, one process each, printing
# for every one how many lines OCCT put on stdout and what the recording printer saw.
#
#   run.sh [--xcframework DIR]
#
# Default kernel: $OCCT_XCFRAMEWORK, then SwiftPM's resolved asset under .build/artifacts, then
# Libraries/OCCT.xcframework. Which one it read is printed first. Built in a temporary directory that
# is removed on exit; nothing is written to the repository. macOS arm64 only, like every probe here.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
XC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --xcframework) XC="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$XC" ]; then
  if [ -n "${OCCT_XCFRAMEWORK:-}" ]; then
    XC="$OCCT_XCFRAMEWORK"
  else
    for c in "$REPO"/.build/artifacts/*/OCCT/OCCT.xcframework "$REPO/Libraries/OCCT.xcframework"; do
      if [ -d "$c/macos-arm64" ]; then XC="$c"; break; fi
    done
  fi
fi
if [ -z "$XC" ] || [ ! -f "$XC/macos-arm64/libOCCT-macos.a" ]; then
  echo "no OCCT.xcframework found; pass --xcframework" >&2
  exit 2
fi
echo "kernel: $XC"
echo "libOCCT-macos.a: sha256 $(shasum -a 256 "$XC/macos-arm64/libOCCT-macos.a" | cut -d' ' -f1)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/occt3029.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
clang++ -std=c++17 -ObjC++ -w -O0 -I"$XC/macos-arm64/Headers" -c "$HERE/probe.mm" -o "$TMP/probe.o"
clang++ -arch arm64 "$TMP/probe.o" -L"$XC/macos-arm64" -lOCCT-macos -framework Foundation \
  -framework AppKit -lz -lc++ -o "$TMP/probe" 2>&1 | grep -v "duplicate libraries" || true

scenario() {
  label="$1"
  shift
  "$TMP/probe" "$@" > "$TMP/out.txt" 2> "$TMP/err.txt" || true
  printf '%-44s stdout lines %2d   %s\n' "$label" "$(wc -l < "$TMP/out.txt" | tr -d ' ')" \
    "$(grep '^messages sent' "$TMP/err.txt" | sed 's/messages sent to the default messenger: //')"
}

echo
scenario "STEPControl_Writer, as OCCT ships it" write
scenario "  default printers at trace level warning" write --trace warning
scenario "  default printers at trace level fail" write --trace fail
scenario "  the issue's proposal: a writer-local messenger" write --per-writer
scenario "STEPCAFControl_Writer (an XDE document)" write-caf
scenario "  default printers at trace level warning" write-caf --trace warning
scenario "IGESControl_Writer" write-iges
scenario "STEPControl_Reader on a malformed file" read-bad
scenario "  default printers at trace level warning" read-bad --trace warning

echo
echo "what the writer-local messenger leaves on stdout:"
"$TMP/probe" write --per-writer 2> /dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -v '^$' | sed 's/occt3029\.[A-Za-z0-9]*/occt3029.XXXXXX/; s/^/  /'
echo
echo "what the same trace level leaves of a genuine failure (a malformed STEP file, level warning):"
"$TMP/probe" read-bad --trace warning 2> /dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -v '^$' | sed 's/^/  /'
echo
echo "gravity of each message of one STEPControl_Writer write:"
"$TMP/probe" write 2>&1 > /dev/null | grep '^  \[' | sed 's/occt3029\.[A-Za-z0-9]*/occt3029.XXXXXX/; s/^\(.\{150\}\).*/\1.../'
