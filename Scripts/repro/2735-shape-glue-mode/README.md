# #2735: `OCCTShapeGlue` set no tools, so it always fell back to a plain fuse

## The claim, reproduced

The issue records, as another agent's unverified measurement, that putting both shapes into
`BRepAlgoAPI_Fuse::SetArguments` with no `SetTools` call and `SetGlue(BOPAlgo_GlueShift)` reports
`HasErrors()`/`IsDone() == false`. `probe.mm` reproduces this independently, on two exactly
coincident 10x10x10 boxes:

```
(a) both-as-arguments, no tools, glue on: IsDone=false HasErrors=true
```

Confirmed. The correctly configured operation (`shape1` as the argument, `shape2` as the tool)
succeeds on the same geometry:

```
(b) argument+tool, glue on: IsDone=true HasErrors=false solids=1 faces=10 volume=2000
```

## Looking for a discriminator: glue mode vs. a plain fuse

Per `okf/policies/measure-dont-assume.md`, the probe does not assume gluing mode changes the
*topological* result relative to a plain fuse; it measures both, on two fixtures, and reports
every number rather than the one that was expected. It compares `BRepAlgoAPI_Fuse` against
`BRepAlgoAPI_Fuse`, never against `BRepAlgoAPI_BuilderAlgo` (General Fuse), so this is not #367's
class-mismatch mistake.

**Fixture 1, exactly coincident shared face** (box2 sits flush on box1): `(b)` glue on, `(c)` glue
off, and `(d)` the pre-fix fallback's own two-argument constructor (no glue, no fuzzy value) all
measured **identically**: 1 solid, 10 faces, volume 2000. On genuinely coincident geometry, `SetGlue`
made no measurable topological difference here; the OCCT dev guide describes it as a performance
option ("speed up... in some cases up to 90%"), and this fixture doesn't touch a case large enough
for that to show up as anything but wall-clock time.

**Fixture 2, a gap inside the caller's tolerance but outside OCCT's default confusion precision**
(box2 offset by 5e-5, with `tolerance = 1e-3`): `(e)` glue+fuzzy and `(f)` fuzzy-only (glue off)
again measured identically (1 solid, 10 faces) — so `SetGlue` itself still isn't the discriminator.
**`(g)`, the exact fallback construction the pre-fix bridge code runs
(`BRepAlgoAPI_Fuse(shape1->shape, shape2->shape)`, no `SetFuzzyValue`, no `SetGlue`)**, measured
**2 solids, 12 faces**: a compound of two untouched boxes, not a glued solid.

## The real discriminator: whether the fixed path runs at all

`SetGlue(BOPAlgo_GlueShift)` did not move any measurement in this probe; `SetFuzzyValue(tolerance)`
did. That is consistent with the fix still being correct and worth keeping `SetGlue` for: the bug
was that the missing-tools setup made `IsDone()` false on *every* input regardless of geometry, so
`OCCTShapeGlue` always ran the untoleranced two-argument fallback constructor and never the
argument/tool/glue/fuzzy path the function is named for. The observable symptom a caller can hit is
exactly `(g)` vs `(e)`: near-touching parts that should glue into one body come back as two
unconnected solids in a compound, silently, because the caller's own `tolerance` argument was never
applied. `Tests/OCCTModelingTests/GlueTests.swift`'s `glueAppliesTolerance` asserts `solidCount == 1`
on this fixture and is red on the pre-fix bridge code (measured `solidCount == 2`, matching `(g)`)
and green after the fix (measured `solidCount == 1`, matching `(e)`).

The existing `glueTwoBoxes` test shares an *exactly* coincident face (fixture 1), where `(b)`/`(c)`/`(d)`
all agree — which is exactly why that test kept passing while the bug shipped.

## Reproducing

```bash
swift build   # resolves the pinned OCCT.xcframework into .build/artifacts/<scheme>/OCCT
XCF=".build/artifacts/$(ls .build/artifacts)/OCCT/OCCT.xcframework/macos-arm64"
clang++ -std=c++17 -ObjC++ -w -I"$XCF/Headers" -L"$XCF" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2735-shape-glue-mode/probe.mm -o /tmp/occt_probe_2735
/tmp/occt_probe_2735
```

Full output: `transcript.txt` in this directory.
