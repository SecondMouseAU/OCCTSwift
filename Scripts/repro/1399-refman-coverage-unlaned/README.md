# #1399: the wrapped classes no #807 lane claims

#820's Phase 6 reconciliation found **643 classes with real bridge presence sitting in no lane's
table** and filed the number. This is the lane that turns the number into verdicts.

| file | what it is |
|---|---|
| `derive_lane.py` | the set, derived by importing #820's own union rather than transcribing it, and split by what can check each class. Thirteen self-test cases. |
| `family-substrate.md` | the 26 containers and scalars, adjudicated |
| `family-healing.md` | `ShapeFix`/`ShapeAnalysis`/`ShapeUpgrade`/`ShapeCustom`/`ShapeExtend`, `BRepTools`/`BRepLib`, `BRepBndLib`/`BndLib`/`Bnd_*`, `BRepGProp`/`GProp_*`, `BRepGraph_*` |
| `family-geometry.md` | `Geom`/`Geom2d`/`GeomEval`/`Geom2dEval`, `Convert_*`, `CPnts`, the adaptors, `ElCLib`/`ElSLib`, `LProp`/`Law`, `ProjLib`, the `Gcc` construction family |
| `family-booleans.md` | `BOPAlgo`/`BOPDS`, `IntTools`, `Intf`/`IntAna`/`IntRes2d`, `Extrema_POn*`, `Contap`, `HatchGen`, `FilletSurf` |
| `family-foundation.md` | `math_*`, `OSD`, `Units*`, `Precision`, `Standard`, `IFSelect`/`XSControl`/`RWStl`, `SelectMgr`/`PrsMgr`/`Prs3d` |

```bash
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py              # the partition
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --verbose    # + every class
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --bucket algorithm
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --family healing
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --self-test
```

Runs from any cwd. Needs `Libraries/OCCT.xcframework` and reports SKIPPED (exit 2) without it, the
normal case in CI and a fresh clone.

## The partition, and why it is the finding

| bucket | count | disposition |
|---|---|---|
| machine-covered | 479 | named in a claim `census-doc-occt-attribution.py` parses, so it is re-checked on every run, whole-tree |
| algorithm | 138 | the reading list, four families |
| substrate | 26 | containers and scalars, adjudicated in `family-substrate.md` |

**479 of the 643 were never unchecked.** The nine lanes' own results are the evidence for treating
that as coverage rather than as an excuse: `okf/policies/static-gates.md` records the attribution
census catching **25 of #808's 26 confirmed findings and 6 of #809's 6**, and that detector is not
lane-scoped. Auditing all 643 by hand would spend four passes re-confirming what a script checks on
every push, which is the shape of audit-as-ritual that #377's own anti-drift rule exists to
prevent.

## Two corrections this lane made to itself before reading anything

Both are recorded because a lane that hides its own errors is worth less than one that reports
them.

**A fourth bucket, "ours", was wrong and is gone.** It held `BRepGraph`, `GeomEval` and
`Geom2dEval` on the assumption this project invented them. All three are genuine OCCT packages,
in the pinned kernel and on upstream master with their own GTests: `BRepGraph` in TKBRep, the
evaluators in TKG3d and TKG2d. Their twenty classes are ordinary algorithm classes, which is what
took the reading list from 118 to 138. A self-test case now pins it, since the way to get this
wrong again is to classify by the name rather than by the header.

**The reachability check was blind to a real call site.** Reading `src/*.mm` and `include/*.h`
misses the private headers the bridge keeps in `src/`, so `Prs3d` looked wrapped-by-nothing while
the bridge calls `Prs3d::GetDeflection` from `src/OCCTBridge_Internal.h`. #820's own token cache
reads both directories and was right. Caught by `every-class-is-really-wrapped`, which failed on
exactly one class out of 643 and was worth having for that one.

## Result

