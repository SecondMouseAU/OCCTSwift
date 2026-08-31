# #820: refman coverage audit, Phase 6 whole-surface reconciliation

Five files:

| file | what it is |
|---|---|
| `lane_loader.py` | imports each of the nine source lanes' own `refman_census.py` and re-runs its own `LANE_CLASSES`/`classify()`, in that lane's own calling convention (two shapes, `verify_shapes()` checks both are still what's on disk). No lane's verdicts are retyped. |
| `derive_substrate.py` | the fifteen #1045 "substrate" packages, re-derived fresh from the pinned headers (337 classes, not #1045's own undercounted 331; see its own docstring). |
| `substrate_audit.py` | the audit #1045 assigned Phase 6: every one of the 337 substrate classes gets a verdict, mechanical wrapped/documented test first, then a curated table read against `occt-refman@8.0.1` for what's left. |
| `whole_surface_union.py` | the artifact this issue asks for: unions the nine lanes + the substrate audit, diffs against the full 6,774-header pinned surface, reports the reconciliation. |
| `selftest.py` | `--self-test`'s four cases, each proven to fail first per `okf/policies/prove-the-test-fails.md`. |

```bash
python3 Scripts/repro/820-refman-coverage-whole-surface/whole_surface_union.py             # the report
python3 Scripts/repro/820-refman-coverage-whole-surface/whole_surface_union.py --verbose   # + substrate per-class rows
python3 Scripts/repro/820-refman-coverage-whole-surface/whole_surface_union.py --self-test
python3 Scripts/repro/820-refman-coverage-whole-surface/substrate_audit.py                 # the substrate table alone
python3 Scripts/repro/820-refman-coverage-whole-surface/derive_substrate.py                # the fresh 337-class count
```

All run from any cwd. Needs `Libraries/OCCT.xcframework` (pinned headers) and `Libraries/occt-src`
(module layout for the residue breakdown); reports SKIPPED (exit 2) without them, the normal case in
CI and a fresh clone.

## Result

| | count |
|---|---|
| nine source lanes (#808, #809, #810, #811, #812, #813, #814, #982, #983), reproduced exactly | 1,730 |
| substrate audit (#1045's fifteen packages, Phase 6's own) | 337 |
| **covered total** | **2,067** |
| shipped headers (pinned `Headers/*.hxx`) | 6,774 |
| residual | 4,707 |

The nine lanes are re-derived by import, not retyped: `lane_loader.rows_for_lane(issue)` reproduces
each lane's own previously-published total exactly (151, 126, 278, 129, 93, 192, 368, 51, 342 =
1,730) using only that lane's own `LANE_CLASSES`/`classify()`, and finds zero classes claimed by two
lanes.

The substrate audit is new work (nobody had done it): 80 of 337 already wrapped/documented, the
other 257 curated and recorded in `docs/occtswift-wrapping-gaps.md`'s new "Substrate packages" section.

The residual 4,707 splits three ways (see `docs/occtswift-wrapping-gaps.md`'s "Phase 6 whole-surface
reconciliation" section for the full breakdown and disposition of each):

- **642, real bridge presence, claimed by no lane's table** -- the headline finding. Not a wrapping
  gap (the classes ARE wrapped); a partition gap in #820's own sense, filed as a follow-up rather
  than absorbed here.
- **3,983, neither wrapped, documented, nor recorded** -- overwhelmingly `DataExchange` (STEP/IGES
  internal data model) and the legacy pre-`BOPAlgo` `TopOpeBRep*` engine, matching this file's
  long-standing "What's Not Wrapped (by design)" table, now measured precisely by module for the
  first time. Bucketed, not censused; see the doc section for exactly what was and wasn't
  individually spot-checked.
- **82, documented-only or gaps.md-only** -- mostly bare `<Package>.hxx` stems picked up
  incidentally by toolkit-summary prose, not separately adjudicated.

## What this pass did not do

- **The 642 wrapped-but-unaudited classes across ~120 packages were not individually re-audited
  to the standard the nine source lanes hold themselves to.** That is several more Pass-sized
  efforts (`ShapeFix`/`ShapeAnalysis`/`ShapeUpgrade`/`ShapeCustom` healing family, `BOPAlgo`/`BOPDS`/
  `BOPTools`/`IntTools`/`Gcc*` boolean/construction family, `math`/`Geom`/`Geom2d`/`gce`/`Extrema`
  foundation geometry, and smaller `Visualization`/`FoundationClasses` pockets), out of proportion
  to a reconciliation pass. Filed as a follow-up.
- **The 3,983-class "neither" residual was bucketed by OCCT source module and spot-checked, not
  censused.** Roughly 40 classes were read directly against `occt-refman@8.0.1` across the
  substrate audit plus a handful of `TopOpeBRepDS`/`IGESGeom`/`StepShape`/`Vrml` spot-checks; the
  rest rest on the module-level bucketing plus this file's own pre-existing "What's Not Wrapped (by
  design)" categorisation.
- **Not every concrete subclass of every abstract base in the substrate audit was individually
  re-verified as wrapped** (checked directly only for `GeomFill_TrihedronLaw`'s four subclasses).
- **The `documented-only`/`gaps.md-only` residual (82 classes) was not individually adjudicated**:
  most are bare package-utility header stems picked up by incidental prose, a low-confidence signal
  #812's own README already flags for the identical shape.

See [`docs/occtswift-wrapping-gaps.md`](https://github.com/SecondMouseAU/OCCTSwift/blob/main/docs/occtswift-wrapping-gaps.md)'s
"Substrate packages" and "Phase 6 whole-surface reconciliation" sections for the full writeup.
