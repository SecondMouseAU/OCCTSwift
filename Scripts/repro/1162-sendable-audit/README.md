# #1162 `@unchecked Sendable` audit

Issue #1162 claimed 27+ Swift classes were marked `@unchecked Sendable` without thread-safety
verification, and cited #1153/#1154/#1155/#1156/#1158/#1159 as evidence several were unsafe. All
six are now CLOSED. Per this project's own "measure, don't assume the premise" discipline, this
audit re-verified each citation against what actually shipped rather than trusting the issue's
table, then investigated every class the issue named (plus two it should have named:
`WireCurve`, `AxisPlacement2D`'s siblings) from the Swift wrapper down through the bridge to the
underlying OCCT mechanism.

**A grep at the time of this audit found ~90 `@unchecked Sendable` declarations in
`Sources/OCCTSwift/`, not 27.** The issue's table is a small, stale subset of a much larger, mostly
structurally-identical pattern (a bridge handle wrapper with no internal lock). This audit covers
the issue's named classes plus the two closely-related ones found along the way; the other ~60 are
out of scope here and share the same disposition reasoning documented below (see "Why most classes
keep `@unchecked Sendable`").

## The six cited issues, re-verified

| Issue | What it says vs. what shipped |
|---|---|
| #1153 (BSpline adaptor cache race) | Real kernel fix (`Scripts/patches/0031`), override-link-validated, **confirmed NOT in the pinned v3.0.0 `OCCT.xcframework`** (17 patches pinned; `Scripts/patches/` holds 22; `0031` is one of the 5 not yet shipped). The race is live in what a consumer actually links today. |
| #1154 (`TopoDS_TShape::myState` race) | Same shape: fix is `Scripts/patches/0030`, override-link-validated, **not in the pinned asset**. Live today. |
| #1155 (algorithms w/ internal mutable state) | Closed via a real TSan survey (PR #1372, `Scripts/repro/1155-thread-safety-survey/`) that found all 8 named classes clean of *cross-instance* races. It tested one thread per independent instance, **not** concurrent calls on the *same* instance, which is the question this audit needs. Doesn't transfer directly; several `@unchecked Sendable` classes it's cited for (`ProjectionOnSurface` via `GeomAPI_ProjectPointOnSurf`) turn out fine for an unrelated reason (immutable after `init`), not because of this survey. |
| #1156 (shared geometry after booleans) | Closed as a pure duplicate of #1153+#1154, "describing their compound consequence rather than a new mechanism." No independent fix. |
| #1158 (per-call bridge classification) | Closed as a duplicate of **#342, which is still OPEN**. #1162's "Phase 2" (conditional Sendable per classification) is not naturally unblocked by #1158's closure. |
| #1159 (auto-locking exclusive calls) | Same: closed as a duplicate of **#342, still OPEN**. |

## A load-bearing precedent the issue doesn't cite

PR #912 (merged 2026-08-16, ten days before #1162 was filed) already litigated "should a mutable
bridge-handle class keep `@unchecked Sendable`" for `ThruSectionsBuilder`, and the review's finding
11 settled it: keep the conformance (it reflects the handle being safe to move across a
concurrency-domain boundary, not that concurrent same-instance mutation is safe), and document the
real contract in the class doc comment — **"the existing, already-documented project-wide
thread-safety model ... every sibling builder class has the same unsynchronized-flag shape,"** not
a defect to fix per-class. `ThruSectionsBuilder.swift`'s doc comment is the existing exemplar this
audit followed for every class in the "mutable, no lock, use `OCCTSerial`" bucket.

## Why most classes keep `@unchecked Sendable`

Given the precedent above and the ~90-vs-27 scale mismatch, blanket-removing `@unchecked Sendable`
from only the issue's named classes would leave a *worse*, inconsistent API than documenting
precisely: some builders `Sendable`, structurally-identical siblings not, with no principled
caller-visible distinction. `@unchecked Sendable` was kept, with a corrected/strengthened doc
comment, for every class where the unsafe surface is an *obvious-from-the-API-shape* mutator
(`setX`, `add`, a re-callable `perform()`/`build()`) — the caller has some signal. It was actually
**removed** only for the two classes where every method looks like a pure query and none is:
`EdgeCurve`/`WireCurve` (see below), the purest form of the trap the issue's own `withTaskGroup`
example demonstrates.

`Shape` and `Surface` are argued through explicitly in the table below rather than mechanically
grouped, since they're the highest-traffic types in the package and the ones the issue's own
worked example targets.

## Audit table

Legend for **Original claim**: `F` = issue said False/unsafe, `U` = issue said Unknown,
`LT` = issue said "Likely true" (value type).

| Class | File:line (current) | Original claim | Verdict | Mechanism (evidence) | Disposition |
|---|---|---|---|---|---|
| `Shape` | `Shape.swift:6` | F (#1154) | **Still unsafe** | Topology flags (`TopoDS_TShape::myState`, #1154) unpatched in pinned kernel; `isValid`'s `BRepCheck_Analyzer` pass and the `Free`/`Modified`/`Checked`/... accessors mutate them with zero sync. Shared TShapes after booleans/fillets compound this. | **Kept + doc strengthened.** Removing `Sendable` from the package's most pervasively-used type is out of proportion to this issue (see PR body for the full blast-radius argument); doc comment now names both live mechanisms and points at `OCCTSerial`/`copy(copyGeometry:)`. |
| `Surface` | `Surface.swift:112` | F (#1153) | **Unsafe, wrong mechanism cited** | Bridge struct (`OCCTSurface`) holds only `Handle(Geom_Surface)`, no persistent adaptor — plain evaluation (`point`/`d1`/`d2`/`evaluateGrid`) calls `Geom_Surface::D0/D1/D2` directly and does **not** hit #1153's adaptor-cache race. The real hazard: `Sphere.setRadius`/`.BSpline.setPole`/`.setTrim`/etc. mutate the same shared handle a concurrent evaluation reads. | **Kept + doc corrected.** Concurrent evaluation-only calls (no setter in the mix) are actually safe; doc now says so and names the real hazard. |
| `EdgeCurve` | `EdgeCurve.swift:18` | F (#1153) | **Confirmed unsafe** | Bridge struct (`OCCTEdgeCurve`) holds a **persistent** `BRepAdaptor_Curve`, built once at `init`, reused by every call — every accessor (`point`, `tangent`, `length`) mutates its BSpline evaluation cache (#1153, unpatched). Zero setters, so unlike `Surface` there's no "safe half." | **RECLASSIFIED: `@unchecked Sendable` REMOVED.** Full `swift build --build-tests` (1440/1440 steps) clean with it gone — the cleanest, most defensible removal in this audit. |
| `WireCurve` | `WireCurve.swift:21` | *(not in issue's table)* | **Confirmed unsafe, same as EdgeCurve** | Bridge struct (`OCCTCompCurve`) holds a persistent `BRepAdaptor_CompCurve`, identical shape to `EdgeCurve`. | **RECLASSIFIED: `@unchecked Sendable` REMOVED**, same evidence and same build proof as `EdgeCurve` (they share one build check). Not in the issue's table despite being the identical defect — the issue's table is not exhaustive even among classes it should have caught. |
| `ProjectionOnCurve` | `Projection.swift:6` | F (#1155) | **Reclassified safe** | `init?` runs `GeomAPI_ProjectPointOnCurve::Init` synchronously to completion into a private, per-instance struct (`OCCTProjOnCurve { GeomAPI_ProjectPointOnCurve proj; }`); every accessor after is a `const` read, no re-run/mutate method exists. | **Kept, doc corrected** to state the evidence for genuine safety, not a hand-wave. |
| `ProjectionOnSurface` | `Projection.swift:49` | F (#1155) | **Reclassified safe** | Same shape as `ProjectionOnCurve`; its internal `GeomAdaptor_Surface` (the class #1153's race lives on) is a private per-instance copy built once during `Init`, never shared. | **Kept, doc corrected.** |
| `ThruSectionsBuilder` | `ThruSectionsBuilder.swift:28` | F (#1155) | **Confirmed unsafe (already correctly documented)** | Genuine mutable builder (`addWire`/`addVertex`/6 setters/re-callable `build()`), no internal lock. | **Kept-as-is.** Already carries the correct doc comment from PR #912 (reviewed, predates #1162); nothing to change. |
| `BSplineApproxInterp` | `BSplineApproxInterp.swift:40` | F (#1155) | **Confirmed unsafe, `#1155` never actually covered this class** | Genuine mutable builder (setters + re-callable `perform()`/`performOptimal()`), same shape as `ThruSectionsBuilder`. `#1155`'s 8-class survey never named `GeomAPI_PointsToBSpline`, so the citation was wrong from the start, independent of #1155's later closure. | **Kept, doc added** matching the `ThruSectionsBuilder` template (had none before). |
| `TObjApplication` | `TObjApplication.swift:6` | F (#344) | **Unsafe, stale citation, new mechanism found** | #344 was `XCAFApp_Application`/`CDF_Application`, already fixed (v1.15.6) and since eliminated from the bridge entirely (#371). `TObjApplication` wraps a *different*, still-live process-wide singleton (`TObj_Application::GetInstance()`) with unsynchronized `myIsError`/`myIsVerbose` fields — a real, previously-uncharacterized race. | **Kept, doc corrected + new issue filed (#1404)** rather than fixed here (bridge-side mutex needed, out of scope for a docs/reclassification audit). |
| `Mesh` | pending | U | pending | pending (subagent) | pending |
| `TransactionDelta` | pending | U | pending | pending (subagent) | pending |
| `TransformedDrawing` | pending | U | pending | pending (subagent) | pending |
| `ZLayerSettings` | pending | U | pending | pending (subagent) | pending |
| `ClipPlane` | pending | U | pending | pending (subagent) | pending |
| `AAG` | pending | U | pending | pending (subagent) | pending |
| `Drawing` | pending | U | pending | pending (subagent) | pending |
| `PixMap` | pending | U | pending | pending (subagent) | pending |
| `ShapeRayIntersection` | pending | U | pending | pending (subagent) | pending |
| `SharedLibrary` | pending | U | pending | pending (subagent) | pending |
| `LengthDimension`/`RadiusDimension`/`AngleDimension`/`DiameterDimension`/`TextLabel` | pending | U | pending | pending (subagent) | pending |
| `GeomTransformation` | `GeomTransformation.swift:6` | LT | **"Likely true" was wrong** | Has real post-construction mutators (`setTranslation`/etc.) on the shared `gp_Trsf`-backed handle, no lock. | pending final doc edit |
| `Interval`/`IntervalSet` | `Interval.swift:6,101` | LT | **"Likely true" was wrong** | Has real mutators. | pending final doc edit |
| `AxisPlacement2D` | `AxisPlacement2D.swift:8` | LT | **Confirmed safe** | No mutator reachable. | pending final doc edit (likely kept-as-is) |
| `OBB` | `OBB.swift:6` | LT | **"Likely true" was wrong** | Has real mutators. | pending final doc edit |

*(This table is updated in a follow-up commit once the remaining rows are resolved; see the PR
body / final session report for the completed version if this note is still here.)*

## Files changed so far

- `Sources/OCCTSwift/Shape.swift`, `Surface.swift`, `Projection.swift`, `BSplineApproxInterp.swift`,
  `TObjApplication.swift` — doc comments corrected/strengthened, `@unchecked Sendable` kept.
- `Sources/OCCTSwift/EdgeCurve.swift`, `WireCurve.swift` — `@unchecked Sendable` **removed**, doc
  comments rewritten to state why.

## New issues filed

- [#1404](https://github.com/SecondMouseAU/OCCTSwift/issues/1404) — `TObjApplication`'s
  unsynchronized singleton fields, distinct from #344.
