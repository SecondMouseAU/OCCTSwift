#!/usr/bin/env bash
# #3105: reproduces the crash battery against the pinned kernel and re-runs it with patch 0058.
# usage: run.sh <occt-src-with-the-44-pinned-patches> <work-dir>
# <occt-src> is a clean V8_0_1 checkout with Scripts/patches/0010..0057 applied (the #2190 lesson: not
# the shared Libraries/occt-src, which may be dirty). 0058 is applied here, to a copy of its file.
set -euo pipefail
SRC=$(cd "$1" && pwd); WORK=$2; mkdir -p "$WORK"; HERE=$(cd "$(dirname "$0")" && pwd)
PATCH=$(ls "$HERE"/../../patches/0058-*.patch)
CXX=src/ModelingAlgorithms/TKOffset/BRepOffsetAPI/BRepOffsetAPI_MiddlePath.cxx
# the pinned kernel, checksum from Package.swift
gh release download v4.0.0-kernel.5 --repo SecondMouseAU/OCCTSwift -p OCCT.xcframework.zip -D "$WORK" --clobber
test "$(shasum -a 256 "$WORK/OCCT.xcframework.zip" | cut -d' ' -f1)" = \
  91688c08d55f8f7f05f4965e32679b045dfead119ceeff766bd3bd68cb5a9ca8
(cd "$WORK" && unzip -q -o OCCT.xcframework.zip)
XC=$WORK/OCCT.xcframework/macos-arm64
FLAGS="-std=c++17 -w -g -O0 -DNo_Exception -DNDEBUG -I$XC/Headers"   # the release macros, or the checked inline TopoDS::Edge wins at link time
mkdir -p "$WORK/patched/$(dirname $CXX)"
cp "$SRC/$CXX" "$WORK/MiddlePath.cxx"
cp "$SRC/$CXX" "$WORK/patched/$CXX"; patch -p1 -d "$WORK/patched" < "$PATCH"
clang++ $FLAGS -c "$WORK/MiddlePath.cxx" -o "$WORK/mpr.o"
clang++ $FLAGS -c "$WORK/patched/$CXX" -o "$WORK/mpr_patched.o"
for v in mpr mpr_patched; do
  clang++ -std=c++17 -ObjC++ -w -g -DNo_Exception -DNDEBUG -I$XC/Headers -L$XC "$HERE/probe.mm" "$WORK/$v.o" \
    -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o "$WORK/probe_$v"
done
(cd "$HERE" && FEAT=1 python3 scan.py "$WORK/probe_mpr"         > "$WORK/scan-before.txt"
               FEAT=1 python3 scan.py "$WORK/probe_mpr_patched" > "$WORK/scan-after.txt"
               python3 fault-sites.py "$WORK/probe_mpr" "$WORK/scan-before.txt" "$WORK/mpr.o" > "$WORK/sites-before.txt"
               python3 cmp.py "$WORK/scan-before.txt" "$WORK/scan-after.txt" > "$WORK/cmp.txt"; python3 summ.py "$WORK/scan-after.txt" >> "$WORK/cmp.txt")
cat "$WORK/sites-before.txt" "$WORK/cmp.txt"
