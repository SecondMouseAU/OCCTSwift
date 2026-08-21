#!/bin/bash
# #1057: run each MinimalRepro stage in its own process, so a crash reports the stage rather than
# ending the run. MinimalRepro imports no swift-testing.
#
#   ./run-stages.sh [last-stage]     (default 22)

set -u
cd "$(dirname "$0")/standalone" || exit 2
LAST="${1:-22}"

swift build --product MinimalRepro >/dev/null 2>&1 || { echo "build failed"; exit 2; }
BIN="$(swift build --product MinimalRepro --show-bin-path)/MinimalRepro"

for n in $(seq 1 "$LAST"); do
  out=$("$BIN" "$n" 2>&1)
  rc=$?
  line=$(printf '%s' "$out" | grep -m1 "stage $n:")
  if [ "$rc" -ne 0 ]; then
    msg=$(printf '%s' "$out" | grep -m1 -o "freed pointer was not the last allocation")
    [ -z "$msg" ] && msg="rc=$rc"
    printf '%s CRASH (%s)\n' "${line:-stage $n}" "$msg"
  else
    printf '%s\n' "${line:-stage $n: (no output)}"
  fi
done
