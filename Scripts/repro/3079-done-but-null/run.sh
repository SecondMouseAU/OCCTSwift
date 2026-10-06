#!/usr/bin/env bash
# Probe the 35 `new OCCTShape(builder.Shape())` sites of #3079 for a done-but-null result.
#
#   Scripts/repro/3079-done-but-null/run.sh [case-prefix]     from anywhere
#
# Builds ./probe (a SEPARATE package that depends on OCCTSwift by path, so the root manifest is
# untouched; the released kernel asset is resolved, no Libraries/ needed), then runs EVERY case in
# its own process, so a crash is one recorded line and not the end of the sweep. Per case the
# output is one of:
#   nil            the bridge refused (the Swift API returned nil)
#   VALID ...      a non-null shape
#   NULL-WRAPPED   a non-nil Shape whose isNull is true: the defect #3079 asks about
#   CRASH(<sig>)   the process died; stop probing that function and file an issue
#   TIMEOUT        no answer in $CASE_TIMEOUT seconds
# followed by a per-function summary. Writes $OUT (default transcript.txt beside this script).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$HERE/transcript.txt}
CASE_TIMEOUT=${CASE_TIMEOUT:-90}
FILTER=${1:-}
unset BRIDGE_PREBUILT OCCTSWIFT_BRIDGE_PREBUILT
( cd "$HERE/probe" && swift build 2>&1 | tail -1 ) >&2
BIN=$(cd "$HERE/probe" && swift build --show-bin-path)/probe
: > "$OUT"
"$BIN" --list | grep -F -- "$FILTER" | while IFS= read -r c; do
  line=$(perl -e 'alarm shift; exec @ARGV' "$CASE_TIMEOUT" "$BIN" "$c" 2>/dev/null); rc=$?
  if [ $rc -eq 0 ] && [ -n "$line" ]; then echo "$line"
  elif [ $rc -eq 142 ]; then echo "$c => TIMEOUT"
  else echo "$c => CRASH(exit $rc)"; fi
done | tee "$OUT"
echo "== summary: result counts per bridge function ==" | tee -a "$OUT"
awk -F' => ' '{ split($1, a, "/"); r=$2; sub(/ .*/, "", r); sub(/\(.*/, "", r); k=a[1] SUBSEP r; n[k]++; f[a[1]]=1; k2[r]=1 }
  END { for (fn in f) { s=fn ":"; for (r in k2) if (n[fn SUBSEP r]) s=s " " r "=" n[fn SUBSEP r]; print s } }' "$OUT" | sort | tee -a "$OUT"
