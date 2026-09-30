#!/usr/bin/env bash
# #2866: the four buffer-taking OCAF array setters and a reversed range.
#
# Point OCCT_XCFRAMEWORK at the PINNED asset, not at Libraries/OCCT.xcframework, which in a
# developer checkout is often a locally built kernel one repin behind. The pin at the time of
# measurement was v4.0.0-kernel.3, checksum
# 27810c46220a77303c322bc24119e3aa1fe983707e9f88ce8455e7e9b9db82bc. A `swift build` extracts it to
#   .build/artifacts/<package>/OCCT/OCCT.xcframework
# which is what this script defaults to before falling back to the checkout's own copy.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
if [ -z "${OCCT_XCFRAMEWORK:-}" ]; then
  PINNED="$(find "$ROOT/.build/artifacts" -maxdepth 3 -name OCCT.xcframework -type d 2>/dev/null | head -1)"
  OCCT_XCFRAMEWORK="${PINNED:-$ROOT/Libraries/OCCT.xcframework}"
fi
K="$OCCT_XCFRAMEWORK"
BIN="${TMPDIR:-/tmp}/probe-2866"

echo "kernel: $K"
set -x
clang++ -std=c++17 -ObjC++ -w \
  -I"$K/macos-arm64/Headers" \
  -L"$K/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  "$HERE/probe.mm" -o "$BIN" || exit 1
set +x

for m in byte-reversed boolean-reversed extstring-reversed reference-reversed \
         byte-minus-two \
         byte-empty boolean-empty extstring-empty reference-empty \
         roundtrip-bin-one roundtrip-bin-empty roundtrip-xml-one roundtrip-xml-empty; do
  echo "----- mode $m"
  "$BIN" "$m" 2>&1
  echo "exit=$?"
done
