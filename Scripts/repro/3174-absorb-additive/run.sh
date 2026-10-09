#!/bin/bash
# #3174: absorbAdditive union failure and applyBoolean solid operands. From the repo root.
# Measured before the fix: two valid solids always fuse (disjoint, edge-touching, face-touching,
# identical, 1e12-sized all fulfilled); an extrude onto a bare-shell inputBody reaches the
# "boolean union failed" skip; a union/subtract/intersect on a shell (or compound of a shell)
# operand was reported fulfilled with no solid in the result.
exec swift test --filter Issue3174
