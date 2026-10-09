#!/bin/bash
# Compile kernel translation units from a patched occt-src and swap them into the macOS slice of an
# xcframework (a COPY, never the shared one): the quick route to run the Swift tests against a changed kernel.
#   swap-members.sh <occt-src> <xcframework dir> <TU ...>      TU = ChFi3d basename or <Package>/<name>
#   swap-members.sh --restore <pristine xcframework dir> <xcframework dir> <TU ...>   put the pristine members back
# The members keep their archive names (<name>.cxx.o). Flags follow Scripts/build-occt.sh (macOS, Release).
set -e
if [ "$1" = "--restore" ]; then
  PRISTINE=$2; XF=$3; shift 3; A=$XF/macos-arm64/libOCCT-macos.a; P=$PRISTINE/macos-arm64/libOCCT-macos.a
  T=$(mktemp -d); (cd "$T" && for tu in "$@"; do n=${tu##*/}; ar x "$P" "$n.cxx.o"; done && ar r "$A" *.o && ranlib "$A"); rm -rf "$T"; exit 0
fi
SRC=$1; XF=$2; shift 2
A=$XF/macos-arm64/libOCCT-macos.a; T=$(mktemp -d)
for tu in "$@"; do
  case "$tu" in */*) pkg=${tu%/*}; n=${tu##*/};; *) pkg=ChFi3d; n=$tu;; esac
  clang++ -arch arm64 -mmacosx-version-min=12.0 -std=c++17 -O2 -DNDEBUG -w \
    -I"$SRC/src/ModelingAlgorithms/TKFillet/ChFi3d" -I"$SRC/src/ModelingAlgorithms/TKFillet/$pkg" -I"$XF/macos-arm64/Headers" \
    -c "$SRC/src/ModelingAlgorithms/TKFillet/$pkg/$n.cxx" -o "$T/$n.cxx.o"
done
(cd "$T" && ar r "$A" *.o && ranlib "$A"); rm -rf "$T"
