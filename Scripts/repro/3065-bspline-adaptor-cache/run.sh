#!/usr/bin/env bash
# #3065: build adaptor_contract.cpp against (a) vanilla OCCT 8.0.1 adaptor sources and
# (b) the same sources with Scripts/patches/0031 applied, then measure.
#   ./run.sh build        build both variants into $OUT
#   ./run.sh tsan         build the TSan variants of the #2074 harness (then run them by hand, see the README)\n#   ./run.sh race  [N]    N one-process runs per variant and mode (default 20)
#   ./run.sh perf  [N]    N runs, median reported
# Needs Libraries/OCCT.xcframework and Libraries/occt-src (gitignored; symlink from the main checkout).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
LIB="${LIBS:-$REPO/Libraries}"
XCF="$LIB/OCCT.xcframework/macos-arm64"
OSRC="$LIB/occt-src"
SRC="$OSRC/src"
OUT="${OUT:-$HERE/out}"
PATCH="$REPO/Scripts/patches/0031-bspline-adaptor-cache-thread-safety-1153.patch"
FILES="src/FoundationClasses/TKMath/BSplCLib/BSplCLib_Cache.hxx src/FoundationClasses/TKMath/BSplCLib/BSplCLib_Cache.cxx src/FoundationClasses/TKMath/BSplSLib/BSplSLib_Cache.hxx src/FoundationClasses/TKMath/BSplSLib/BSplSLib_Cache.cxx src/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Curve.hxx src/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Curve.cxx src/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Surface.hxx src/ModelingData/TKG3d/GeomAdaptor/GeomAdaptor_Surface.cxx"
OPT="${OPT:--O2}"
build() {
  for v in stock patched; do
    d="$OUT/$v"; rm -rf "$d"; mkdir -p "$d"
    for f in $FILES; do mkdir -p "$d/$(dirname "$f")"; git -C "$OSRC" show "HEAD:$f" > "$d/$f"; done
    if [ "$v" = patched ]; then ( cd "$d" && patch -p1 --silent < "$PATCH" ); fi
    inc="-I$d/src/FoundationClasses/TKMath/BSplCLib -I$d/src/FoundationClasses/TKMath/BSplSLib -I$d/src/ModelingData/TKG3d/GeomAdaptor -I$SRC/ModelingData/TKG3d/Geom -I$XCF/Headers"
    for f in $FILES; do case "$f" in *.cxx)
      clang++ -std=c++17 $OPT -g -w -c $inc "$d/$f" -o "$d/$(basename "$f" .cxx).o";; esac; done
    clang++ -std=c++17 $OPT -g -w -c $inc "$HERE/adaptor_contract.cpp" -o "$d/main.o"
    clang++ -std=c++17 $OPT -g -w "$d"/*.o -L"$XCF" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o "$d/contract"
  done
}
# tsan: the #2074 harness, TSan-instrumented, with the four adaptor TUs compiled from the variant's
# own sources and its own headers (so the harness and those TUs agree on the class layout, which
# is what makes this an A/B and not the ODR violation tsan-stress.sh's #2074 comment rules out).
# The rest of the kernel comes from the TSan install, and only Geom/GeomAdaptor symbols are used.
tsan() {
  TI="$LIB/occt-install-tsan"; inc="$TI/include/opencascade"; [ -d "$inc" ] || inc="$TI/include"
  libs=$(ls "$TI"/lib/libTK*.a | xargs -n1 basename | sed 's/^lib//;s/\.a$//;s/^/-l/')
  for v in stock patched; do
    d="$OUT/$v"; ti="-I$d/src/FoundationClasses/TKMath/BSplCLib -I$d/src/FoundationClasses/TKMath/BSplSLib -I$d/src/ModelingData/TKG3d/GeomAdaptor -I$SRC/ModelingData/TKG3d/Geom -I$inc"
    mkdir -p "$d/tsan"
    for f in $FILES; do case "$f" in *.cxx)
      clang++ -std=c++17 -fsanitize=thread -O1 -g -w -c $ti "$d/$f" -o "$d/tsan/$(basename "$f" .cxx).o";; esac; done
    clang++ -std=c++17 -fsanitize=thread -O1 -g -w -c $ti "$HERE/../2074-adaptor-evaluation/occt_2074_stress.cpp" -o "$d/tsan/main.o"
    clang++ -std=c++17 -fsanitize=thread -O1 -g -w "$d"/tsan/*.o -L"$TI/lib" $libs -lz -lc++ -framework Foundation -o "$d/tsan/stress"
  done
}
case "${1:-}" in
  build) build ;;
  tsan) tsan ;;
  race|perf) python3 -I "$HERE/measure.py" "$1" "$OUT" "${2:-20}" ;;
  *) echo "usage: $0 build|race|perf [N]" >&2; exit 2 ;;
esac
