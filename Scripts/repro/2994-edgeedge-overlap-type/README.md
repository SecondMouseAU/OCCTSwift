# 2994: why `IntTools_EdgeEdge` types one partial arc overlap a vertex and another an edge

Measured against the pinned `v4.0.0-kernel.3` asset on 2026-10-02. `probe-transcript.txt` is the
run.

## Build and run

```bash
XC=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
clang++ -std=c++17 -ObjC++ -w -I"$XC/Headers" -L"$XC" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2994-edgeedge-overlap-type/probe.mm -o /tmp/occt_probe
/tmp/occt_probe
```

## The rule, read from the source and then confirmed on seven fixtures

`IntTools_EdgeEdge::MergeSolutions` (`IntTools_EdgeEdge.cxx:702`, `:756-765`) starts with
`aType = TopAbs_VERTEX` and promotes the merged common range to `TopAbs_EDGE` in exactly one case:

```cpp
if (((fabs(aT11 - aTi11) < myRes1) && (fabs(aT12 - aTi12) < myRes1))
    || ((fabs(aT21 - aTi21) < myRes2) && (fabs(aT22 - aTi22) < myRes2)))
{
  aType = TopAbs_EDGE;
  myCommonParts.Clear();
}
```

`aT11..aT12` and `aT21..aT22` are the two edges' whole ranges, `aTi**` the merged common range. So
the part is an **edge when the overlap covers the whole of one of the two edges**, and a vertex
otherwise. The probe predicts each fixture from that rule alone and the kernel agrees on all seven
arc cases:

| fixture | a | b | overlap | type | predicted |
|---|---|---|---|---|---|
| A (#2994 row 1) | `[0, pi]` | `[pi/2, 3pi/2]` | `[pi/2, pi]` | VERTEX | VERTEX |
| B (#2994 row 2) | `[0, pi]` | `[pi/4, 3pi/4]` | all of b | EDGE | EDGE |
| C | `[0, pi]` | `[pi/2, pi]` | all of b | EDGE | EDGE |
| D | `[pi/4, 3pi/4]` | `[0, pi]` | all of a | EDGE | EDGE |
| E | `[0, pi]` | `[0, pi]` | both | EDGE | EDGE |
| F | `[0, pi/2]` | `[pi/4, 3pi/4]` | `[pi/4, pi/2]` | VERTEX | VERTEX |
| G | `[0, pi/2]` | `[pi/4, pi/2]` | all of b | EDGE | EDGE |

So #2994's guess, that the trigger is the overlap reaching an edge endpoint, is wrong: C and G
both end at `a`'s own last parameter and both come back `EDGE`. The trigger is whole-range
coverage, and the behaviour is deliberate rather than accidental.

**The vertex-typed part still carries the whole overlap.** Fixture A's `Range1()` is
`(1.570796297, 3.141592654)`, the real `[pi/2, pi]`, with `VertexParameter1 = 2.356194475`
(`3pi/4`) beside it. `IntTools_CommonPrt::Type()` is a directive to the consumer, not a claim that
the coincidence is pointlike.

## The one real inconsistency: line/line answers the same question differently

`IntTools_EdgeEdge::Perform` short-circuits two straight edges into `ComputeLineLine`
(`IntTools_EdgeEdge.cxx:901-989`), which never reaches `MergeSolutions` and types **every**
coincident overlap `TopAbs_EDGE` (`:989`), whole-range or not. Fixture H, two collinear segments
overlapping over x in `[1, 2]` and covering neither edge, comes back `EDGE`, where the geometrically
identical arc fixture A comes back `VERTEX`. Same class, same question, two answers, decided by
curve type.

## What OCCT's own consumer does with each, and why neither breaks a boolean

`BOPAlgo_PaveFiller::PerformEE` (`BOPAlgo_PaveFiller_3.cxx:145`) is the only production caller.

* **`TopAbs_VERTEX`** builds a new vertex at `IntTools_Tools::VertexParameters`, but first discards
  the part when the found parameter sits on a pave at both ends
  (`:368-375`, `if ((bIsOnPave[0] && bIsOnPave[2]) || ... ) continue;`). Fixture A meets that test
  on the reading of the source, since the overlap ends at `a`'s own last parameter and begins at
  `b`'s own first, and the measurement agrees the part was dropped: had it been acted on, `a`
  would carry a third split at `3pi/4` and it carries two pieces, not three.
* **`TopAbs_EDGE`** is acted on only when `aPB1->HasSameBounds(aPB2)` (`:528-533`), and otherwise
  `break`s, dropping the part. Fixture B's pave blocks do not have the same bounds, so that one is
  dropped too.

Both answers are therefore discarded by the kernel's own consumer on these inputs, and the BOP
still gets the geometry right, because `PerformVE` has already split both edges at the other's
bounding vertices before `PerformEE` runs. The probe's General Fuse section measures it: fixture A
splits `a` into `(0, pi/2)` and `(pi/2, pi)` and `b` into `(pi/2, pi)` and `(pi, 3pi/2)`, three
edges in all, so the shared quarter arc is one edge and not two. Fixture B splits `a` into three
and leaves `b` whole, also three edges. Neither result contains a vertex at `3pi/4`.

## Verdict

Not a kernel defect in the sense of a wrong computation. `Range1()` and `Ranges2()` are the true
overlap in both rows, and `Type()` is advice to a boolean operation about whether to make a vertex
or to merge two pave blocks, not a classification of the geometry. A caller cannot read it as
"vertex means they touch at a point".

The line/line versus curve/curve disagreement is a genuine wart and is **held for the OCCT 8.0.2
survey** rather than filed upstream now, alongside #2991 and #2992.
