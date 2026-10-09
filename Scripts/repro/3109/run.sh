#!/bin/bash
# #3109: measure where each revolve builder stops returning. One process per input, killed at LIMIT s.
# Run from the repo root. Replaces Sources/OCCTTest/main.swift with probe.swift for the run and restores it.
set -u
LIMIT=${LIMIT:-10}
cp Sources/OCCTTest/main.swift /tmp/occttest-main.swift.bak
trap 'cp /tmp/occttest-main.swift.bak Sources/OCCTTest/main.swift' EXIT
cp Scripts/repro/3109/probe.swift Sources/OCCTTest/main.swift
swift build --product OCCTTest 2>&1 | tail -2
BIN=$(swift build --show-bin-path)/OCCTTest
ANGLES=${ANGLES:-"6.283185307179586 1e3 1e6 1e8 1e9 1e10 1e11 1e12 1e13 1e14 1e15 1e16 1e18 1e100 1e300"}
for b in ${BUILDERS:-revolve revolved revolution feature localRevolution localRevolutionOffset localRevolutionForm}; do
  for a in $ANGLES; do
    "$BIN" "$b" "$a" & pid=$!
    ( sleep "$LIMIT"; kill -9 $pid 2>/dev/null ) & killer=$!
    if wait $pid 2>/dev/null; then :; else echo "$b angle=$a -> NO RETURN / CRASH in ${LIMIT}s (status $?)"; fi
    kill $killer 2>/dev/null; wait $killer 2>/dev/null
  done
done
