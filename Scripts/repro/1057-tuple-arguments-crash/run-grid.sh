#!/bin/bash
# #1057: run every cell of the tuple grid in its own process, N times each, and report exit code
# plus the runtime message if one was printed.
#
#   ./run-grid.sh [repetitions]     (default 3)
#
# One process per cell is not a convenience: a cell that crashes takes the whole test process with
# it, so a single `swift test` run would report only the first cell to die.

set -u
cd "$(dirname "$0")/standalone" || exit 2

REPS="${1:-3}"

CELLS=(
  L0Layout
  A1StringSIMD3
  B1StringSIMD3SIMD3
  C1SIMD3SIMD3
  D1StringInt
  E1BareSIMD3
  F1BareString
  G1SIMD3String
  H1RefSIMD3
  I1ArraySIMD3
  J1StringSIMD2
  K1StringSIMD4D
  L1StringSIMD4F
  M1StringSIMD8F
  N1StringSize32
  O1StringVector32
  P1StringDouble
  Q1NamedPair
  R1SingleCase
  S1TwoSequence
  T1Serialized
  U1SerialLoop
  V1EmptyBody
)

swift build --build-tests >/dev/null 2>&1 || { echo "build failed"; exit 2; }

printf '%-22s %-8s %s\n' CELL VERDICT DETAIL
for cell in "${CELLS[@]}"; do
  crashes=0
  detail=""
  for _ in $(seq 1 "$REPS"); do
    out=$(swift test --filter "$cell" 2>&1)
    rc=$?
    if [ "$rc" -ne 0 ]; then
      crashes=$((crashes + 1))
      if [ -z "$detail" ]; then
        # The runtime's own message first, SwiftPM's signal line only as a fallback. Taking them
        # in file order instead put SwiftPM's "exited with unexpected signal code 6" ahead of
        # "freed pointer was not the last allocation" on every row, so this table could never
        # show the allocator message, and a review round went by with the README claiming two
        # cells produced a bare 139 when they produce the message like everything else.
        # The message carries no trailing newline, so it runs together with whatever the test
        # harness printed next; report the phrase itself rather than the line it landed in.
        if printf '%s' "$out" | grep -q "freed pointer was not the last allocation"; then
          detail="freed pointer was not the last allocation"
        else
          detail=$(printf '%s' "$out" | grep -m1 -E "Fatal error|signal code|Crashed" | sed 's/^[[:space:]]*//' | cut -c1-70)
        fi
        [ -z "$detail" ] && detail="rc=$rc"
      fi
    fi
  done
  if [ "$crashes" -eq 0 ]; then
    printf '%-22s %-8s %s\n' "$cell" "clean" "$REPS/$REPS"
  else
    printf '%-22s %-8s %s\n' "$cell" "CRASH" "$crashes/$REPS  $detail"
  fi
done
