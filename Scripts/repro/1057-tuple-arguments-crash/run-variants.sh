#!/bin/bash
# #1057: run each Smallest variant in its own process. Smallest imports nothing: no swift-testing,
# no Foundation, no simd module.
#
#   ./run-variants.sh [last-variant]     (default 64)

set -u
cd "$(dirname "$0")/standalone" || exit 2
LAST="${1:-64}"

swift build --product Smallest >/dev/null 2>&1 || { echo "build failed"; exit 2; }
BIN="$(swift build --product Smallest --show-bin-path)/Smallest"

for n in $(seq 1 "$LAST"); do
  out=$("$BIN" "$n" 2>&1)
  rc=$?
  line=$(printf '%s' "$out" | grep -m1 "^v$n:")
  [ -z "$line" ] && line=$(printf '%s' "$out" | grep -m1 "v$n:")
  if [ "$rc" -ne 0 ]; then
    msg=$(printf '%s' "$out" | grep -m1 -o "freed pointer was not the last allocation")
    [ -z "$msg" ] && msg="rc=$rc"
    printf '%s CRASH (%s)\n' "${line:-v$n}" "$msg"
  else
    printf '%s\n' "${line:-v$n: (no output)}"
  fi
done
