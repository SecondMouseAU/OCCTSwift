#!/bin/bash
# #3003: build the probe against an OCCT xcframework, run it in N fresh processes, and print the census.
#
#   run.sh [--what lines|battery|order|threads] [--variant asset|control|patched]
#          [--runs N] [--xcframework DIR] [--occt-src DIR]
#
#   --what      lines     the six lines of the two #766 probes (probe.mm lines), the default
#               battery   72 offset and thick-solid requests with a dump hash each (battery.mm)
#               order     the hash iteration order of a DataMap of one result's faces (probe.mm order)
#               threads   thread count and BOPAlgo_Options' parallel mode (probe.mm threads), one run
#               perturb   32 builds in ONE process with a different amount of heap held before each,
#                         and how many distinct face orders came out (probe.mm perturb), over --runs
#                         processes (default 20): one process is a draw, the spread is the measurement.
#               perturb-quiet  the same without the perturbation.
#   --variant   asset     link against the archive as shipped. This is the kernel a consumer runs.
#               control   recompile the UNMODIFIED BRepOffset_MakeOffset.cxx from --occt-src with the
#                         kernel's own flags and link it ahead of the archive. The census must match
#                         `asset`, which is what shows the override toolchain is not the variable.
#               patched   the same file with Scripts/patches/0053-*.patch applied to a copy.
#   --runs      processes to run (default 60). One process shows nothing; the claim is a spread.
#   --xcframework  the OCCT.xcframework to read. Default: $OCCT_XCFRAMEWORK, then SwiftPM's resolved
#               asset under .build/artifacts, then Libraries/OCCT.xcframework. Which kernel it was is
#               printed first, because a census of the wrong one is worth nothing.
#   --raw FILE  also keep the raw output of the runs, which `census.py compare` reads
#   --occt-src  an OCCT V8_0_1 source tree, for control and patched. Default Libraries/occt-src. It
#               is only read: the file is copied out and the patch is applied to the copy.
#
# Everything is built in a temporary directory that is removed on exit; nothing is written to the
# repository. macOS arm64 only, like every probe here.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
WHAT=lines
VARIANT=asset
RUNS=60
RUNS_GIVEN=""
XC=""
RAW=""
OCCT_SRC="$REPO/Libraries/occt-src"

while [ $# -gt 0 ]; do
  case "$1" in
    --what) WHAT="$2"; shift 2 ;;
    --variant) VARIANT="$2"; shift 2 ;;
    --runs) RUNS="$2"; RUNS_GIVEN=1; shift 2 ;;
    --xcframework) XC="$2"; shift 2 ;;
    --occt-src) OCCT_SRC="$2"; shift 2 ;;
    --raw) RAW="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$WHAT" in lines|battery|order|threads|perturb|perturb-quiet) ;; *) echo "bad --what: $WHAT" >&2; exit 2 ;; esac
case "$VARIANT" in asset|control|patched) ;; *) echo "bad --variant: $VARIANT" >&2; exit 2 ;; esac

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
HDR="$XC/macos-arm64/Headers"
LIB="$XC/macos-arm64"

case "$WHAT" in
  threads) RUNS=1 ;;
  perturb|perturb-quiet) [ -n "$RUNS_GIVEN" ] || RUNS=20 ;;
esac
echo "kernel: $XC"
echo "libOCCT-macos.a: sha256 $(shasum -a 256 "$LIB/libOCCT-macos.a" | cut -d' ' -f1), $(stat -f %z "$LIB/libOCCT-macos.a") bytes"
echo "variant: $VARIANT, what: $WHAT, runs: $RUNS"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/occt3003.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

case "$WHAT" in
  battery) SRC="$HERE/battery.mm" ;;
  *) SRC="$HERE/probe.mm" ;;
esac
clang++ -std=c++17 -ObjC++ -w -O0 -I"$HDR" -c "$SRC" -o "$TMP/probe.o"

