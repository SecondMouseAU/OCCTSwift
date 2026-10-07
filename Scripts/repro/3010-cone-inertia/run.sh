#!/usr/bin/env bash
# Reproduce #3010 on the kernel and measure the effect of patch 0055.
#
#   Scripts/repro/3010-cone-inertia/run.sh        from the repo root
#
# Three binaries run the same probe, which compares GProp_SelGProps and GProp_VelGProps on gp_Cone
# (plus gp_Cylinder and gp_Sphere, for the issue's first question) against an independent
# Gauss-Legendre integral written in the probe:
#
#   asset    the xcframework alone, no override (context only: a local copy can lag the pinned asset)
#   control  GProp_SelGProps.cxx and GProp_VelGProps.cxx recompiled from source with 0050 and 0051
#            applied and nothing else, linked ahead of the archive: the kernel as it stands
#   variant  the same two files with 0055 on top
#
# Needs Libraries/OCCT.xcframework (the macOS slice) and Libraries/occt-src. 0050 and 0051 are
# applied here when the source tree does not already hold them, so a tree that is not patched yet
# gives the same control. Builds under $OUT; nothing in the repo is modified. OCCT_SRC and OCCT_XC
# override the two Libraries/ paths. Exits 1 unless the control fails and the variant passes.
set -eu

DIR=Scripts/repro/3010-cone-inertia
PATCHES=Scripts/patches
OUT=${OUT:-/tmp/occt3010}
SRC=${OCCT_SRC:-Libraries/occt-src/src}
XC=${OCCT_XC:-Libraries/OCCT.xcframework/macos-arm64}
GP=ModelingData/TKGeomBase/GProp
# The kernel is a Release build for arm64 macOS 12; -O3 -DNDEBUG is what CMake's Release adds.
CXX_FLAGS=(-std=c++17 -w -O3 -DNDEBUG -arch arm64 -mmacosx-version-min=12.0 -I"$XC/Headers")
LINK=(-L"$XC" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++)
rm -rf "$OUT"
mkdir -p "$OUT"

ROOT=$PWD
# applied <dir> <patch>: true when the patch is already in the tree there (git apply is exact about context)
applied() { ( cd "$1" && git apply --check -R "$ROOT/$2" ) >/dev/null 2>&1; }
# tree <name> <patch...>: the two files from $SRC with 0050 and 0051 applied if they are not, then the given patches
tree() { local name=$1; shift
  mkdir -p "$OUT/$name/src/$GP"
  cp "$SRC/$GP/GProp_SelGProps.cxx" "$SRC/$GP/GProp_VelGProps.cxx" "$OUT/$name/src/$GP/"
  for p in "$PATCHES"/0050-*.patch "$PATCHES"/0051-*.patch "$@"; do
    if applied "$OUT/$name" "$p"; then :; else ( cd "$OUT/$name" && git apply "$ROOT/$p" ); fi
  done; }
# build <name>: compile the two files of tree <name> and link the probe ahead of the archive
build() { local name=$1
  for c in Sel Vel; do
    clang++ "${CXX_FLAGS[@]}" -c "$OUT/$name/src/$GP/GProp_${c}GProps.cxx" -o "$OUT/$name-$c.o"
  done
  clang++ "${CXX_FLAGS[@]}" "$DIR/probe.cxx" "$OUT/$name-Sel.o" "$OUT/$name-Vel.o" "${LINK[@]}" -o "$OUT/bin-$name"; }

echo "== 0. 0055 applies on top of 0050 and 0051, and not without them =="
mkdir -p "$OUT/bare/src/$GP"
cp "$SRC/$GP/GProp_SelGProps.cxx" "$SRC/$GP/GProp_VelGProps.cxx" "$OUT/bare/src/$GP/"
if applied "$OUT/bare" "$(echo "$PATCHES"/0050-*.patch)"; then
  echo "(this source tree already holds 0050, so the bare-tree check does not apply)"
else
  if ( cd "$OUT/bare" && git apply --check "$ROOT/$(echo "$PATCHES"/0055-*.patch)" ) >/dev/null 2>&1; then echo "0055 applies to the V8_0_1 files alone"; else echo "0055 does not apply to the V8_0_1 files alone"; fi
fi

tree control
tree variant "$PATCHES"/0055-*.patch
echo "0055 applies to the files with 0050 and 0051 applied"
if applied "$OUT/variant" "$(echo "$PATCHES"/0055-*.patch)"; then echo "0055 reverse-applies to the variant tree"; fi

echo "== 1. the xcframework alone (a local one can lag the pin and lack 0050 and 0051, so this is context only) =="
clang++ "${CXX_FLAGS[@]}" "$DIR/probe.cxx" "${LINK[@]}" -o "$OUT/bin-asset"
rc=0; "$OUT/bin-asset" >"$OUT/asset.txt" || rc=$?
tail -3 "$OUT/asset.txt"; echo "exit $rc"

echo "== 2. control: the two files recompiled with 0050 and 0051 only =="
build control
crc=0; "$OUT/bin-control" >"$OUT/control.txt" || crc=$?
head -3 "$OUT/control.txt"; sed -n '/== gp_Cone/,/XOY.*pi\/12/p' "$OUT/control.txt" | head -6; tail -3 "$OUT/control.txt"; echo "exit $crc"

echo "== 3. variant: 0055 on top =="
build variant
vrc=0; "$OUT/bin-variant" >"$OUT/variant.txt" || vrc=$?
head -3 "$OUT/variant.txt"; tail -3 "$OUT/variant.txt"; echo "exit $vrc"

echo "== 4. the matrices of the headline case (u full, v 0..10, a = pi/6, R = 5), control then variant =="
"$OUT/bin-control" -v | sed -n '/XOY\] a=pi\/6 R=5 v 0..10/,/\[XOY\] a=pi\/12/p' | head -24
echo "-- variant --"
"$OUT/bin-variant" -v | sed -n '/XOY\] a=pi\/6 R=5 v 0..10/,/\[XOY\] a=pi\/12/p' | head -24

echo "== 5. every case, variant =="
cat "$OUT/variant.txt"

echo "== verdict =="
echo "control exit $crc (must be 1), variant exit $vrc (must be 0)"
[ "$crc" = 1 ] && [ "$vrc" = 0 ]
