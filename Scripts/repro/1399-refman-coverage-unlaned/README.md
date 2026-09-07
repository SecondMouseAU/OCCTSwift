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

<!-- filled in at integration from the four family files -->
