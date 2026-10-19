#!/bin/bash
# usage: stage.sh <occt-src> <unzipped OCCT.xcframework> <out-dir> <patch>...
# Compile the translation units the given patches change (-O2 -DNDEBUG -DNo_Exception, the build
# flags of the shipped slice) from a patched <occt-src>, and swap them into a copy of the
# framework's macos-arm64 library with `ar r`. Minutes, not the hour of build-occt.sh; the full
# build is kernel-integration.yml. The patched headers go first on the include path.
# Output: <out-dir>/xcf/macos-arm64/{libOCCT-macos.a,Headers -> framework headers}.
set -eu
SRC=$(cd "$1" && pwd)
K=$(cd "$2" && pwd)/macos-arm64
mkdir -p "$3"
OUT=$(cd "$3" && pwd)
shift 3
mkdir -p "$OUT/obj" "$OUT/ovl" "$OUT/xcf/macos-arm64"
cp "$K/libOCCT-macos.a" "$OUT/xcf/macos-arm64/"
ln -sfn "$K/Headers" "$OUT/xcf/macos-arm64/Headers"
# `+worktree` stands for the files the working tree of <occt-src> has changed since its HEAD
FILES=$(for p in "$@"; do
  if [ "$p" = "+worktree" ]; then git -C "$SRC" diff --name-only HEAD
  else git -C "$SRC" apply --numstat "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")" | cut -f3; fi
done | sort -u)
for f in $FILES; do case $f in *.hxx|*.lxx|*.pxx) cp "$SRC/$f" "$OUT/ovl/";; esac; done
cd "$OUT/obj"
rm -f ./*.o
pids=""
for f in $FILES; do
  case $f in *.cxx) ;; *) continue;; esac
  clang++ -std=c++17 -O2 -DNDEBUG -DNo_Exception -DOCCT_NO_PLUGINS -arch arm64 -mmacosx-version-min=12.0 \
    -fPIC -w -I "$OUT/ovl" -I "$K/Headers" -c "$SRC/$f" -o "$(basename "$f").o" &
  pids="$pids $!"
done
for p in $pids; do wait "$p"; done
ar r "$OUT/xcf/macos-arm64/libOCCT-macos.a" ./*.o 2>/dev/null
echo "swapped $(ls ./*.o | wc -l) objects"
