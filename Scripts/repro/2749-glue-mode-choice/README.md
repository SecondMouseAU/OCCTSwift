# #2749: `BOPAlgo_GlueShift` vs `BOPAlgo_GlueFull` for `Shape.glue`

## The question

`OCCTShapeGlue` (`Sources/OCCTBridge/src/OCCTBridge_Modeling_Boolean.mm`) hardcodes
`BOPAlgo_GlueShift`. `BOPAlgo_GlueEnum.hxx` documents the two non-off values as:

- `BOPAlgo_GlueShift`: shapes with **partial** coincidence, faces overlap but are not fully
  coincident and are split during the operation.
- `BOPAlgo_GlueFull`: shapes with **full** coincidence, no partial overlap of the faces, so no
  face is split at all.

`Shape.glue`'s own doc comment ("Glue two shapes together at coincident faces... when shapes have
faces that perfectly align") describes full coincidence, not partial. Neither #2735 nor #2740
measured `GlueFull`; this probe does, and adds an input where the faces are not coincident at all,
per the issue.

## Fixtures

`probe.mm` builds five fixtures. Fixtures 1-3 use the same argument+tool `BRepAlgoAPI_Fuse` shape
#2735/#2740 fixed `OCCTShapeGlue` to use (`shape1` as the argument, `shape2` as the tool); each is
run once per glue mode (`GlueOff`/`GlueShift`/`GlueFull`), reporting solids/faces/volume and mean
wall time over repeated runs (a single run of a two-box fuse is microseconds, dominated by
scheduler noise; see below).

1. **Exactly coincident shared face**, reused verbatim from
   `Scripts/repro/2735-shape-glue-mode/probe.mm`'s fixture 1 (box2 flush on box1 at z=10,
   fuzzy=1e-6).
2. **Gap inside the caller's tolerance, outside OCCT's default confusion precision**, reused
   verbatim from that probe's fixture 2 (gap=5e-5, tolerance=1e-3).
