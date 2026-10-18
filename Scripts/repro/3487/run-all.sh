#!/bin/bash
# usage: run-all.sh <OCCT.xcframework> <work-dir> [jobs]
# Builds the probe, writes the corpus, and runs the matrix. Output: <work-dir>/matrix-<name>.txt
# (the summary) and <work-dir>/run-<name>/results-<mode>.tsv (one line per case).
#
# The guarded readers are cheap, so they run in full. The unguarded reader spins on a large share
# of cases and each spin costs its whole CPU allowance (0.1 s), so its runs are thinned (see
# matrix.py --thin); the full unguarded matrix is hours on a loaded machine.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
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

# After the fix: eofbit and failbit throw, then the same plus the word-length limit the bridge ships.
matrix strxe strxe
matrix bridge bridge
# Before the fix (BRepTools::Read on the bare stream and on the bare file), thinned.
matrix path-prefix path --only prefix --thin 12
matrix str-struct str --only struct --files box,bsplineloft,meshedbox,compound
matrix str-byte str --only byte --thin 40 --files box,bsplineloft,meshedbox,compound
echo "done"
