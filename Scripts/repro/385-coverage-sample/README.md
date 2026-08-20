# Pass 4a coverage sample (#385)

Two throwaway detectors written to answer one question: when this wrapper reaches an OCCT class,
how much of that class does it actually reach, and does the part it does reach do what its
signature says?

Both are **screening tools, not gates**. Neither is wired into CI. Read the caveats.

## `occt-class-coverage.py <Class> [<Class> ...]`

Counts public methods declared in the pinned header against the distinct methods our bridge
invokes on that class.

Sample taken 2026-08-20 against the pinned 8.0.1 kernel:

| OCCT class | public | we call | cover |
|---|---:|---:|---:|
| `XCAFDimTolObjects_DatumObject` | 38 | 2 | 5% |
| `XCAFDimTolObjects_DimensionObject` | 78 | 8 | 10% |
| `XCAFDimTolObjects_GeomToleranceObject` | 40 | 4 | 10% |
| `Draft_FaceInfo` | 9 | 1 | 11% |
| `Draft_VertexInfo` | 9 | 1 | 11% |
| `Draft_EdgeInfo` | 15 | 2 | 13% |
| `Plate_Plate` | 23 | 4 | 17% |
| `GeomPlate_BuildPlateSurface` | 34 | 7 | 21% |
| `BRepFeat_Gluer` | 9 | 2 | 22% |
| `BRepFeat_MakeDPrism` | 13 | 3 | 23% |
| `XCAFDoc_DimTolTool` | 39 | 9 | 23% |
| `BRepFeat_SplitShape` | 10 | 4 | 40% |
| `BRepOffsetAPI_ThruSections` | 27 | 12 | 44% |
| `GeomPlate_BuildAveragePlane` | 8 | 5 | 62% |
| `ShapeFix_Face` | 34 | 28 | 82% |
| `BRepFeat_MakeCylindricalHole` | 8 | 7 | 88% |

**Two caveats, both load-bearing.**

The denominator counts `Set*` and `DumpJson`, so the ratio overstates missingness for any class we
deliberately read but never write. It screens, it does not adjudicate. `ShapeFix_Face` at 82% and
`BRepFeat_MakeCylindricalHole` at 88% are the controls that say the metric has signal at all.

**It was wrong the first time it ran, in a way worth recording.** Scanning only
`Sources/OCCTBridge/src/*.mm` reported `BRepFeat_MakeCylindricalHole` at **0%**, which CLAUDE.md's
own Known OCCT Bugs entry for #532 contradicts outright. The calls live in
`occtBRepFeatCylindricalHole` in `OCCTBridge_Internal.h`, and this repo deliberately hosts shared
helpers there (CLAUDE.md's reach rule). A `.mm`-only scan is therefore blind to precisely the
most-shared call sites. The fix is one line, `ALL` now includes the in-src headers, and it moved that
class from 0% to 88%.

## `detect-dead-parameters.py`

Bridge functions that declare a named parameter and never read it: the caller's input cannot affect
the answer.

Reports **13**. All eleven checked by hand are reachable from public Swift API. The starkest:
`OCCTGeomPlateErrors` (`OCCTBridge_ProjLib_NLPlate.mm:1309`) takes `maxDegree` and `maxSegments`,
then hardcodes `GeomPlate_BuildPlateSurface builder(3, 10, 5, tolerance)`. Its Swift face,
`Surface.plateErrors(points:tolerance:maxDegree:maxSegments:)`, documents defaults of 8 and 9.

**Caveat.** The first run reported 36. Twenty-three were unnamed parameters in `OCCTBridge_BRepGraph.mm`'s
deliberate ABI no-op stubs, which are documented as such at `:4872` and are not defects. The filter
now skips parameters whose "name" is a bare type. Whether Swift honestly exposes those no-ops is a
separate question this detector does not answer.

## Why these are not gates

Both were written to size a problem, not to hold a line. Promoting either needs a measured
false-positive rate over a hand-adjudicated sample, per the precedent
`Scripts/census-doc-occt-attribution.py` set in #928 (41% over 40 rows, which is why it reports
rather than gates). Neither has one yet.