| bucket | classes | `ok` | `deliberate, recorded` | `under` | `over` |
|---|---|---|---|---|---|
| healing | 31 | 5 | 6 | 6 | **14** |
| geometry | 44 | 8 | 10 | 1 | **25** |
| booleans | 31 | 19 | 6 | 1 | 5 |
| foundation | 32 | 7 | 18 | 3 | 4 |
| substrate | 26 | 2 | 24 | 0 | 0 |
| **read by hand** | **164** | **41** | **64** | **11** | **48** |
| machine-covered | 479 | adjudicated as findings, not as classes: 212 real, 210 false | | | |

**`over` dominates, and every brief predicted `under`.** The reasoning behind the prediction was
that 70 of the classes are named nowhere in `docs/`, which reads as a documentation gap. It was
wrong in the same way in all four families: the *capability* was documented under its Swift name,
and the OCCT class named beside it was the wrong one. A neighbouring class, a base class, a header
filename, a sub-view of the right object. `measure-dont-assume.md` calls this "the adjacent
identifier reads as the one you need"; here it is 48 times.

## The finding that reframes the issue

#1399 was filed as "643 classes nobody audited". The audit found that framing was the smaller
half. **`census-doc-occt-attribution.py` was reporting 431 findings, and nobody had ever read its
output.** Of the 422 in scope, **212 were real**, at a measured false-positive rate of 49.8% (the
sample in `Scripts/repro/928-over-coverage-detector/` had measured 41.0% over 40 rows, so the rate
holds up at eleven times the sample size).

A detector nobody reads is not coverage. That is the durable lesson of this lane, and it is worth
more than the class list that prompted it.

## What the audit corrected in its own instruments

Four, all recorded rather than quietly fixed, because a lane that hides its own errors is worth
less than one that reports them.

1. **The "ours" bucket was a false assumption.** `BRepGraph`, `GeomEval` and `Geom2dEval` are OCCT
   packages, not this project's inventions.
2. **The reachability check missed the bridge's private headers in `src/`**, which made `Prs3d`
   look wrapped-by-nothing.
3. **`docs/CHANGELOG.md` was counting as documentation**, so a class named only in a v0.x entry
   read as documented. Eleven rows across the lane.
4. **The `BRepGraph_EditorView` diagnosis in the census brief was wrong in its mechanism.** It said
   the bridge functions reach entirely different classes; most reach it through `graph.Editor()`.
   The finding was real for a different reason: `BRepGraph_EditorView` is a **header filename**, and
   the class is `BRepGraph::EditorView`. Per-entry reading then separated 8 read-only lookups that
   never touch the editor and 11 naming the wrong `Ops` sub-view, distinctions a blanket rewrite,
   which is what the wrong diagnosis implied, would have erased.

## Code defects found by an audit of documentation

Documentation was the subject; fourteen issues came out of it, because a doc that cannot be made
true against the code is often the code's fault. In rough order of what a caller would notice:

- **#1631**, `Shape.edgeFaceIntersection` finds nothing for any input (fixed in PR #1651)
- **#1652**, eight public `BRepGraph` setters and six getters are silent no-ops on the pinned kernel
- **#1643**, `MathSolver.eigenvalues` discards the *first* subdiagonal element where three doc
  layers said the last, so the documented example computes a different matrix with no error signal
- **#1632**, `ExtremaElSS.planeToSphere` and `sphereToSphere` always return `[]`
- **#1646**, ten `Geom2dEval_*` evaluators abort the process on ordinary arguments (guarded in
  PR #1629)
- **#1634**, `Shape.revolutionToElementary()` runs its own inverse
- **#1638**, `Shape.composeShell` can never split a face
- **#1636**, **#1637**, **#1639**, **#1640**, **#1644**, **#1645**, **#1633**, **#1635**

Plus two defects in the census itself, which is the instrument the machine-covered verdict rests
on: **#1641** (blind to any class whose name ends in an all-uppercase word: 45 claim sites, 14 real
classes) and **#1642** (single-pass type expansion, so a correct attribution can score worse than
the wrong one it replaced).