OVR=""
if [ "$VARIANT" != "asset" ]; then
  REL=src/ModelingAlgorithms/TKOffset/BRepOffset/BRepOffset_MakeOffset.cxx
  if [ ! -f "$OCCT_SRC/$REL" ]; then
    echo "no $REL under $OCCT_SRC; pass --occt-src" >&2
    exit 2
  fi
  # The patch also carries a GTest, so the file it adds to has to be in the copy as well.
  GREL=src/ModelingAlgorithms/TKOffset/GTests/BRepOffset_MakeOffset_Test.cxx
  mkdir -p "$TMP/ovr/$(dirname "$REL")" "$TMP/ovr/$(dirname "$GREL")"
  cp "$OCCT_SRC/$REL" "$TMP/ovr/$REL"
  cp "$OCCT_SRC/$GREL" "$TMP/ovr/$GREL"
  PATCH="$(ls "$REPO"/Scripts/patches/0053-*.patch | head -1)"
  # `aBindOrder` is the patch's own local, so whether the copy carries it says whether the patch is
  # in, and it is checked again after applying. `patch -R --dry-run` is not a usable test: Apple's
  # patch 2.0-12u11 exits 0 on a copy the patch is NOT in ("Unreversed patch detected! Ignore -R?
  # [y]"), which is how the first version of this script linked the unmodified file and called it
  # patched. `git apply -R --check`, which build-occt.sh uses, gets it right.
  if grep -q aBindOrder "$TMP/ovr/$REL"; then CARRIES=yes; else CARRIES=no; fi
  if [ "$VARIANT" = "control" ]; then
    if [ "$CARRIES" = yes ]; then
      echo "the source under $OCCT_SRC already carries $(basename "$PATCH"); control needs the unmodified file" >&2
      exit 2
    fi
  elif [ "$CARRIES" = yes ]; then
    echo "the source already carries $(basename "$PATCH"); linking it as it stands"
  else
    (cd "$TMP/ovr" && git apply "$PATCH")
    echo "applied $(basename "$PATCH") to a copy of BRepOffset_MakeOffset.cxx"
    if ! grep -q aBindOrder "$TMP/ovr/$REL"; then
      echo "the patch did not change the copy" >&2
      exit 2
    fi
  fi
  # The kernel's own Release flags, as recorded in OpenCASCADECompileDefinitionsAndFlags-release.cmake.
  clang++ -std=c++17 -arch arm64 -mmacosx-version-min=12.0 -O3 -DNDEBUG -DNo_Exception \
    -DHAVE_RAPIDJSON -DOCC_CONVERT_SIGNALS -w -I"$HDR" -c "$TMP/ovr/$REL" -o "$TMP/ovr.o"
  OVR="$TMP/ovr.o"
fi

# ld warns about -lc++ twice, which is noise; anything else is shown.
clang++ -arch arm64 "$TMP/probe.o" $OVR -L"$LIB" -lOCCT-macos -framework Foundation \
  -framework AppKit -lz -lc++ -o "$TMP/bin" 2>&1 | grep -v "duplicate libraries" || true

case "$WHAT" in
  threads) "$TMP/bin" threads; exit 0 ;;
  perturb|perturb-quiet)
    i=0
    while [ "$i" -lt "$RUNS" ]; do
      if [ "$WHAT" = perturb ]; then "$TMP/bin" perturb; else "$TMP/bin" perturb quiet; fi
      i=$((i + 1))
    done > "$TMP/out.txt"
    python3 "$HERE/census.py" perturb < "$TMP/out.txt"
    exit 0 ;;
esac

i=0
while [ "$i" -lt "$RUNS" ]; do
  case "$WHAT" in
    order) "$TMP/bin" order ;;
    lines) "$TMP/bin" lines ;;
    *) "$TMP/bin" ;;
  esac
  i=$((i + 1))
done > "$TMP/out.txt"
if [ -n "$RAW" ]; then cp "$TMP/out.txt" "$RAW"; fi

case "$WHAT" in
  lines) python3 "$HERE/census.py" lines < "$TMP/out.txt" ;;
  battery) python3 "$HERE/census.py" battery < "$TMP/out.txt" ;;
  order)
    echo "distinct hash orders of the same faces over $RUNS processes: $(sort -u "$TMP/out.txt" | wc -l | tr -d ' ')"
    head -3 "$TMP/out.txt" ;;
esac
