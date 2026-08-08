# #784 duplication rescan

Passes 1a (#380) and 1b (#381) are closed at 60 sub-issues, both built as a segmented *subsystem*
read. On 2026-08-07, six duplications were found in code both passes had already audited, every one
by accident while doing something else. This directory is the derived, re-runnable artifact #784
asks for: a search for others the same way a diff-reader finds them, applied deliberately rather
than by accident.

Run it with:

```bash
python3 Scripts/repro/784-duplication-rescan/detect-duplicate-logic.py            # both scopes
python3 Scripts/repro/784-duplication-rescan/detect-duplicate-logic.py --bridge   # bridge only
python3 Scripts/repro/784-duplication-rescan/detect-duplicate-logic.py --swift    # Swift API only
python3 Scripts/repro/784-duplication-rescan/detect-duplicate-logic.py --self-test
```

It is a census, not a gate: it always exits 0 in report mode (barring a crash or a missing
directory), because its output is a list of candidates for a human to adjudicate, not a verdict on
the tree, matching `census-unmeasured-values.py`'s own convention. `--self-test` exits 1 on a
failed case, like every other `--self-test` in this repo.

## What shape the six actually share

Read from the PR/issue bodies directly, not assumed from #784's own one-line summaries:

| # | Instance | Layer | Shape |
|---|---|---|---|
| 1 | #761/PR#779: `OCCTFaceGetSharedEdgeCount`/`OCCTFaceGetSharedEdges` | bridge | Two entry points, one comparison loop, textually near-identical |
| 2 | PR#768: `OCCTDocumentSetShapeColor`/`OCCTDocumentSetShapeColorRGBA` | bridge | Two entry points, same OCCT class (`XCAFDoc_ColorTool`), near-identical minus the field the bug was in |
| 3 | PR#778: `isRadiallyInwardFillet` vs an inline block in `detectHoles()` | Swift app | A small function's logic copy-pasted from INSIDE a much bigger enclosing function |
| 4 | #777: `PocketFeature.isOpen` vs `BRepGraph`'s indexed incidence | Swift app | Same QUESTION, different ALGORITHM — no shared text |
| 5 | PR#774: a reachability check duplicated between two BRANCHES of one function (`census-unmeasured-values.py`) | tooling | Duplication INSIDE one function, not between two |
| 6 | PR#773: `HarnessRunner.swift`/`CensusRunner.swift` | tooling | Two whole files in `Scripts/repro/`, outside the audited population |

**They are not one shape, they are three, two each**: (A) two independently-discoverable entry
points/functions sharing a near-identical body — the shape #784's own framing assumes is dominant,
and the one this script targets; (B) the same question answered by two different algorithms with no
shared text — not findable by comparing token sequences, named here so its absence from the
findings below reads as a scope boundary, not a miss; (C) duplication inside one function, or
between files outside the population these audit passes cover (dev tooling) — a different detection
problem and a different population, out of scope here, not silently dropped.

"Bridge is where 'wrap the same OCCT class twice' happens" (#784's framing) holds for instances 1-2
but not 3-6: 2 of 6 are bridge, 2 are Swift-app-level (one of those two not text-similar at all), 2
are dev tooling unrelated to OCCT. The dominant shape (A) is confirmed as real and worth searching
for; "bridge first" is right advice for where shape A concentrates, not a claim about the whole
six.

## Algorithm

Full detail in the script's module docstring. Summary: extract every function/method body (bridge:
`Sources/OCCTBridge/src/*.mm`'s C/Objective-C++ functions; Swift: `Sources/OCCTSwift/*.swift`'s
`func` bodies), tokenize, take every consecutive `shingle_k`-token run as a shingle, drop any
shingle whose document frequency (how many distinct functions contain it) is at or above
`boilerplate_min_count` (the necessarily-repetitive C-wrapper preamble this bridge legitimately
repeats hundreds of times), then flag a pair when their surviving shingle sets overlap by at least
`min_shared`, scored as **containment** (`shared / min(|A|, |B|)`, not Jaccard) so a small,
fully-duplicated function registers even when its logic is embedded inside a much bigger caller
(shape 3's own mechanism). A pair where one function's name appears as a token in the other's body
is delegation, not duplication, and is excluded.

This is a MOSS-style clone detector (k-token shingle fingerprinting), chosen because the failure
mode this repo keeps hitting is literal copy-paste, not renamed-but-equivalent logic — every one of
#761/PR#768/PR#778's own PR bodies uses the words "copy-paste" or "reimplemented", not
"coincidentally similar".

## Tuning trace (measure, don't assume)

The first run, at loose settings borrowed from `census-unmeasured-values.py`'s own scale
(`shingle_k=9, boilerplate_ratio=0.04, min_distinctive=10, min_shared=6, containment_threshold=0.6`),
reported **3219 of the bridge's 4152 units as candidate pairs**. Reading a sample confirmed this was
almost entirely noise: `OCCTCurve3DGetDomain`/`OCCTCurve2DGetDomain`-shaped pairs (`Geom_Curve` and
`Geom2d_Curve` are OCCT's own deliberately parallel 3D/2D hierarchies, exposing identically-named
methods by design), `gp_Ax1`/`gp_Ax2` siblings, and — on the Swift side — already-deduplicated
forwarding shims like `gridEvalD0`/`gridEvalD1` (explicitly documented leftovers of #486's own
consolidation). A grep-shaped threshold produces a grep-shaped answer even when the underlying
method is not a grep; tightening was necessary, not optional.

Successive tightenings on the real bridge corpus (4152 units):

| `shingle_k` | `boilerplate_min_count` | `min_distinctive`=`min_shared` | `containment_threshold` | pairs |
|---|---|---|---|---|
| 9 | ratio 0.04 (≈166) | 10 / 6 | 0.60 | 3219 |
| 9 | 5 | 15 / 15 | 0.75 | 240 |
| 9 | 5 | 20 / 20 | 0.80 | 153 |
| 12 | 5 | 20 / 20 | 0.80 | 138 |
| 12 | 4 | 25 / 25 | 0.85 | 47 |
| **15** | **4** | **25 / 25** | **0.85** | **38 (final)** |

Same progression on the Swift corpus (3374 units), same final settings for consistency:
118 → 34 → **21 (final)**.

**`boilerplate_min_count` is an absolute document-frequency cutoff, not a ratio of corpus size.** A
preamble idiom shared by 5 of 4000 functions is already a common idiom; requiring 4% of the corpus
(166 functions) to agree before something counts as boilerplate is why the loose run was so noisy.
This was learned by running the numbers, not chosen up front.

**Validated against two real "already fixed, don't re-flag" cases**, both confirmed by reading the
code, not by score:

- The Curve3D/Curve2D isomorphic-mirror family and the CompCurve/EdgeCurve six-pair family (which
  already shares one set of non-template helpers per an explicit #603 comment) both appear at the
  loose settings and both disappear by the final settings — the false positives the tightening was
  *for*.
- `gridEvalD0`/`gridEvalD1` (Swift) is explicitly documented forwarding shims from #486; it does
  not appear at the final Swift settings either.

## Findings

Full raw output: run the script, or see `full-report.txt` in this directory (captured at commit
time; **may drift from a fresh run** as the tree changes — re-run rather than trust the file if the
two disagree).

### Filed (bridge)

- **#791** — `OCCTConvertSphereToBSplineSurface`/`buildSurfaceFromElementary` (score 1.00, 309
  shared) and `buildCurve2DFromConic`/`OCCTConvertCircleToBSpline2D` (score 0.99, 168 shared): two
  entry points independently reimplement an array-building helper their siblings already call.
  Confirmed `Convert_SphereToBSplineSurface` genuinely inherits `Convert_ElementarySurfaceToBSplineSurface`
  (verified against the OCCT refman) and `Convert_CircleToBSplineCurve` is a sibling of the
  Ellipse/Hyperbola/Parabola converters that already call the helper — this is exactly the #761/#768
  shape, the strongest finding in the rescan.
- **#792** — `OCCTShapeClean`/`OCCTBRepToolsCleanTriangulation`, `OCCTShapeUpdate`/`OCCTBRepToolsUpdate`,
  `OCCTBRepGraphMeshAppendCachedTriangulation`/`OCCTBRepGraphSetFaceTriangulationRep`: the same OCCT
  static call wrapped under a second name, added in a later release, with zero cross-reference. The
  first two are below this script's own `min_distinctive` floor (one-line bodies) and were found by
  reading the file directly while investigating the third — noted rather than silently dropped,
  since a threshold tuned to avoid one-liner false positives is also blind to real one-liner
  duplicates.
- **#793** — `oriFromInt` (`OCCTBridge_BRepGraph.mm`)/`intToOrientation` (`OCCTBridge_Topology.mm`):
  byte-identical int→`TopAbs_Orientation` decode, no shared declaration, both genuinely load-bearing
  (13 and 6 call sites respectively). The same class of bug #490 already fixed for the continuity
  enums, outside that pass's scope.
- **#794** — a table of 11 sibling-entry-point pairs (`OCCTExtremaPCCurve`/`Bounded`,
  `OCCTCPntsUniformDeflection`/`Range`, `OCCTShapeQuilt`/`WithHistory`,
  `OCCTShapeMakePeriodic`/`OCCTShapeRepeat`, `OCCTWireInterpolate`/`WithTangents`,
  `OCCTFilletBuilderGenerated`/`Modified`, `OCCTMeshUnion`/`Subtract`/`Intersect`,
  `OCCTImportSTL`/`Robust`, `OCCTExportPLY`/`WithOptions`, `OCCTDocumentWriteOBJ`/`WritePLY`,
  `OCCTSolveQuadratic`/`Cubic`/`Quartic`) sharing setup/extraction scaffolding around one differing
  OCCT call, with no shared helper. Filed as one census issue rather than eleven, per #784's own
  "cheap and targeted" instruction — each is individually low severity (no known behavioral bug
  yet), the pattern recurring eleven times is what makes it worth tracking.

### Filed (Swift)

- **#795** — the single largest finding in the rescan. `PDFExporter.swift`/`SVGExporter.swift`
  duplicate `primitiveOps`/`collectFromDrawing`/`collectProjectedEdges`/`strokeWidth` almost
  verbatim (scores 1.00, 48-170 shared shingles) despite sharing no base class or protocol.
  `DXFExporter.swift` duplicates `collectProjectedEdges` too, and — worse — its own
  `formatTolerance`/`TolerancedLabel` (`DXFExporter.swift:328`) is **byte-identical** to
  `DrawingDispatch.swift`'s **own** `formatTolerance`/`TolerancedLabel` (`:165`), the file that
  exists specifically to be the one place PDF/SVG's shared `emitDimension` uses this logic. DXF
  never calls `emitDimension` at all, so the "shared" dispatch file's own formatTolerance has a
  second, independent copy sitting in a sibling file that does not use it.
- **#796** — 5 Swift API sibling pairs (`coonsFilling`/`curvedFilling`,
  `discreteTrihedron`/`correctedFrenet`, `pointCloudByTriangulation`/`ByDensity`,
  `GuideTrihedronAC.evaluate`/`GuideTrihedronPlan.evaluate`,
  `recognizeCanonicalSurface`/`Curve`) sharing marshaling scaffolding around distinct bridge calls.
  Explicitly excludes and explains three pairs that measured as already-handled
  (`inertiaProperties`/`surfaceInertiaProperties`: documented + low risk;
  `solveSystem`/`solveSystemNewton`: a real duplicate but already has a comment acknowledging it
  directly; `gridEvalD0`/`gridEvalD1`: already-deprecated #486 forwarding shims) and two that
  measured as NOT duplication at all (`shadedMesh`/`shadedMesh`,`edgeMesh`/`edgeMesh`: legitimate
  Swift overloads by parameter type, not two definitions of one function; `angle`/`isCoplanar`:
  coincidental, both share the whole file's `gp_Ax3`-unpacking idiom, not a computation duplicate).

### Measured and NOT filed (isomorphic mirrors, expected repetition)

Confirmed by direct source reading, not by score: `OCCTCurve3DGetDomain`/`GetPeriod`/`GetContinuity`/
`TypeName`/`BSplineRemoveKnot`/`BSplineSetKnots` vs their `OCCTCurve2D*` siblings — `Geom_Curve` and
`Geom2d_Curve` expose the identical method names by OCCT's own parallel 3D/2D API design, an
unavoidable structural mirror, the same category as `OCCTAxis1PlacementLocation`/`Axis2*`,
`OCCTProjOnCurvePoint`/`OCCTProjOnSurfPoint`, `OCCTIntAnaCylinderSphere`/`ConeSphere`,
`OCCTGeomFillGuideTrihedronACD0`/`PlanD0` (different OCCT classes, `GeomFill_GuideTrihedronAC`/`Plan`,
both subclassing `GeomFill_TrihedronLaw`), `OCCTContapSphereDir`/`Eye` (different `Contap_ContAna::Perform`
overloads: direction vs eye-point projection), `OCCTHelixBuild`/`OCCTHelixCoilBuild` (Coil genuinely
lacks a position parameter), `OCCTTrsfDisplacement`/`Transformation` (documented OCCT inverse methods),
`OCCTAx3Create`/`FromNormal` (overload pair), `OCCTDocumentNamingTraceForward`/`Backward`
(`TNaming_NewShapeIterator`/`OldShapeIterator`, OCCT's own symmetric pair), and
`OCCTShapeInertiaProperties`/`SurfaceInertiaProperties` (the actual property computation already
delegates to two distinct, pre-existing shared helpers; only ~30 lines of pure field-copying is
duplicated, low risk, not filed).

Note on **`OCCTCurve2DBSplineLocateU`/`OCCTSurfaceBSplineLocateU`** and **`OCCTCurve3DBSplineSetKnots`/
`OCCTCurve2DBSplineSetKnots`**: also isomorphic mirrors on inspection (2D curve vs 3D surface, or
2D vs 3D curve, parallel OCCT method names), listed here for completeness rather than re-derived per
pair above.

**`OCCTShapeCreateMesh`/`OCCTShapeCreateMeshWithParams`** (score 0.94, 584 shared shingles — the
largest raw score in the bridge run) is explicitly excluded from #794: an in-place comment already
acknowledges the duplication directly ("same as `OCCTShapeCreateMesh`, including #613/#614's ...
split — see the note there"), a documented, deliberate decision rather than an oversight.

## A false-positive mechanism found while tuning, not by accident: nested Swift functions

`swift_functions()` extracts every `func` definition regardless of nesting depth. A **locally
nested function's entire body is a literal substring of its enclosing function's body** (Swift
allows `func` inside `func`), so containment between a nested helper and its enclosing function is
close to 1.0 by pure syntax — not evidence of independent duplication.

Measured directly on the real Swift corpus at final settings: disabling `exclude_delegation`
(`compute(..., exclude_delegation=False)`) newly flags **21 pairs on the Swift side, 0 on the
bridge side**. Every one of the 21 is an enclosing function paired with one of its OWN locally
nested helpers — `ThreadFeatures.swift`'s `threadedRodSolid` and its nested `camEdge`/`camWire`/
`circleWire`/`arcW`/`shoulderFaces`/`cylinderLateral` account for 8 of them; five more files
(`Surface.swift`, `SheetLayout.swift`, `ArcLengthCurveAdaptor.swift`, `DXFExporter.swift`/
`DrawingDispatch.swift`, `Curve2D.swift`, `DrawingComposition.swift`, `LawFunction.swift`) contribute
the rest, mostly a local `read`/`arrow`-shaped helper nested inside a bigger function. None of the
21 are sibling-nested-function pairs (e.g. `camEdge` vs `camWire`) — only enclosing/nested pairs, as
the mechanism predicts.

This is reliably rescued, not just usually: a nested function's own `func <name>(` declaration line
necessarily puts its name in the enclosing body's own token set, so `exclude_delegation`'s
name-in-tokens check fires on every such pair with no exceptions found in the real corpus. Added as
`SWIFT_CLEAN`'s dedicated fixture (below) once found, per `okf/policies/measure-dont-assume.md`'s
"a second construction that was different in the wrong way" lesson — the mechanism was invisible to
the synthetic self-test fixtures until it was checked against the real corpus.

## What this does not find (read before trusting a small number)

- **Shape B** (#777): two different algorithms answering the same question. No shared text for a
  shingle to match — a semantic/call-graph question this script does not attempt.
- **Shape C** (PR#774/#773): duplication between two branches of ONE function (this script never
  compares a function against itself), or duplication in `Scripts/` dev tooling (out of population
  by design — see "Scope" in the module docstring).
- A function whose distinctive shingle count is below `min_distinctive`: `OCCTShapeClean`/
  `OCCTBRepToolsCleanTriangulation`'s one-line bodies (see #792) are the concrete example the real
  corpus produced.
- A generic Swift function (`func foo<T>(...)`) or a computed property (`var x: Bool { ... }`) as
  its own comparable unit — `swift_functions()` matches `func` only. Either still appears as part of
  an enclosing function's body (so an embedded block is still caught, per shape 3/PR#778), but a
  top-level computed property is invisible as a unit on its own.

## Self-test and removal matrix

11 fixtures (8 bridge, 3 Swift), each proven, not just exercised, per
`okf/policies/prove-the-test-fails.md`: every mechanism below was disabled in a working copy of
`detect-duplicate-logic.py`, `--self-test` re-run, the case(s) confirmed to flip, then restored.

| Mechanism disabled | Cases correct | What flipped |
|---|---|---|
| (baseline) | 11/11 | — |
| Boilerplate exclusion (`boilerplate_min_count` set unreachably high) | 10/11 | Only the boilerplate-preamble CLEAN case |
| Containment (Jaccard instead of `shared/min`) | 9/11 | Only the two size-asymmetric MISSED cases (bridge PR#778 shape, and its Swift twin) |
| Delegation exclusion (`exclude_delegation=False`) | 10/11 | Only the nested-local-function CLEAN case |
| Minimum-distinctiveness guard (`min_distinctive=0`) | 11/11 | **Nothing — see below** |
| Minimum-shared-shingles guard (`min_shared=0`) | 10/11 | Only the short-coincidental-idiom CLEAN case |
| Shingle size (`shingle_k=1`, token-level) | 8/11 | Three CLEAN cases at once (two unrelated functions, tiny bodies, and the coincidental-idiom case) |

Every row's flip set is disjoint from every other row's, so each isolates a distinct mechanism
rather than two guards backstopping each other — the exact trap
`okf/policies/prove-the-test-fails.md`'s "a green removal row is ambiguous" section warns about.

**The `min_distinctive` row is a genuine "adds nothing", explained structurally, not just
observed empirically.** `min_distinctive` and `min_shared` are set EQUAL by design (25/25 in
production, 3/3 in self-test). Since `shared <= min(|A|, |B|) <= |A|` always, whenever `|A| <
min_distinctive` it is also true that `shared <= |A| < min_distinctive == min_shared`, so
`min_shared` already excludes the pair regardless of `min_distinctive`. `min_distinctive` can only
ever have independent effect if set STRICTLY GREATER than `min_shared` — and doing that would
wrongly exclude a genuinely small, near-fully-duplicated function (the PR#778 shape) whose total
size sits between the two thresholds, which is exactly the case this script exists to catch. So
`min_distinctive`'s only real job at its current value is a performance pre-filter (skip tiny
functions before building the inverted index, cheaper than indexing everything and filtering
later) — provably not a correctness guard, not a guard that happens not to matter today.

## Files

- `detect-duplicate-logic.py` — the artifact.
- `full-report.txt` — a captured run's output, for reference; re-run the script for the current
  answer.
