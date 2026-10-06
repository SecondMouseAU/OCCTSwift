#!/usr/bin/env bash
# Reproduce the root cause of #2881 (OCCT#1568) on the pinned kernel, and the effect of patch 0054.
#
#   Scripts/repro/occt1568-fillet-opposite-edge/run.sh        from the repo root
#
# Needs Libraries/OCCT.xcframework (the macOS slice) and Libraries/occt-src (the pinned V8_0_1
# tree, with the carried patches applied: no patch touches the three files used here, so they are
# pristine). Builds under $OUT (default /tmp/occt1568); nothing in the repo is modified.
# OCCT_SRC and OCCT_XC override the two Libraries/ paths, for a checkout that has no Libraries/ of its own.
set -euo pipefail

DIR=Scripts/repro/occt1568-fillet-opposite-edge
OUT=${OUT:-/tmp/occt1568}
SRC=${OCCT_SRC:-Libraries/occt-src/src}
XC=${OCCT_XC:-Libraries/OCCT.xcframework/macos-arm64}
CXX_FLAGS=(-std=c++17 -w -O0 -g -I"$XC/Headers")
LINK=(-L"$XC" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++)
mkdir -p "$OUT"

# probe <name> [override.o ...]: the reporter's replay, with the given objects linked ahead of the kernel
probe() { local name=$1; shift
  clang++ "${CXX_FLAGS[@]}" -ObjC++ "$DIR/probe.mm" "$@" "${LINK[@]}" -o "$OUT/$name"; }
# override <name> <pristine file under $SRC> <diff>: apply an instrumentation diff and compile it
override() { local name=$1 file=$2 diff=$3
  patch -s -o "$OUT/$name.cxx" "$SRC/$file" "$diff"
  clang++ "${CXX_FLAGS[@]}" -c "$OUT/$name.cxx" -o "$OUT/$name.o"; }

echo "== 1. the crash, and the radii either side of it (edge 13, DRAW numbering) =="
probe unpatched
cd "$DIR"
for r in 1.49 1.5 1.5000001; do
  rc=0; "$OUT/unpatched" model.brep "$r" 13 >"$OUT/out.txt" 2>&1 || rc=$?
  echo "radius $r: exit $rc"
done
cd - >/dev/null

echo "== 2. BRepAdaptor_Curve2d::Initialize never sees a null pcurve on this model =="
override objects ModelingData/TKBRep/BRepAdaptor/BRepAdaptor_Curve2d.cxx "$DIR/instrument/BRepAdaptor_Curve2d-objects.diff"
probe objects "$OUT/objects.o"
( cd "$DIR"; "$OUT/objects" model.brep 1.5 13 >"$OUT/out.txt" 2>&1 || true
  echo "Initialize calls: $(grep -c 'initialize ' "$OUT/out.txt"), with a null pcurve: $(grep -c 'pcurveNull=1' "$OUT/out.txt")"
  echo "default constructions: $(grep -c 'default-ctor' "$OUT/out.txt")" )

echo "== 3. the one EvalD1 before the fault dereferences a default-constructed adaptor =="
override evald1 ModelingData/TKG3d/Adaptor3d/Adaptor3d_CurveOnSurface.cxx "$DIR/instrument/Adaptor3d_CurveOnSurface-EvalD1.diff"
probe evald1 "$OUT/objects.o" "$OUT/evald1.o"
( cd "$DIR"; "$OUT/evald1" model.brep 1.5 13 >"$OUT/out.txt" 2>&1 || true
  ed1=$(grep '\[ED1\]' "$OUT/out.txt" | tail -1); echo "$ed1"
  adaptor=$(echo "$ed1" | sed -E 's/.*myCurve=(0x[0-9a-f]+).*/\1/')
  echo "that adaptor was default-constructed: $(grep -c "default-ctor this=$adaptor" "$OUT/out.txt") time(s), initialised: $(grep -c "initialize   this=$adaptor" "$OUT/out.txt") time(s)" )

echo "== 4. the branch in StartSol fires exactly at the crashing radius =="
override startsol ModelingAlgorithms/TKFillet/ChFi3d/ChFi3d_Builder_2.cxx "$DIR/instrument/ChFi3d_Builder_2-startsol-log.diff"
probe startsol "$OUT/startsol.o"
( cd "$DIR"
  for r in 1.49 1.5 1.5000001; do
    rc=0; "$OUT/startsol" model.brep "$r" 13 >"$OUT/out.txt" 2>&1 || rc=$?
    echo "radius $r: exit $rc, StartSol hits: $(grep -c STARTSOL "$OUT/out.txt")"
  done
  "$OUT/startsol" model.brep 1.5 13 2>&1 | grep STARTSOL | sort -u | head -1 || true )

echo "== 5. patch 0054 =="
rm -rf "$OUT/tree"; mkdir -p "$OUT/tree/src/ModelingAlgorithms/TKFillet/ChFi3d"
cp "$SRC/ModelingAlgorithms/TKFillet/ChFi3d/ChFi3d_Builder_2.cxx" "$OUT/tree/src/ModelingAlgorithms/TKFillet/ChFi3d/"
patch -s -p1 -d "$OUT/tree" < Scripts/patches/0054-ChFi3d_Builder-StartSol-drops-an-obstacle-with-no-edge-2881.patch
clang++ "${CXX_FLAGS[@]}" -c "$OUT/tree/src/ModelingAlgorithms/TKFillet/ChFi3d/ChFi3d_Builder_2.cxx" -o "$OUT/patched.o"
probe patched "$OUT/patched.o"
( cd "$DIR"; for r in 1.49 1.5 1.5000001; do
    rc=0; "$OUT/patched" model.brep "$r" 13 >"$OUT/out.txt" 2>&1 || rc=$?
    echo "radius $r: exit $rc, $(grep 'IsDone' "$OUT/out.txt" | tail -1 | sed 's/^ *//')"
  done
  echo "-- 42 edges x 9 radii, unpatched vs patched --"
  python3 sweep.py "$OUT/unpatched" "$OUT/patched" )
