#!/bin/bash
# One input per process: a crash kills only that process. Usage: run.sh (from the repo root)
# Compile first: see the ground-truth-probe skill, output to /tmp/claude-501/p3099.
P=${PROBE:-/tmp/claude-501/p3099}
for kind in square zero same mixed; do
for nw in 0 1 2 3; do
for solid in 1 0; do for ruled in 1 0; do for v in "0 0" "1 0" "0 1" "1 1"; do
  out=$($P $nw $solid $ruled $v $kind 2>&1); rc=$?
  echo "kind=$kind wires=$nw solid=$solid ruled=$ruled vertices(first,last)=$v -> rc=$rc $out"
done; done; done; done; done
