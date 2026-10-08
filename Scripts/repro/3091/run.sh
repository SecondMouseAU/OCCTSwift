#!/usr/bin/env bash
# Reproduce #3091 on the kernel and measure the effect of patch 0057.
#
#   Scripts/repro/3091/run.sh        from the repo root
#
# Two binaries run the same probe, which compares GProp_SelGProps and GProp_VelGProps on gp_Cylinder,
# gp_Sphere and gp_Torus against an independent Gauss-Legendre integral written in the probe:
#
#   control  GProp_SelGProps.cxx and GProp_VelGProps.cxx recompiled from source with 0050, 0051 and
#            0055 applied and nothing else, linked ahead of the archive: the kernel as it stands
#   variant  the same two files with 0057 on top
#
# Needs Libraries/OCCT.xcframework (the macOS slice) and Libraries/occt-src. Builds under $OUT;
# nothing in the repo is modified. OCCT_SRC and OCCT_XC override the two Libraries/ paths.
# Exits 1 unless the control fails and the variant passes.
set -eu

DIR=Scripts/repro/3091
PATCHES=Scripts/patches
OUT=${OUT:-/tmp/occt3091}
SRC=${OCCT_SRC:-Libraries/occt-src/src}
XC=${OCCT_XC:-Libraries/OCCT.xcframework/macos-arm64}
GP=ModelingData/TKGeomBase/GProp
CXX_FLAGS=(-std=c++17 -w -O3 -DNDEBUG -arch arm64 -mmacosx-version-min=12.0 -I"$XC/Headers")
LINK=(-L"$XC" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++)
rm -rf "$OUT"
mkdir -p "$OUT"

ROOT=$PWD
# applied <dir> <patch>: true when the patch is already in the tree there
applied() { ( cd "$1" && git apply --check -R "$ROOT/$2" ) >/dev/null 2>&1; }
# tree <name> <patch...>: the two files from $SRC with 0050, 0051 and 0055 applied if they are not,
# then the given patches
tree() { local name=$1; shift
  mkdir -p "$OUT/$name/src/$GP"
  cp "$SRC/$GP/GProp_SelGProps.cxx" "$SRC/$GP/GProp_VelGProps.cxx" "$OUT/$name/src/$GP/"
  for p in "$PATCHES"/0050-*.patch "$PATCHES"/0051-*.patch "$PATCHES"/0055-*.patch "$@"; do
    if applied "$OUT/$name" "$p"; then :; else ( cd "$OUT/$name" && git apply "$ROOT/$p" ); fi
  done; }
build() { local name=$1
  for c in Sel Vel; do
    clang++ "${CXX_FLAGS[@]}" -c "$OUT/$name/src/$GP/GProp_${c}GProps.cxx" -o "$OUT/$name-$c.o"
  done
  clang++ "${CXX_FLAGS[@]}" "$DIR/probe.cxx" "$OUT/$name-Sel.o" "$OUT/$name-Vel.o" "${LINK[@]}" -o "$OUT/bin-$name"; }

tree control
tree variant "$PATCHES"/0057-*.patch
if applied "$OUT/variant" "$(echo "$PATCHES"/0057-*.patch)"; then echo "0057 reverse-applies to the variant tree"; fi

echo "== control: the two files with 0050, 0051 and 0055 only =="
build control
crc=0; "$OUT/bin-control" >"$OUT/control.txt" || crc=$?
head -4 "$OUT/control.txt"; tail -2 "$OUT/control.txt"; echo "exit $crc"

echo "== variant: 0057 on top =="
build variant
vrc=0; "$OUT/bin-variant" >"$OUT/variant.txt" || vrc=$?
head -4 "$OUT/variant.txt"; tail -2 "$OUT/variant.txt"; echo "exit $vrc"

echo "== every case, control then variant =="
cat "$OUT/control.txt"
echo "-- variant --"
cat "$OUT/variant.txt"

echo "== verdict =="
echo "control exit $crc (must be 1), variant exit $vrc (must be 0)"
[ "$crc" = 1 ] && [ "$vrc" = 0 ]
