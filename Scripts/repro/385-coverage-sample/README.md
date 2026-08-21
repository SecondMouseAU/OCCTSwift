# Pass 4a coverage sample (#385)

Three throwaway detectors written to answer one question: when this wrapper reaches an OCCT class,
how much of that class does it actually reach, and does the part it does reach do what its
signature says?

All three are **screening tools, not gates**. None is wired into CI.

**All three now have a measured false-positive rate**, which is what #1001 asked for before anything
re-sweeps with them. The measurement, the hand-adjudicated samples, the scoring script and the
per-detector recommendation live in
[`Scripts/repro/1001-detector-fp-rates/`](../1001-detector-fp-rates/README.md). The short version:

| detector | false-positive rate | recommendation |
|---|---:|---|
| `detect-hardcoded-arguments.py` | **81.5%** over a 27-row census | do not re-sweep with it; the criterion is the problem |
| `detect-dead-parameters.py` | **0%** over a 13-row census | use it, the strongest of the three |
| `occt-class-coverage.py` | **20.0%**, fixed to **0%** over the same 40 rows | use it as a screen, not as a metric |

Two of the three were changed by that work, and the changes are described in each script's own
docstring rather than here.

## `occt-class-coverage.py <Class> [<Class> ...]`

Counts public methods declared in the pinned header against the distinct methods our bridge invokes
on that class.

Sample re-taken 2026-08-21 against the pinned 8.0.1 kernel, **after** #1001 fixed the four causes
of denominator inflation (default arguments, private sections, macros, and calls inside inline
bodies read as declarations):

| OCCT class | public | we call | cover |
|---|---:|---:|---:|
| `Draft_FaceInfo` | 9 | 0 | 0% |
| `Draft_VertexInfo` | 9 | 0 | 0% |
| `Draft_EdgeInfo` | 15 | 0 | 0% |
| `GeomPlate_BuildPlateSurface` | 18 | 4 | 22% |
| `BRepFeat_MakeDPrism` | 13 | 3 | 23% |
| `XCAFDoc_DimTolTool` | 39 | 9 | 23% |
| `BRepFeat_Gluer` | 8 | 2 | 25% |
| `Plate_Plate` | 12 | 4 | 33% |
| `XCAFDimTolObjects_DimensionObject` | 70 | 28 | 40% |
| `XCAFDimTolObjects_GeomToleranceObject` | 40 | 16 | 40% |
| `BRepFeat_SplitShape` | 9 | 4 | 44% |
| `XCAFDimTolObjects_DatumObject` | 38 | 19 | 50% |
| `BRepOffsetAPI_ThruSections` | 23 | 12 | 52% |
| `GeomPlate_BuildAveragePlane` | 6 | 5 | 83% |
| `ShapeFix_Face` | 32 | 28 | 88% |
| `BRepFeat_MakeCylindricalHole` | 7 | 7 | 100% |

**Two caveats, both still load-bearing.**

The denominator still counts `Set*` and `DumpJson`, so the ratio overstates missingness for any
class we deliberately read but never write. Those are not false positives, they are real public
methods this bridge does not call, and no parser fix removes them. It screens, it does not
adjudicate. `ShapeFix_Face` at 88% and `BRepFeat_MakeCylindricalHole` at 100% are the controls that
say the metric has signal at all, and the second of those reaching 100% is how the #1001 parser
fixes were checked: CLAUDE.md documents that class as fully wrapped.

**It was wrong the first time it ran, in a way worth recording.** Scanning only
`Sources/OCCTBridge/src/*.mm` reported `BRepFeat_MakeCylindricalHole` at **0%**, which CLAUDE.md's
own Known OCCT Bugs entry for #532 contradicts outright. The calls live in
`occtBRepFeatCylindricalHole` in `OCCTBridge_Internal.h`, and this repo deliberately hosts shared
helpers there (CLAUDE.md's reach rule). A `.mm`-only scan is therefore blind to precisely the
most-shared call sites. The fix is one line, `ALL` now includes the in-src headers.

The earlier version of this table (taken 2026-08-20) is superseded twice over: by the parser fixes,
and by Pass 4a's own landed work. `Draft_*` reads 0% rather than ~12% because #1000 deleted
`DraftInfo`, and the three `XCAFDimTolObjects_*` classes rose because the GD&T work landed between
the two runs.

## `detect-dead-parameters.py`

Bridge functions that declare a named parameter and never read it: the caller's input cannot affect
the answer.

Reports **0** on today's tree, and **13** at Pass 4a's branch point, which is #999's output. All
thirteen are real, adjudicated one at a time, and cross-checked against
`clang -Wunused-parameter`, which agrees on all fourteen distinct `(file, parameter)` pairs with no
disagreement in either direction.

**Caveat.** The first run reported 36. Twenty-three were unnamed parameters in
`OCCTBridge_BRepGraph.mm`'s deliberate ABI no-op stubs, which are documented as such at `:4872` and
are not defects. Those are still filtered, now by token count rather than by the name-suffix
heuristic #1001 replaced. Whether Swift exposes those no-ops is a separate question this detector
does not answer.

## `detect-hardcoded-arguments.py`

Bare numeric literals passed as arguments to an OCCT constructor or method: the input-side mirror of
#726, which looks at what a function returns.

Reports **23** on today's tree and **27** at Pass 4a's branch point. Two of the 23 are real. The
measurement in #1001 recommends against re-sweeping with it, and says why: the criterion has no
notion of whether the enclosing function has a parameter the literal could be displacing, which is
the shape #1020 actually describes.

## Why these are not gates

All three were written to size a problem, not to hold a line. Promoting any of them needs a measured
false-positive rate over a hand-adjudicated sample, per the precedent
`Scripts/census-doc-occt-attribution.py` set in #928 (41% over 40 rows, which is why it reports
rather than gates). They now have one each, and on those numbers only
`detect-dead-parameters.py` is a plausible candidate; see
[`Scripts/repro/1001-detector-fp-rates/`](../1001-detector-fp-rates/README.md) for the full
argument, including the recall figure that has to be read alongside a low false-positive rate.
