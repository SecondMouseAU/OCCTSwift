# OCCTSwift#570, the healing paths that accept an approximation on `MaxError() <= tol`

Follow-up to [#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522), which fixed
`AdvApp2Var_ApproxF2var::mma2ce1_` filling the U Jacobi-maxima buffer from the V slot
(`Scripts/patches/0019-*`, upstream [OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418)).
That defect zeroed every patch's **interior** truncation error, so `MaxError()` only ever described
the boundary iso-curves. #522 proved the number was wrong. This is about the kernel healing sites
that make an **accept/reject decision** on it, where a zero turns into a wrong shape rather than a
wrong diagnostic.

**Answer: yes, two of them returned a materially wrong surface, and the third is what put the other
two on the collapsing continuity in the first place.** A face on an offset sphere came back from
`ShapeCustom::ConvertToBSpline` as a degree-1, 2-pole fit deviating by **24**, the offset sphere's
own diameter, and from `ShapeCustom::BSplineRestriction` as a **single-pole** periodic surface
deviating by **23.9999 against a 0.01 tolerance**. Both were accepted as meeting tolerance. Both are
reachable from six public Swift entry points. No kernel or bridge change is needed: `0019` already
fixes all of it, and this issue's deliverable is the measurement plus the regression tests that pin
it (`Tests/OCCTShapeHealingTests/Issue570HealingApproxTests.swift`).

## The three sites

| site | decision | continuity |
|---|---|---|
| `ShapeConstruct.cxx:268` | `anApprox.MaxError() <= Tol3d && Done` | caller's, looped down to 0 on exception |
| `ShapeCustom_BSplineRestriction.cxx:856` | `anApprox.MaxError() <= myTol3d` | caller's, degraded to 0 by the degree-priority loop |
| `ShapeCustom_ConvertToBSpline.cxx:148` | calls the first | **forces `GeomAbs_C0` for any offset surface** |

The third does not construct an approximation itself. It calls `ShapeConstruct::ConvertSurfaceToBSpline`
and overrides the requested continuity for offset surfaces:

```cpp
GeomAbs_Shape cnt = surf->Continuity();
if (surf->IsKind(STANDARD_TYPE(Geom_OffsetSurface)))
{
  cnt = GeomAbs_C0; // pdn 30.06.99 because of hang-up in GeomConvert_ApproxSurface
}
```

So that path did not *degrade into* the collapsing continuity, it **started there**.

## Running it

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/570-healing-approx-accept/occt_570_healing_fingerprint.mm -o /tmp/occt_570
/tmp/occt_570
```

No fixture file is needed. `fingerprint-before.txt` and `fingerprint-after.txt` are the full
transcripts either side of `0019`.

### Getting the "before" side

`0019` is one character, so the cheapest before/after is the `-O0` single-TU override-link from
#310/#348/#522 rather than a kernel rebuild. Copy
`Libraries/occt-src/src/ModelingData/TKGeomBase/AdvApp2Var/AdvApp2Var_ApproxF2var.cxx`, put the
first `mma2jmx_` call back on `ipt5`, compile it standalone and link the `.o` **before**
`-lOCCT-macos`:

```bash
clang++ -c -std=gnu++17 -O0 -g -w -DNDEBUG -DNo_Exception -DOCC_CONVERT_SIGNALS \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -I"Libraries/occt-src/src/ModelingData/TKGeomBase/AdvApp2Var" \
  /tmp/AdvApp2Var_ApproxF2var_stock.cxx -o /tmp/f2var_stock.o
clang++ -std=c++17 -ObjC++ -w -I... -L... \
  Scripts/repro/570-healing-approx-accept/occt_570_healing_fingerprint.mm /tmp/f2var_stock.o \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o /tmp/occt_570_stock
```

`-DNo_Exception` matters, the production kernel is built with it
(`BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`), and an override TU compiled without it reintroduces
`*_Raise_if` preconditions the shipped kernel does not have.

**Both transcripts here are `-O0` override-linked builds**, one with the reverted character and one
with an unmodified copy of the same file. Comparing a stock `-O0` override against the shipped `-O2`
archive would drift the deviation figures in the sixth significant digit on unrelated rows; comparing
two `-O0` overrides isolates the one character. The unmodified override was checked against the plain
shipped archive first: identical degrees, poles and knots everywhere, deviations agreeing to ~6
significant figures.

## What moved

### `ShapeCustom::ConvertToBSpline`, forced-C0 branch

| fixture | before | after |
|---|---|---|
| offset(sphere r=10, +2), full domain | deg 1x10, 2x11 poles, **dev 24** | deg 13x10, 14x11 poles, dev 1.21e-7 |
| every other offset fixture | unchanged | unchanged |
| `offset=false` (convert the basis instead) | unchanged | unchanged |

`Precision::Approximation()` is `1e-6`, so a 24 mm deviation was accepted as meeting a micron
tolerance. The fit was a straight chord across the full 2π of longitude.

### `ShapeCustom::BSplineRestriction` (tol3d = 0.01, maxDeg = 9)

| fixture | before | after |
|---|---|---|
| offset(sphere r=10, +2), full domain | deg 1x7, **1x8 poles**, dev 23.9999 | deg 9x7, 9x8 poles, dev 5.06e-4 |
| every other fixture, every continuity | unchanged | unchanged |

One pole in a periodic direction: the whole U direction collapsed to a point. Identical at C0, C1 and
C2, with `degreePriority` the outer loop degrades continuity toward 0 whenever the requested one
cannot meet the tolerance within `maxDegree`, and the full sphere cannot at degree 9. So requesting
C2 was not protection.

### Nothing else moved

Ten fixtures across five probes. Everything outside those two rows is byte-identical between the two
kernels, including:

- **Elementary surfaces never reach the approximator.** `ConvertSurfaceToBSpline` short-circuits
  `Geom_ElementarySurface` to `GeomConvert::SurfaceToBSplineSurface` (exact, rational) before the
  loop. Probed directly (section 2 of the transcript), a plain sphere collapses at C0 exactly like
  its offset does, deg 1x10, dev 20, so the short-circuit, not the input, is what kept planes,
  cylinders, cones, spheres and tori out of this.
- **The offset sphere trimmed clear of its poles** (V ∈ [-1, 1]) is unaffected, matching #522: the
  collapse needs the degenerate V-boundary isos that trimming removes. This is the whole reason the
  existing tests missed it, every pre-existing test of these entry points uses a box or a cylinder.
- C1 and C2 requests to `ConvertSurfaceToBSpline`, on every fixture. The reported `MaxError()` is
  uniformly a little larger after the fix (the interior contribution is counted for the first time),
  but no result changed.

## Reachable from this wrapper

Six public Swift entry points, all confirmed against the released `v1.15.18` kernel:

| Swift | bridge | verdict |
|---|---|---|
| `Shape.convertedToBSpline()` | `OCCTShapeConvertToBSpline` | **wrong shape** (offset hardcoded true) |
| `Shape.withSurfacesAsBSpline(offset:)` | `OCCTShapeCustomConvertToBSpline` | **wrong shape** (offset defaults true) |
| `Shape.convertToBSplineAdvanced(_:offsetMode:)` | `OCCTShapeConvertToBSplineAdvanced` | **wrong shape** (offsetMode defaults true) |
| `Shape.bsplineRestriction(surfaceTolerance:…)` | `OCCTShapeBSplineRestriction` | **exceeds its tolerance** |
| `Shape.bsplineRestriction(tol3d:…continuity3d:…)` | `OCCTShapeCustomBSplineRestriction` | **exceeds its tolerance**, at C0/C1/C2 alike |
| `Shape.bsplineRestrictionAdvanced(…)` | `OCCTShapeBSplineRestrictionAdvanced` | **exceeds its tolerance** |

`Issue570HealingApproxTests` covers all six. Run against the released kernel
(`OCCTSWIFT_REMOTE=1 swift test --filter Issue570HealingApproxTests`) six of its seven tests fail
with those figures, and the seventh, the pole-trimmed control, passes.

## The 1999 workaround: keep it

The issue asked whether `cnt = GeomAbs_C0` is still needed now that the approximator's degree search
works. Section 5 of the harness times the request it suppresses, `ConvertSurfaceToBSpline` at
`surf->Continuity()`: on both kernels.

All seven offset fixtures report `Continuity() == GeomAbs_CN`, which
`ConvertSurfaceToBSpline` clamps to `GeomAbs_C3`. On both kernels that request completes in **under
5 ms**, and its results are **identical before and after `0019`**, the collapse never reaches C2/C3,
so the suppressed request was never affected by #522 at all.

That is an argument for leaving the workaround alone, not for removing it:

- It produces **no evidence the hang is gone**, because it produces no evidence the hang ever existed
  for these inputs. The comment blames a hang; #522 is not a hang; retiring a hang guard needs a
  reproduction of the hang, and there is none. Seven fixtures that do not hang either way is not that.
- Post-`0019` the workaround now **costs nothing measurable**. Forced C0 returns deg 13x10 where the
  own-continuity request returns 15x12, a slightly coarser fit, 1.21e-7 against 1.37e-8, both
  comfortably inside the 1e-6 tolerance.

What the measurement *does* establish is worth recording: the forced C0 is exactly what routed every
offset surface into the collapse. A workaround added in 1999 for one defect is what made a different
defect, found in 2026, reachable from this wrapper. It is correct today and it stays.

## Not filed upstream

`0019` is already filed as [OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418) and fixes
every row above. Nothing here is a separate kernel defect, the three healing sites are behaving
correctly given a correct `MaxError()`.
