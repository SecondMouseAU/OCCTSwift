# #613 / #695 — the sub-shape index census

`census.py` enumerates every bridge site that resolves an index by walking a `TopExp_Explorer`
instead of reading the deduplicated `TopExp::MapShapes` enumeration, grouped by the sub-shape type
being walked.

```bash
python3 Scripts/repro/613-edge-index-census/census.py Sources/OCCTBridge/src
```

## Why this exists as a committed artifact

The first pass at #613's back-port to `main` rebuilt the site list by reading #613's own issue body,
and missed three sites (`OCCTBRepCheckSubShapeValid`, `OCCTBRepExtremaExtPC`,
`OCCTBRepExtremaExtCF`) — two of them immediately adjacent to functions the same PR *did* convert.
They were missed because #613's list was written against `refactor/381-pass1b`, where #541 had
already converted them, so they never appeared in #613's scope. `main` never had #541.

That is the failure mode `docs/v2.0.0-plan.md` names: *the census said N, the measurement said M*.
Grep the tree, don't transcribe an issue.

## Expected output on a converged tree

```
9 explorer-indexed sites

--- TopAbs_FACE  (7) ---   <- deferred to #541, see below
--- type  (2) ---          <- the deliberate WIRE/SHELL fallbacks
```

**Zero `TopAbs_EDGE` or `TopAbs_VERTEX` entries.** Any that appear are regressions: those two
families are consistently map-based on both sides, so an occurrence walk always disagrees with its
consumer.

The two `type` entries are the WIRE/SHELL branches of `OCCTBRepCheckSubShapeValid` and
`checkSubShape`. They are deliberate: `OCCTShapeGetWires`/`GetShells` and their counts are explorer
walks too, so those paths already agree with their own consumers.

## Why FACE is deferred rather than fixed

Faces do not have the edge family's problem. Measured against the pinned kernel:

| shape | FACE map / explorer | EDGE map / explorer |
|---|---|---|
| solid box | 6 / 6 agree | 12 / 24 diverge |
| L-prism | 8 / 8 agree | 18 / 36 diverge |
| compound, 2 disjoint solids | 12 / 12 agree | 24 / 48 diverge |
| fused overlapping boxes | 14 / 14 agree | 32 / 64 diverge |
| compound, same solid twice | 6 / 12 **diverge** | 12 / 48 diverge |

An edge is shared by the two faces it bounds, so EDGE diverges on every ordinary solid. A face has
one parent unless a compound gives it two, so FACE agrees except in that exotic case. `main`'s own
split — `faces()` on the explorer against `faceCount`/`face(at:)` on the map — is therefore latent,
and reconciling it is #541, a registered v2.0.0 breaking change, not a 1.x bug fix.
