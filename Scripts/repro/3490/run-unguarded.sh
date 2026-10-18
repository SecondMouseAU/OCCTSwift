#!/bin/bash
# usage: run-unguarded.sh <OCCT.xcframework> <work-dir> [jobs]
# The #3487 harness against the bare reader (BRepTools::Read on the path and on a stream, no
# bridge guard), thinned as that README's "before" runs are, so the numbers compare. Run it once
# against the pinned kernel and once against a kernel with 0073 applied.
set -u
HERE="$(cd "$(dirname "$0")/../3487" && pwd)"
XCF=$1
WORK=$2
JOBS=${3:-8}
mkdir -p "$WORK/corpus"
"$HERE/build.sh" "$XCF" "$WORK/probe" || exit 1
"$WORK/probe" gen "$WORK/corpus" > "$WORK/corpus.txt"
matrix() { # name mode [matrix.py options...]
  local name=$1 mode=$2
  shift 2
  python3 "$HERE/matrix.py" "$WORK/probe" "$WORK/corpus" "$WORK/run-$name" "$mode" --jobs "$JOBS" "$@" \
    > "$WORK/matrix-$name.txt" 2>&1
}
matrix path-prefix path --only prefix --thin 12
matrix str-struct str --only struct --files box,bsplineloft,meshedbox,compound
matrix str-byte str --only byte --thin 40 --files box,bsplineloft,meshedbox,compound
python3 "$(dirname "$0")/cases.py" "$WORK/corpus/box.brep" "$WORK/cases"
for f in "$WORK"/cases/*.brep; do
  echo "$(basename "$f"): $(ulimit -t 10; "$WORK/probe" read path "$f" 2>&1 | head -2 | tr '\n' ' ' | cut -c1-100)"
done > "$WORK/cases.txt"
echo done > "$WORK/DONE"