3. **Not coincident at all** (new for #2749): box2 offset 1.0 unit past the shared face, three
   orders of magnitude past the 1e-3 tolerance passed as the fuzzy value, so neither the geometry
   nor the fuzzy bound bring the two solids into contact.
4. **Supplementary, not one of the three the issue names.** Fixtures 1-3 never move the needle on
   wall time: repeated full runs of the probe disagree on which mode is faster by more than the
   gap between them, which is not a useful measurement. Two 12x12 grids of unit boxes, stacked as
   two compounds sharing 144 coincident unit faces, give the algorithm enough FACE/FACE candidate
   pairs for the documented "up to 90%" glue speedup to show above scheduler noise, while still
   going through the same single-argument/single-tool `BRepAlgoAPI_Fuse` shape `Shape.glue` uses.
5. **Supplementary, not one of the three the issue names.** Genuine **partial** face coincidence,
   which is not one of `Shape.glue`'s target cases but is exactly the geometry
   `BOPAlgo_GlueEnum.hxx`'s own warning is about ("Setting inappropriate option for the operation
   is likely to lead to incorrect result"). Box2 is shifted 3 of its 10 units in X, so 7 of the 10
   units overlap: neither face is a superset of the other, so a correct fuse must split both faces
   along the overlap boundary, which `GlueFull`'s own doc comment says it skips.

## Results

Full output: `transcript.txt`. One representative run (values shift a few percent between runs at
fixtures 1/2/3/5's scale; fixture 4's ordering is the one that held across six separate runs, see
below):

| Fixture | Mode | IsDone | solids | faces | volume | avg wall time |
|---|---|---|---|---|---|---|
| 1 exact coincidence | Off | true | 1 | 10 | 2000 | 6420us (n=200) |
| 1 exact coincidence | Shift | true | 1 | 10 | 2000 | 6258us (n=200) |
| 1 exact coincidence | Full | true | 1 | 10 | 2000 | 4734us (n=200) |
| 2 gap within tolerance | Off | true | 1 | 10 | 2000 | 5390us (n=200) |
| 2 gap within tolerance | Shift | true | 1 | 10 | 2000 | 3871us (n=200) |
| 2 gap within tolerance | Full | true | 1 | 10 | 2000 | 3348us (n=200) |
| 3 not coincident at all | Off | true | 2 | 12 | 2000 | 1322us (n=200) |
| 3 not coincident at all | Shift | true | 2 | 12 | 2000 | 1323us (n=200) |
| 3 not coincident at all | Full | true | 2 | 12 | 2000 | 1118us (n=200) |
| 4 (supplementary) 144 coincident faces | Off | true | 144 | 1440 | 288 | 1243626us (n=20) |
| 4 (supplementary) 144 coincident faces | Shift | true | 144 | 1440 | 288 | 1127416us (n=20) |
| 4 (supplementary) 144 coincident faces | Full | true | 144 | 1440 | 288 | 810598us (n=20) |
| 5 (supplementary) partial overlap | Off | true | 1 | 12 | 2000 | 4545us (n=200) |
| 5 (supplementary) partial overlap | Shift | true | 1 | 12 | 2000 | 3944us (n=200) |
| 5 (supplementary) partial overlap | Full | true | 1 | 12 | 2000 | 2953us (n=200) |

**Topology and volume are identical across all three glue modes on every fixture**, including
fixture 3 (correctly stays a 2-solid compound under every mode: gluing never merges solids that
are not actually touching) and fixture 5 (correctly stays 1 solid, 12 faces, matching the
non-glued fuse, even though this is the specific misuse case `BOPAlgo_GlueEnum.hxx` warns about).
On this one axis-aligned partial-overlap case, `GlueFull` did not produce an observably wrong
result; that is one measured case, not a proof that `GlueFull` is safe on every partial-overlap
input, since neither mode checks its own precondition.

**Wall time at fixtures 1/2/3/5's scale is noise-dominated.** Six full runs of fixture 1-3-scale
fixtures show `GlueShift` and `GlueOff` trading places, sometimes by more than the reported gap; no
conclusion is drawn from those numbers beyond "no mode is reliably slower on these three inputs."

**Fixture 4 is the discriminator.** `GlueFull` was the fastest of the three modes in **6 of 6**
full probe runs, ahead of `GlueShift` by margins from about 6% to about 33% across those runs (for
example 810598us vs 1127416us above, a 28% gap). `GlueShift` vs `GlueOff` ordering was not stable
across runs on this machine under load, but `GlueFull` beat both in every run. This matches
`BOPAlgo_GlueEnum.hxx`'s own accounting: `GlueFull` skips VERTEX/FACE, EDGE/FACE **and** FACE/FACE
intersection for full coincidence, while `GlueShift` still computes FACE/FACE intersections to
support the partial-overlap case it exists for, so `GlueFull` doing strictly less work than
`GlueShift` on exactly the geometry `Shape.glue` targets (full coincidence) is expected, not a
surprise.

## Conclusion

`GlueFull` is the correct choice for `Shape.glue`: identical results to `GlueShift` on every
fixture measured, a repeatable wall-time advantage once the fixture is large enough to move past
scheduler noise, and it is the option OCCT's own documentation names for exactly the case
`Shape.glue`'s doc comment already claims to serve (faces that "perfectly align"). See
`Sources/OCCTBridge/src/OCCTBridge_Modeling_Boolean.mm`'s `OCCTShapeGlue` for the change and its
inline comment, and `docs/reference/Shape-Features.md` for the wrapper's own writeup.

This does not extend to `Shape.fused(with:glue:)`, `.subtracted(_:glue:)`, `.intersected(with:glue:)`,
or the underlying `union(_:fuzzyValue:glue:timeout:)`/`subtracting(...)`/`intersection(...)`
family: those already expose `BooleanGlue`/`GlueMode` as an explicit caller-chosen parameter
(default `.off`, no gluing), rather than hardcoding a mode, so there is no hardcoded choice to
revisit there. `#2749` is specifically about `Shape.glue`'s own hardcoded default.

## Reproducing

```bash
swift build   # resolves the pinned OCCT.xcframework into .build/artifacts/<scheme>/OCCT
XCF=".build/artifacts/$(ls .build/artifacts)/OCCT/OCCT.xcframework/macos-arm64"
clang++ -std=c++17 -ObjC++ -w -I"$XCF/Headers" -L"$XCF" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2749-glue-mode-choice/probe.mm -o /tmp/occt_probe_2749
/tmp/occt_probe_2749
```

Full output of one run: `transcript.txt` in this directory.
