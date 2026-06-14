# Changelog

All notable changes to OCCTSwift.

## Current: v1.4.6

**4,287 wrapped operations | macOS / iOS / visionOS / tvOS | OCCT 8.0.0**

---

## Release History

### v1.4.6 (June 2026) — instanced-assembly STEP writer (closes #173)

**PATCH — additive, non-breaking.** New `Exporter.writeSTEPAssembly(_ document: Document, to url:)`
writes an XCAF `Document` as a **product-structured STEP assembly**: each unique part label
becomes one STEP product, referenced by its located component occurrences
(`NEXT_ASSEMBLY_USAGE_OCCURRENCE` + each component's `TopLoc_Location`). A part placed N times
stores **one** `MANIFOLD_SOLID_BREP`, not N copies — file size scales with unique parts, and the
result opens as an editable assembly in standard CAD viewers (AP214). Names/colors set on the
document are preserved.

The underlying capability already existed (`Document.writeSTEP` transfers the XCAF doc via
`STEPCAFControl_Writer`, and full rotation+translation placement landed in #174); this adds the
named, documented, throwing convenience entry point #173 asked for, plus instancing + round-trip
tests.

### v1.4.5 (June 2026) — mesh→shape weld tolerance is caller-tunable (#197)

**PATCH — additive, non-breaking.** `Mesh.toShape()` sewed its triangles into a shell at a
**hardcoded `1e-6`** weld tolerance. That tolerance must scale with the mesh's coordinate
magnitude — too small for a large-coordinate (or imprecise, imported) mesh leaves shared edges
unmerged and silently yields an open shell. It now takes `weldTolerance: Double = 1e-6` (the
default reproduces prior output); non-positive values return `nil`. From the #197 hardcoded-constant
sweep — the audit (see issue) found this the one remaining genuine knob; the rest of the `1e-X`
literals are internal correctness epsilons left as-is.

### v1.4.4 (June 2026) — mesh deflection is caller-tunable on auto-meshing utilities (#197)

**PATCH — additive, non-breaking.** Several utility functions auto-triangulated their input at a
**hardcoded `0.1` mm** deflection, leaving callers no control over fidelity/speed. Each now takes a
`deflection: Double = 0.1` parameter (the default reproduces prior output). First slice of the #197
hardcoded-constant sweep — the *mesh deflection* area:

- `Shape.writeSTLBinary(to:deflection:)` / `writeSTLAscii(to:deflection:)` — STL export resolution.
- `Shape.proximityFaces(with:tolerance:deflection:)` — proximity triangulation.
- `Shape.selfIntersectionPairs(tolerance:maxPairs:deflection:)` — self-intersection triangulation.
- `CoherentTriangulation.createFromMesh(_:deflection:)`.

(The primary STL path `Exporter.writeSTL(shape:to:deflection:)` already exposed this.) Source-only;
remaining #197 areas — tolerances, sampling counts — tracked in the issue.

### v1.4.3 (June 2026) — fast 2D drawings of threaded solids via polyhedral HLR (closes #196)

**PATCH — additive + guidance.** The v1.4.1 smooth analytic thread helicoid is HLR-hostile under
OCCT's **exact** HLR (`hlrEdges` / `HLRBRep_Algo`): projecting its BSpline faces computes analytic
helical silhouettes and blows up — a downstream 2D-drawing pipeline measured **~19× slower** vs the
v1.4.0 faceted thread.

**The fix is not to change the solid.** OCCT's **polyhedral** HLR (`hlrPolyEdges` / `HLRBRep_PolyAlgo`,
already wrapped) projects the shape's *triangulation*, so it is fast on any surface — **measured ~48×
faster** than exact HLR on an analytic M10 thread (337 ms vs 16.4 s, side view) — while the one
analytic solid stays smooth for STEP. **Prefer `hlrPolyEdges` for 2D drawings of threaded / curved
solids; reserve exact `hlrEdges` for analytically simple shapes.**

`hlrPolyEdges(direction:category:deflection:)` now exposes the internal mesh **`deflection`** (mm,
default `0.1`) so drawing pipelines can trade fidelity (more, shorter edges) for speed. Non-breaking —
the default reproduces prior output. (No GPU offload needed; the polyhedral CPU path already recovers
the speed. The broader hardcoded-constant sweep this surfaced is tracked in #197.)

### v1.4.2 (June 2026) — long full-length threads return a usable solid, not nil (closes #193)

**PATCH — regression fix.** A long full-length thread (`threadedShaft` over tens of turns, e.g. an
ISO 4017 M10×50 full-thread shank ≈ 49 turns) came back **`nil`**. No API change.

**Cause.** v1.4.1's soundness gate required `Shape.isValid`. For a long thread, the two cutter paths
both fail that gate: the smooth analytic cutter is BRepCheck-valid but, when wound over ~40+ turns,
OCCT's boolean degenerates to a near-no-op (the result keeps ~the full blank volume — *no groove cut*);
the faceted screw-loft fallback *does* cut the groove correctly but trips `BRepCheck` on a benign facet
self-intersection (`isValid == false`) — exactly the #193 symptom. With both rejected, the method
returned `nil`.

**Fix.** Soundness is now judged on **geometry, not `BRepCheck`**: the cut must stay inside the blank
(tight/optimal envelope) and remove a sane fraction of the volume. `isValid` is no longer a gate. The
analytic no-op is still rejected (it removes ~0 material → fails the volume check), so a long thread
falls through to the faceted screw-loft and is returned — dimensionally correct and STEP-exportable,
as the downstream reporter confirmed. Short/medium threads still get the smooth analytic helicoid and
remain `isValid == true`; only the long faceted fallback is allowed to be invalid-but-usable.

### v1.4.1 (June 2026) — smooth analytic thread helicoid, with screw-loft fallback (#187)

**PATCH — geometry quality, no API change.** `threadedShaft` / `threadedHole` now emit a **smooth
analytic helicoid** instead of v1.4.0's faceted ruled loft. Same signatures, same in-envelope
result; the difference is surface quality and face count.

**What changed.** v1.4.0 swept the V-profile through ~14 screw-transformed sections per turn and
ruled-lofted them — correct and in-envelope, but **faceted** (hundreds of flank facets) and ~1 s per
thread. The cutter is now built analytically (new bridge op `OCCTShapeBuildThreadCutter`): the four
ISO-68 V-corners each trace a single BSpline helix (`GeomAPI_Interpolate`), and the solid is bounded
by four ruled faces between consecutive corner-helices plus two V end caps — sewn, made solid, and
`BRepLib::OrientClosedSolid`-corrected. That's **~6 faces, no faceting**, regardless of turn count.

**Automatic fallback.** OCCT's boolean chokes on the *tightly-wound* cutter of small, fine-pitch
threads (e.g. M5×0.8 — 22.5 turns at radius 2.5): the subtraction comes back BRepCheck-"valid" but
with *more* volume than the blank. The cut is validated (optimal/tight bounding box stays inside the
blank **and** volume strictly decreases by a sane amount); if the analytic result fails, it silently
falls back to v1.4.0's robust screw-loft. So M6/M8/M10/M12 and coarse worm pitches get the smooth
helicoid, while pathological small-fine-pitch threads still build via the faceted-but-robust path.

**Why the envelope is measured on the optimal box.** The smooth helicoid's *default* `Bnd_Box`
(`BRepBndLib::Add`) is the BSpline **convex hull**, which overshoots the real surface by ~0.1–0.35 mm
— a control-pole artifact, not escaped material (`AddOptimal` returns the blank's exact extent).
Both the fallback check and the #181-C regression test now use the tight optimal box; a strict
tolerance there still catches the real >1 mm balloon the guard exists for.

**Migration.** None required. Thread mesh/STEP geometry differs again (smoother) — byte-exact
snapshot consumers must rebaseline; everything else is unchanged.

### v1.4.0 (June 2026) — correct, in-envelope thread geometry (closes #187)

**MINOR — BEHAVIOUR CHANGE to `threadedShaft` / `threadedHole`.** The thread output geometry changes:
both now produce a **correct, in-envelope helicoid** for every pitch, including coarse worm pitches
that previously returned `nil` or garbage.

**Why it changed.** The cutter was a `BRepOffsetAPI_MakePipeShell` sweep of a V-profile along the
helix. That sweep re-frames the section with the helix lead, so it **bulged the thread outward**
(~1.25× cut depth for fasteners, ~3.1× for worm pitches → a self-intersecting ≈2×-radius balloon that
crashed STEP export — #181-C/#185). The cutter is now built by a **screw-motion sweep**: the axial
V-profile is transported by a pure rotate-about-axis + translate-along-axis motion (every section
stays in its own axial plane), ruled-lofted, and subtracted. The result's crest sits at the nominal
radius (within ~0.1 mm tessellation), deterministically.

**Migration.** No API change (same signatures, still `Shape?`). But:
- the produced thread **mesh / STEP geometry differs** — snapshot/byte-exact consumers must rebaseline;
- threads that returned `nil` at coarse/worm pitch now return a valid solid;
- the V-form is faceted (ruled loft, ~14 sections/turn) rather than a smooth pipe surface;
- **performance:** ~1 s per thread (loft + boolean over the section facets). For many threads, expect
  it to dominate; a true analytic helical surface (future work) would remove the faceting/cost trade.

The #181-C envelope guard is retained as a thin safety net (now 1× cut depth) but effectively never
trips on the in-envelope result.

### v1.3.6 (June 2026) — fix: thread envelope guard rejected valid fastener threads (closes #189)

**PATCH — regression fix.** The #181-C envelope guard added in v1.3.4 used a tolerance
(`1e-3 · extent`) far tighter than the bounding-box overrun of a *valid* `threadedShaft` /
`threadedHole` result, so it returned **`nil` for ordinary bolts/screws** (M5–M10, ISO 4762/4014/…)
that built in v1.3.3 — breaking 37 downstream fastener generators.

The guard's tolerance is now `2 · cutDepth`. Measured overruns (relative to the thread cut depth,
which scales the corrected-Frenet sweep's directional bulge) are ~1.25× for valid fastener threads
and ~3.1× for the coarse-worm-pitch garbage the guard is meant to catch (#181-C, which balloons to
~2× radius and crashes STEP export). `2 · cutDepth` sits cleanly between them — valid threads build
again, the catastrophic balloon is still rejected. (The proper fix — a cutter that doesn't bulge at
all — is tracked in #187.)

### v1.3.5 (June 2026) — `Shape.helicalSweep` worm/screw-thread helicoid (closes #185)

**PATCH — additive convenience API.** Adds `Shape.helicalSweep(profile:axisOrigin:axisDirection:radius:pitch:turns:clockwise:solid:)`
(and a multi-profile overload), the turnkey form of the #180 auxiliary-spine sweep for the helical
case. It builds the helix spine **and** a correctly-spanning central-axis auxiliary spine internally,
with the orientation flags (`CurvilinearEquivalence = false`, no contact) that keep the swept section
radial — producing a worm/screw-thread helicoid in one call:

```swift
Shape.helicalSweep(profile: rib, axisOrigin: .zero, axisDirection: SIMD3(0,0,1),
                   radius: 5, pitch: .pi, turns: 4.77)   // crest stays radial (~Ø12), not nil
```

Hand-rolling this with `pipeShell(mode: .auxiliary(...))` reliably returned nil because (a) `Wire.helix`
runs toward +Z or −Z depending on handedness and (b) the auxiliary spine must span the helix's full
axial extent or the section planes never intersect it. The helper handles both. (Investigation: the
correct OCCT recipe was confirmed empirically — `SetMode(axisLine, CurvilinearEquivalence=false,
NoContact)`; `CurvilinearEquivalence=true` and the contact modes fail to build for a helix spine.)

### v1.3.4 (June 2026) — assembly/export robustness (#181 B & C)

**PATCH — robustness fixes, no API change.**

- **STEP writer serialization (#181-B).** Concurrent `writeSTEP` calls could SIGSEGV because
  OCCT's `STEPCAFControl`/`STEPControl` writers share non-thread-safe `Interface_Static` globals
  with IGES. All STEP/IGES write entry points now serialize on the shared data-exchange mutex, so
  parallel exports queue instead of crashing. (The crash is an uncatchable signal, so internal
  serialization — not documentation — is the fix.)
- **`threadedShaft` envelope guard (#181-C).** At coarse pitch / steep lead (and, observed here,
  even at bolt pitch) the helical V-cutter self-intersects and the boolean subtract returns a
  non-deterministic solid that BRepCheck reports "valid" yet extends well outside the blank
  (≈Ø22 on a Ø12 blank) — which then crashed downstream STEP export. A thread cut can only remove
  material, so `threadedShaft` now returns `nil` when the result escapes the blank envelope rather
  than handing back garbage. Callers should fall back (e.g. a smooth-cylinder worm body).

Note on #181-A (XCAF `setColor`/`setName` on auto-created component labels): could not reproduce as
an OCCT or bridge fault — `XCAFDoc_ColorTool::SetColor` on auto-created/reference component labels is
robust in isolation, and the bridge already fails safe on unregistered labels. Left open pending a
minimal reproducer.

### v1.3.3 (June 2026) — multi-section pipe shell (closes #180)

**PATCH — additive API.** Adds `Shape.pipeShellMultiSection(spine:profiles:mode:withContact:withCorrection:solid:)`,
the multi-section form of `pipeShell`. Several profiles positioned along the spine are swept into a
single variable cross-section solid/shell via repeated `BRepOffsetAPI_MakePipeShell::Add`. Supports
all orientation modes including `.auxiliary(spine:)`, so a thread rib can ramp from a runout to full
crest along a helix while staying radial — the worm-thread case that single-profile `pipeShellWithLaw`
(Frenet-only, degenerates on near-zero scaling) could not express.

```swift
Shape.pipeShellMultiSection(spine: helix, profiles: [fullRib, runoutRib], mode: .auxiliary(spine: axis))
```

### v1.3.2 (June 2026) — fix loft (ThruSections) SIGSEGV on mismatched profiles (closes #176)

**PATCH — robustness fix, no API change.** `Shape.loft` (and any `BRepOffsetAPI_ThruSections`
path) could SIGSEGV and abort the host process on mismatched closed profiles — e.g. machine-generated
profile sets with differing vertex counts. The crash is an upstream OCCT null dereference in
`BRepFill_CompatibleWires::SameNumberByPolarMethod` (unguarded correspondence-list iterator
over-advance); because it surfaces as an OS signal, the bridge's `catch(...)` could not intercept it.

Fixed by carrying a minimal source patch
(`Scripts/patches/0001-BRepFill_CompatibleWires-guard-polar-iterator.patch`, applied by
`build-occt.sh`) and rebuilding the xcframework. Loft now fails gracefully (`nil`) on such inputs.
Reported and fixed upstream: OpenCASCADE/OCCT issue #1297, PR #1298.

Note: the `OCC_CATCH_SIGNALS` guards added in v1.2.1/v1.2.2 are inert in this build (OCCT is not
compiled with `OCC_CONVERT_SIGNALS`) and do not provide signal safety; this patch addresses the
crash at its source instead.

### v1.3.1 (June 2026) — feature-aware patterning, sweep orientation, geometric edge selection (closes #169, #170, #171)

**PATCH — additive helpers + one orientation fix.** Three ergonomics gaps surfaced building the
OCCTSwiftScripts cookbook recipes (pipe-flange, helical-spring, mounting-bracket). No C++ bridge
change — everything composes existing tested primitives.

- **#169 — feature-level circular pattern.** `circularPattern` duplicates the *body*, so the
  bolt-circle intent ("drill one hole, repeat it around the axis") produced overlapping flange
  copies with the holes filled in. New `Shape.circularPatternCut(tool:axisPoint:axisDirection:count:angle:)`
  patterns the *tool* and subtracts the compound in one call; `circularPattern`'s doc now warns it
  patterns the body, not features.

  ```swift
  let flange = blank.circularPatternCut(tool: hole, axisPoint: .zero,
                                        axisDirection: SIMD3(0,0,1), count: 8)
  ```

- **#170 — sweep orientation.** `Shape.sweep` (`BRepOffsetAPI_MakePipe`) could yield an
  inward-oriented (negative-volume) solid depending on the section wire's sense vs. the path
  tangent — a hazard for booleans and `volume > 0` checks. `sweep` now orientation-normalises its
  result. New `Shape.orientedForward()` applies the same fix explicitly, and `Shape.signedVolume`
  exposes the signed `BRepGProp` mass for orientation diagnostics (unlike `volume`, which masks
  negatives as `nil`).

- **#171 — geometric edge selection.** Picking fillet edges by raw `edges()` index is fragile —
  the index shifts with parameters. New selectors return edges that feed straight into
  `filleted(edges:radius:)`: `concaveEdges()` / `convexEdges()` (classified via `BRepOffset_Analyse`),
  `edges(where:)`, `edges(parallelTo:tolerance:)`, and `edges(inBounds:_:)`.

  ```swift
  let rounded = bracket.filleted(edges: bracket.concaveEdges(), radius: 3)
  ```


### v1.3.0 (June 2026) — full 4×4 XCAF component locations (closes #174)

**MINOR — additive new public API.** XCAF assembly components could previously only be placed by a
translation, so true instanced assemblies (shared geometry under arbitrary rigid transforms) lost
their rotations. `Document.addComponent(matrix:)` now accepts a full 4×4 placement (row-major 12),
and shape-driven instancing via `Shape.located(matrix:)` + `addShape(makeAssembly: true)` dedupes by
shared `TShape` so each unique solid is written once with N located occurrences.

### v1.2.2 (June 2026) — broaden OCC signal guards (#175)

**PATCH — robustness.** Extended `OSD::SetSignal` + `OCC_CATCH_SIGNALS` coverage to the validity,
volume, boolean, extrude, and revolve bridge paths (on top of v1.2.1's loft/mesh/transform guards),
so more degenerate-input failures surface as caught errors rather than aborting the process. Note:
`OCC_CATCH_SIGNALS` is a no-op unless `OCC_CONVERT_SIGNALS` is defined, and converting via
setjmp/longjmp bypasses C++ unwinding — so this hardens, but does not fully tame, deterministic
SIGSEGVs on degenerate machine-generated geometry (see #176).

### v1.2.1 (June 2026) — OCC signal handling on loft/mesh/transform (#175)

**PATCH — robustness.** Installed `OSD::SetSignal` and wrapped the loft (ThruSections), mesh, and
transform bridge entry points in `OCC_CATCH_SIGNALS` so OCCT hardware-signal faults on those paths
convert to catchable failures instead of crashing the caller.

### v1.2.0 (June 2026) — TopologyGraph attribute store + Codable snapshot (closes #168)

**MINOR — additive new public API.** `TopologyGraph` nodes were bare `(kind, index)` pairs with
no payload, and the type had no serialization (it wraps an opaque C++ handle). This adds a pure
Swift-side sidecar so callers can attach arbitrary typed metadata to any `NodeRef` and round-trip
it. No C++ bridge change — the store never touches the C++ graph.

```swift
extension TopologyGraph {
    public var attributes: NodeAttributeStore            // per-node typed metadata
    public func attribute(_ key: String, for: NodeRef) -> AttrValue?
    public func setAttribute(_ key: String, _ value: AttrValue, for: NodeRef)
    public func snapshot() throws -> GraphSnapshot        // export attributes + source shape
    public convenience init(snapshot: GraphSnapshot) throws  // rebuild + reattach
}
```

- `AttrValue` — closed Codable enum: `bool` / `int` / `double` / `string` / `ints` / `doubles`
  (`ints` for mesh-region index sets, `doubles` for fitted-surface params).
- `NodeAttributeStore` — Codable, keyed by `NodeRef`, encodes as sorted arrays so element order
  is deterministic; pair with `GraphSnapshot.canonicalEncoder()` (`.sortedKeys`) for byte-stable,
  diffable output.
- `GraphSnapshot` — Codable round-trip. The graph *structure* is not serialized; it is re-derived
  by rebuilding from the source shape's BREP (captured at construction). Rebuild pins
  `parallel: false`; a determinism test verifies `NodeRef` indexing is stable across rebuilds.
- `NodeKind` and `NodeRef` gained `Codable`.

Foundation for the [OCCTReconstruct](https://github.com/gsdali/OCCTReconstruct) mesh-to-solid
pipeline (per-node fit residual / confidence / provenance + session persistence) and for OCCTMCP's
planned `reconstruct_*` read/write graph tools ([OCCTMCP #33](https://github.com/gsdali/OCCTMCP/issues/33)).

### v1.1.0 (May 2026) — TopologyGraph history disambiguation (closes #167)

**First MINOR bump under the [cohort SemVer policy](SEMVER.md).** Two new methods on `TopologyGraph` resolve the ambiguity in `findDerived`'s empty-result case:

```swift
extension TopologyGraph {
    /// True iff any history record names `original` as a key.
    public func hasHistoryRecord(for original: NodeRef) -> Bool

    /// findDerived if non-empty; else [] for explicitly-deleted nodes;
    /// else [original] for untouched nodes (still at the same index).
    public func findDerivedOrSelf(of original: NodeRef) -> [NodeRef]
}
```

`findDerived` returned `[]` for both "untouched" and "explicitly deleted" — selection-remap consumers couldn't tell which. `findDerivedOrSelf` is the typical "where did this node end up?" lookup: a single deterministic call that returns derivatives, `[]` for deleted, or `[original]` for untouched. `hasHistoryRecord` is the lower-level disambiguator for callers that want to handle the cases differently at the call site.

Implementation is a Swift-side scan over `historyRecords` — O(records × originals-per-record), which is fine for typical scenes. A bridge-side accelerator can land later if profiling ever justifies it.

**Downstream impact:** [OCCTMCP v1.3.0](https://github.com/gsdali/OCCTMCP/releases/tag/v1.3.0) currently works around this with an `isIdentityPreserving` flag on its `HistoryRegistry` for `transform_body` / `heal_shape`. Once OCCTMCP picks up this OCCTSwift bump, it can drop the flag for ops that record explicit modify/delete records and use per-node resolution.

**Op count: 4,284 → 4,286** (+2). xcframework binary unchanged from v1.0.0.

### v1.0.4 (May 2026) — wire applyFillet / applyChamfer through *WithFullHistory (closes #166)

Closes the explicit follow-up to v1.0.3: `FeatureReconstructor.BuildResult.histories[id]` now also covers `FeatureSpec.Fillet` and `FeatureSpec.Chamfer` with non-nil ids — every spec kind now resolves through OCCT's recorded history instead of the centroid-distance heuristic on the consumer side.

**Behavior changes:**

- `applyFillet` for all three `EdgeSelector` cases (`.all`, `.nearPoint`, `.onFeature`) now uses `Shape.filletedWithFullHistory(radius:edges:)` and records the returned `ShapeHistoryRef` in `ctx.histories[id]`.
- `applyChamfer` does the same via `Shape.chamferedWithFullHistory(distance:edges:)`. **Chamfer's `.nearPoint` and `.onFeature` selectors are now wired up** — they were stubbed to `recordSkip(.unsupported)` in v1.0.3 and earlier.
- Each path falls back to the index-less primitive (`filleted(radius:)` / `chamfered(distance:)`) on builder-nil to preserve existing back-compat semantics. Specs without ids continue to land directly on the non-history path.

**Internals:** the per-selector helpers now return `[Int]?` matching-edge-index lists instead of pre-cooked `Shape?` results. This consolidates the resolution machinery between fillet and chamfer (chamfer used to duplicate fillet's `.all`-only path because it had no shared resolver). The OCCTSwiftIO and OCCTMCP-side consumers that read `BuildResult.histories[id]` get fillet / chamfer coverage without any code change.

**Out of scope:** variable-radius fillet via `FeatureSpec` (the `filletedWithFullHistory(edge:startRadius:endRadius:)` Tier 2 variant) — `FeatureSpec.Fillet` only carries one `radius`. Variable-radius would be a new spec variant.

### v1.0.3 (May 2026) — full per-input history Tier 2 & Tier 3 (issue #165)

Completes [#165](https://github.com/gsdali/OCCTSwift/issues/165). Builds on the boolean-history surface in v1.0.2 by extending it to modification ops and threading history capture through `FeatureReconstructor`.

**Tier 2 — modification ops with full history (+5 ops):**

```swift
extension Shape {
    func filletedWithFullHistory(radius: Double, edges: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    func filletedWithFullHistory(edge: Int, startRadius: Double, endRadius: Double)
        -> (result: Shape, history: ShapeHistoryRef)?
    func chamferedWithFullHistory(distance: Double, edges: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    func shelledWithFullHistory(facesToRemove: [Int], thickness: Double, tolerance: Double = 1e-3)
        -> (result: Shape, history: ShapeHistoryRef)?
    func defeaturedWithFullHistory(faces: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
}
```

All five reuse the existing `OCCTBooleanHistory` opaque handle (the underlying type stores a `unique_ptr<BRepBuilderAPI_MakeShape>`, which is the common base of every OCCT modification builder). For consumers, the API matches Tier 1 — `history.record(of: inputSubShape)` returns the `ShapeHistoryRecord` of `Modified` / `Generated` / `IsDeleted` lookups.

**Tier 3 — `FeatureReconstructor.BuildResult.histories`:**

```swift
public struct BuildResult: Sendable {
    // … existing fields …
    public let histories: [String: ShapeHistoryRef]
}
```

Per-feature `ShapeHistoryRef` keyed by the feature id. Populated when:
- A boolean spec (`FeatureSpec.Boolean`) with non-nil id resolves successfully — captured from `unionWithFullHistory` / `subtractedWithFullHistory` / `intersectionWithFullHistory`
- A hole spec (`FeatureSpec.Hole`) with non-nil id — captured from the underlying subtract
- An additive feature (revolve/extrude/sheet-metal) with non-nil id whose `absorbAdditive` step fuses into a non-empty `current` — captured from the union

Features without an id aren't keyed, and the existing `applyFillet` / `applyChamfer` paths still go through the non-history primitives (those cases need edge/face index computation that's tracked as a separate refinement).

This unblocks [OCCTMCP](https://github.com/gsdali/OCCTMCP)'s `remap_selection` for the `apply_feature` tool: instead of falling back to centroid-distance heuristics on splits / merges / deletions, the consumer can now walk `BuildResult.histories[feature_id].record(of: subshape)` for the exact OCCT-recorded mapping.

**Op count: 4,279 → 4,284** (+5 Tier 2 entry points). xcframework binary unchanged from v1.0.0; SPM consumers continue to resolve against the v1.0.0 asset.

### v1.0.2 (May 2026) — per-input boolean history (issue #165 Tier 1)

**Additive feature for selection-remapping consumers** ([#165](https://github.com/gsdali/OCCTSwift/issues/165)). Adds a per-input-subshape history lookup surface to the four `BRepAlgoAPI` boolean ops, addressing OCCTMCP's `remap_selection` need to walk selection IDs across boolean / split mutations exactly (instead of the centroid-distance heuristic that loses on splits / merges / deletions):

```swift
extension Shape {
    func unionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)?
    func subtractedWithFullHistory(_ tool: Shape) -> (result: Shape, history: ShapeHistoryRef)?
    func intersectionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)?
    func splitWithFullHistory(by tool: Shape) -> (pieces: [Shape], history: ShapeHistoryRef)?
}

public final class ShapeHistoryRef: @unchecked Sendable {
    func record(of inputSubShape: Shape) -> ShapeHistoryRecord  // .modified / .generated / .isDeleted
}
```

The `ShapeHistoryRef` retains the OCCT builder so `Modified` / `Generated` / `IsDeleted` stay queryable after the operation completes. Existing `BooleanResult` / `BooleanHistoryResult` callers are unchanged — pure additive surface.

**Bug fix on the way.** While building the history-handle plumbing I found that the new probe-then-fill helpers returned `0` when called with `maxCount=0` (or `outRefs=null`), breaking the Swift-side count-then-allocate idiom. Fixed: the new bridge functions now always return the full count and only stop *writing* when `count >= maxCount`. Existing callers were unaffected (none used the probe path).

xcframework binary unchanged from v1.0.0 (no OCCT version change). SPM consumers continue to resolve against the v1.0.0 asset.

**Out of scope for this release** (will land in follow-ups under #165 Tiers 2 / 3): `filletedWithFullHistory` / `chamferedWithFullHistory` / `shelledWithFullHistory` / `defeaturedWithFullHistory`, and `FeatureReconstructor.BuildResult.history`.

### v1.0.1 (May 2026) — TopologyGraph.rootNodes fix + test repair

**Bug fix.** `TopologyGraph.NodeKind` was missing `product = 10` and `occurrence = 11` cases, so `rootNodes` silently returned `[]` even when products were present (`compactMap { NodeKind(rawValue: 10) }` filtered every entry out as `nil`). After OCCT 8.0.0 beta1 reshaped root iteration to "Products only", every `rootNodes` consumer hit this. Fixed by extending the enum to cover the full `BRepGraph_NodeId::Kind` range (topology 0–8, assembly 10–11; slot 9 reserved upstream).

**Tests.** The four pre-existing failures shipped with v1.0.0 are repaired:

- `hasRoots` and `childExplorer` now wrap the box's solid in a Product via `linkProductToTopology` before querying `rootNodes` (matches OCCT 8.0 GA assembly semantics).
- `edgeVertexDistance` switched from low-level `BRepExtrema_DistanceSS` (which deliberately skips edge-vertex pairs whose closest point is at an endpoint, expecting the caller to also pair vertices-with-vertices) to high-level `Shape.distance(to:)` backed by `BRepExtrema_DistShapeShape`, which orchestrates all subshape combinations including endpoint cases.
- `edgeSelectorFeatureUnsupported` deleted — it asserted `Fillet.onFeature` was unsupported, contradicting the newer `filletOnFeature` test that asserts the opposite. `.onFeature` is wired up in `FeatureReconstructor`.

xcframework binary is unchanged from v1.0.0; SPM consumers continue resolving against the v1.0.0 asset.

### v1.0.0 (May 2026) — OCCT 8.0.0 GA — SemVer-stable

**OCCTSwift reaches SemVer-stable v1.0.0**, pinned to **OpenCASCADE Technology 8.0.0 GA** (released 2026-05-07, commit `d3056ef8` on `Open-Cascade-SAS/OCCT`). After eight months of pre-1.0 development across 170+ point releases — wrapping ~4,275 OCCT operations across 1,160+ test suites — the public Swift API is stable from this point on. Pin to `from: "1.0.0"` in `Package.swift`.

**OCCT 8.0.0 GA highlights since rc5** (per [OCCT discussion #1275](https://github.com/Open-Cascade-SAS/OCCT/discussions/1275)):

- BRepGraph (graph-based topology) and Gordon Surfaces shipped in their final shape
- TKHelix toolkit (geometric helix with B-spline approximation)
- ExtremaPC specialized point-to-curve extrema with variant dispatching
- STEP read/write thread safety: "safe under the contract of one reader or writer per thread"
- Multiple SEGV fixes in chamfer, fillet, and pipe-shell operations
- BSpline evaluation bugs corrected; geometry hashing implementations completed
- C++17 minimum (already required by Swift 6); `Standard_Failure` inherits `std::exception`

**Beta2 → GA breaking changes absorbed in this release:**

- **`PointSetLib` removed.** OCCT introduced `PointSetLib_Props` / `PointSetLib_Equation` in 8.0.0 beta1 (rc5/PCA point-cloud analysis) and removed them before GA. The Swift `PointSetLib` enum and bridge wrappers were deleted to follow upstream. If you depended on `PointSetLib.properties / barycentre / inertiaMatrix / equation`, port to your own NumPy/Accelerate implementation; the OCCT primitives are no longer available at any layer.
- **CoEdge continuity setters consolidated into `setEdgeRegularity`.** OCCT 8.0.0 GA moved continuity from per-coedge to per-`(edge, face1, face2)` (in `BRepGraph_LayerRegularity`). The pre-GA `setCoEdgeContinuity` / `setCoEdgeSeamContinuity` / `setCoEdgeSeamPairId` are replaced by a single `TopologyGraph.setEdgeRegularity(_:face1:face2:continuity:) -> Bool`. For seam continuity, pass the same face index as `face1` and `face2`. Explicit seam-pair-id is gone — seam-pair-id is structural in GA (two coedges on the same edge/face with opposite orientations); query via the existing `coedgeSeamPair` accessor.

**Removed deprecated:**

- **`TopologyGraph.occurrenceParentOccurrence(_:)`** — deprecated in v0.157.0 when OCCT 8.0.0 beta1 reshaped assembly topology to `Product → Occurrence → Product`. Use `occurrenceParentProduct(_:)`.

**Looking ahead:** OCCTSwift now moves to a **work-on-branch strategy** for upstream OCCT changes; `main` stays release-quality. Future OCCT releases land in feature branches and graduate to a tagged OCCTSwift release only when the upstream is GA.

### v0.171.0 (May 2026) — ML-export hoist to OCCTSwiftIO

**Breaking change.** The consumption-side ML repacking layer added in v0.136.0 (`TopologyGraph.GraphExport`, `exportForML()`, `exportJSON()`) has been removed and lifted to [OCCTSwiftIO](https://github.com/gsdali/OCCTSwiftIO) v0.2.0 per [OCCTSwiftIO#1](https://github.com/gsdali/OCCTSwiftIO/issues/1) (supersedes [OCCTSwift#71](https://github.com/gsdali/OCCTSwift/issues/71)). It's pure batch / headless workflow with no Viewport dependency — fits the OCCTSwiftIO charter, doesn't need to live in the kernel.

**What stays in the kernel** (and why): `FaceGridSample`, `sampleFaceUVGrid(faceIndex:uSamples:vSamples:)`, and `sampleEdgeCurve(edgeIndex:count:)`. Their implementations call C bridge functions on `TopologyGraph.handle`, which is `internal` to this module. Lifting them would require widening visibility — explicitly out of scope per the partial-lift decision recorded on the issue.

**Consumer migration:** direct callers of `exportForML` / `exportJSON` must add `import OCCTSwiftIO` alongside `import OCCTSwift`. Symbol resolution otherwise unchanged. Known external callers swept: `OCCTSwiftScripts/Sources/occtkit/Commands/GraphML.swift`, `OCCTSwiftScripts/Sources/GraphML/main.swift`.

**Net deltas:** −124 LOC in `BRepGraph.swift`, −76 LOC in `ShapeTests.swift`. xcframework binary unchanged (no bridge changes).

### v0.170.1 (May 2026) — ShapeMeasurements kernel hoist + OCCTBridge.mm split complete

**ShapeMeasurements moved to kernel** ([#100](https://github.com/gsdali/OCCTSwift/issues/100), [PR #163](https://github.com/gsdali/OCCTSwift/pull/163)). `ShapeMeasurements` (per-face areas / centroids / perimeters + per-edge lengths) and `Shape.measure(linearTolerance:)` are now part of `OCCTSwift` itself, no longer requiring a dependency on `OCCTSwiftTools`. Pure Swift relocation — no bridge changes. Existing `OCCTSwiftTools.ShapeMeasurements` callers should re-target to `import OCCTSwift` once `OCCTSwiftTools` ships its dep bump (tracked in [OCCTSwiftTools#13](https://github.com/gsdali/OCCTSwiftTools/issues/13)).

**OCCTBridge.mm split — DONE** ([#99](https://github.com/gsdali/OCCTSwift/issues/99), PRs #160-#162). The monolithic `OCCTBridge.mm` is now **393 lines** of pure foundation (header includes, global mutex, `OCCTSewing` struct, `Internal.h` import) — down from 58,168 lines pre-split (−99.3%). All 4,281 operations live in 15 per-OCCT-module translation units (`OCCTBridge_Modeling.mm`, `OCCTBridge_Topology.mm`, `OCCTBridge_Healing.mm`, `OCCTBridge_Properties.mm`, `OCCTBridge_Geom2d.mm`, `OCCTBridge_Surface.mm`, `OCCTBridge_Curve3D.mm`, `OCCTBridge_Document.mm`, `OCCTBridge_IO.mm`, `OCCTBridge_Mesh.mm`, `OCCTBridge_Spatial.mm`, `OCCTBridge_BRepGraph.mm`, `OCCTBridge_AIS.mm`, `OCCTBridge_Visualization.mm`, `OCCTBridge_ProjLib_NLPlate.mm`). Net-zero behavior change throughout; public C surface unchanged. The xcframework binary is identical to v0.170.0 (no OCCT changes), so SPM consumers can continue using the v0.170.0 binary URL.

### v0.170.0 (May 2026) — OCCT 8.0.0-beta2 ingest

xcframework rebuilt against `V8_0_0_beta2`. No public API changes — beta2 is a small follow-up to beta1 with no API breakage. Final 8.0.0 release remains targeted for May 7, 2026.

Upstream changes that landed in beta2:

- **Thread-safe STEP write + STEP/IGES read** ([OCCT #1259](https://github.com/Open-Cascade-SAS/OCCT/pull/1259)) — fixes `libmalloc` double-free under concurrent `STEPControl_Writer::Transfer` and intermittent crashes in concurrent STEP/IGES readers. Contract: one reader/writer per thread; STEP read + write safe under that contract; IGES read still requires explicit serialization. OCCTSwift already serializes IGES via `igesMutex()` and STEP via `occtGlobalMutex()`, so the upstream fix is a net safety improvement without requiring bridge changes.
- **CPU grid path restored** ([OCCT #1252](https://github.com/Open-Cascade-SAS/OCCT/pull/1252)) — the classical `Graphic3d_Structure`-based grid removed in beta1 is back as a coexisting backend. Doesn't surface in OCCTSwift (no grid API exposed).
- **Documentation refresh + samples directory + CI warning cleanup** — internal to upstream; no impact on consumers.

OCCTSwift surface unchanged: 4,281 wrapped operations, 3,393 tests, 1,178 suites, identical Swift `OCCTSwift.*` API.

### v0.169.0 (May 2026) — Mesh + export progress (issue #98 follow-up)

Extends the `ImportProgress` channel from v0.168 to two more long-running OCCT operations called out as out-of-scope in the original issue: `BRepMesh_IncrementalMesh::Perform` and the STEP / IGES writers. Same protocol, same cancellation contract.

**New Swift API**:

```swift
extension Shape {
    /// Run BRepMesh_IncrementalMesh with progress + cooperative cancellation.
    /// Throws ImportError.cancelled if cancelled.
    @discardableResult
    public func meshWithProgress(
        linearDeflection: Double = 0.1,
        angularDeflection: Double = 0.5,
        progress: ImportProgress? = nil
    ) throws -> Shape
}

extension Exporter {
    /// Export a shape to STEP with progress + cancellation.
    /// Throws ExportError.cancelled if cancelled.
    public static func writeSTEP(shape: Shape, to url: URL, progress: ImportProgress?) throws

    /// Export a shape to IGES with progress + cancellation.
    public static func writeIGES(shape: Shape, to url: URL, progress: ImportProgress?) throws
}

extension Document {
    /// Write the document to a STEP file with progress + cancellation.
    /// Throws ImportError.cancelled if cancelled.
    public func writeSTEP(to url: URL, progress: ImportProgress?) throws
}

extension ExportError {
    case cancelled
}
```

**Bridge plumbing**: 5 new entry points (`OCCTShapeIncrementalMeshProgress`, `OCCTExportSTEPProgress`, `OCCTExportSTEPWithModeProgress`, `OCCTExportIGESProgress`, `OCCTDocumentWriteSTEPProgress`) reusing the existing `BridgeProgressIndicator` from v0.168. `BRepMesh_IncrementalMesh::Perform(Message_ProgressRange&)`, `STEPControl_Writer::Transfer(...range)`, `IGESControl_Writer::AddShape(...range)`, and `STEPCAFControl_Writer::Transfer(...range)` all accept the indicator's progress range.

**Why `ImportProgress` is the type for export too**: it's the same channel — progress + cancel. Adding parallel `ExportProgress`/`MeshProgress` protocols would multiply types without functional benefit. The protocol name reads slightly oddly in export contexts; pre-1.0 we accept that, and v1.0 will likely rename to `OperationProgress`.

6 new tests cover meshing progress + cancellation, STEP/IGES export with `progress: nil` (back-compat), STEP export progress fires, and `Document.writeSTEP(to:progress:)` round-trip.

### v0.168.0 (May 2026) — STEP/IGES import progress + cancellation (issue #98)

Wraps OCCT's `Message_ProgressIndicator` so callers of `Shape.loadSTEP / loadIGES / loadIGESRobust` and `Document.load / loadSTEP` can observe progress and cooperatively cancel long-running imports.

**New Swift API**:

```swift
public protocol ImportProgress: AnyObject, Sendable {
    func progress(fraction: Double, step: String)
    func shouldCancel() -> Bool   // default: false
}

extension ImportError {
    case cancelled
}

extension Shape {
    public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Shape
    public static func loadSTEP(from url: URL, unitInMeters: Double, progress: ImportProgress? = nil) throws -> Shape
    public static func loadIGES(from url: URL, progress: ImportProgress? = nil) throws -> Shape
    public static func loadIGESRobust(from url: URL, progress: ImportProgress? = nil) throws -> Shape
}

extension Document {
    public static func load(from url: URL, progress: ImportProgress? = nil) throws -> Document
    public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Document
    public static func loadSTEP(from url: URL, modes: STEPReaderModes, progress: ImportProgress?) throws -> Document
}
```

`progress: nil` (the default) keeps existing call sites source-compatible — no behavioural change for callers that haven't opted in.

**Bridge plumbing**: 7 new `*Progress` C entry points in `OCCTBridge` plus an internal `BridgeProgressIndicator` subclass of `Message_ProgressIndicator` that forwards `Show()` to a Swift callback (via opaque `userData` + `@convention(c)` trampoline) and reports `UserBreak() == true` when the Swift `shouldCancel()` returns true. `STEPControl_Reader::TransferRoots`, `IGESControl_Reader::TransferRoots`, and `STEPCAFControl_Reader::Transfer` all accept the indicator's progress range.

**Cancellation contract**: `shouldCancel()` is polled at OCCT's progress checkpoints (typically once per transferred entity). Returning `true` causes the loader to throw `ImportError.cancelled` at the next boundary. The shape / document is not partially constructed.

4 new tests cover (1) progress callback fires for a round-tripped STEP file, (2) `progress: nil` back-compat path still works, (3) cancellation flag honored, (4) `Document.load` progress.

**Driver**: unblocks [OCCTSwiftTools](https://github.com/gsdali/OCCTSwiftTools) v0.4.0 — its `CADFileLoader.load(from:format:)` async API can now pass `progress` straight through, giving OCCTSwiftAIS' file-open dialog a real progress bar and cancel button "for free".

### v0.167.0 (May 2026) — visionOS + tvOS support

OCCT.xcframework now ships **seven slices**:

| Platform | Slice |
|---|---|
| macOS 12+ arm64 | `macos-arm64` |
| iOS 15+ device arm64 | `ios-arm64` |
| iOS 15+ Simulator arm64 | `ios-arm64-simulator` |
| visionOS 1+ device arm64 | `xros-arm64` (new) |
| visionOS 1+ Simulator arm64 | `xros-arm64-simulator` (new) |
| tvOS 15+ device arm64 | `tvos-arm64` (new) |
| tvOS 15+ Simulator arm64 | `tvos-arm64-simulator` (new) |

`Package.swift` declares `.visionOS(.v1)` and `.tvOS(.v15)` alongside the existing `.iOS(.v15)` / `.macOS(.v12)`. The xcframework asset attached to this release is ~341 MB (up from 148 MB at v0.165.0; quadruples the slice count).

**Build script changes** (`Scripts/build-occt.sh`) — required to make OCCT 8 cross-compile cleanly to visionOS and tvOS SDKs:

- Added four new build blocks (`visionOS device`, `visionOS Simulator`, `tvOS device`, `tvOS Simulator`).
- Each new block sets `-DCMAKE_SIZEOF_VOID_P=8` to bypass OCCT's `OCCT_MAKE_COMPILER_BITNESS` cmake macro, which couldn't autodetect pointer size on the visionOS SDK (`32 + 32*(/8)` syntax error from an empty `CMAKE_C_SIZEOF_DATA_PTR`).
- Removed explicit `-mtargetos=` / `-m*-version-min=` flags from the C/CXX flags — clang rejects them when CMake already sets `--target=arm64-apple-xros1.0` from the SDK + deployment target. Letting CMake derive the target is the correct path.
- xcframework creation step now conditionally includes each platform slice: if a slice fails to build (empty `.a`), the xcframework is built without it instead of aborting the whole script.

`OCCT.xcframework.zip` checksum: `5147b7d65cd9af5a6c3af1b38a1492365e645ed5c76a663bf9311c2f54043d87`.

### v0.166.1 (May 2026) — Platform plan refinement

Metadata-only patch revising the v1.0.0 platform expansion plan:

- **Dropped Intel Mac (`macOS x86_64`).** Apple is winding down Intel macOS support; not worth the build slot.
- **visionOS confirmed for v1.0.0.** Device + simulator slices.
- **tvOS reduced to "if cheap".** Will only add if it falls out of the visionOS work without extra effort.
- **Linux / Windows / Android — moved to "under review"** with a full analysis in [docs/platform-expansion.md](../docs/platform-expansion.md). Headline: Linux is the strongest non-Apple candidate (~2 weeks of focused work), Windows is medium-risk, Android should wait for Swift-on-Android packaging to stabilize. The prerequisite for any non-Apple port is the OCCTBridge `.mm` → `.cpp` audit, which is independently useful.

### v0.166.0 (May 2026) — Swift Package Index readiness

Preparation for a public listing on [Swift Package Index](https://swiftpackageindex.com) alongside v1.0.0. No code changes; metadata only.

**Added:**

- `.spi.yml` — SPI build matrix declaration:
  - macOS via SPM on Swift 6.0, 6.1, 6.2, 6.3
  - iOS on Swift 6.3
  - DocC documentation target: `OCCTSwift`
- `CODE_OF_CONDUCT.md` — short pointer to Contributor Covenant 2.1 with reports email.
- README:
  - SPI shields.io badges (Swift versions, platforms) — activate once the package is added to SPI.
  - Updated install snippet from stale `from: "0.128.0"` to current `from: "0.165.0"`.
  - "Supported Platforms" table covering current support and v1.0.0 expansion plan (Intel Mac, visionOS).
  - Documented Swift 6.1+ verified clean against 6.1 / 6.2 / 6.3 toolchains.

**Submission gating:** waiting until v1.0.0 ships (May 7, 2026, alongside OCCT 8.0.0 GA) before submitting to SPI. v0.166 makes the repo submission-ready.

### v0.165.0 (May 2026) — Fix SPM xcframework URL (issue #97)

`Package.swift` had its remote `binaryTarget(url:)` hardcoded to the **v0.131.0** xcframework — predating OCCT 8 by months. SPM consumers pinning `from: "0.157.0"` resolved the version correctly but the build failed at compile-time with `'BRepGraph_MeshView.hxx' file not found` because the v0.131.0 binary was built against rc-era OCCT and didn't ship the beta1 headers that the v0.157+ wrappers reference. Local-path consumers were unaffected (the auto-detect picks up `Libraries/OCCT.xcframework`).

This release:

1. Attaches the current beta1 xcframework as a release asset (`OCCT.xcframework.zip`, ~148 MB).
2. Updates `Package.swift`'s remote URL to point at the v0.165.0 release and bumps the SPM checksum to `99bba63c0e686195512cfaa4f3f46f9f11c8b6cd89e8fe5b8aed872a48978003`.

After this release, `from: "0.165.0"` resolves cleanly for remote-pin consumers and the v0.157.0 → v0.164.0 wrapper surface (MeshView, MeshCache, EditorView mutation, ProductOps, RepOps + cache inspection) becomes usable downstream. Downstream Package.swift consumers should bump their pin to `from: "0.165.0"`.

No new ops; this is purely a packaging fix.

### v0.164.0 (May 2026) — RepOps non-guard setters & cache entry inspection (21 ops)

Final wrapping pass for OCCT 8.0.0 beta1 BRepGraph surface. After this release, the public surface of `BRepGraph::EditorView` and `BRepGraph::MeshView` is exhaustively wrapped on `TopologyGraph`.

**RepOps non-guard setters** — swap geometry / mesh content bound to an existing rep id without recreating the rep:

```swift
graph.repSetSurface(repId, surface: newSurface)
graph.repSetCurve3D(repId, curve: newCurve3D)
graph.repSetCurve2D(repId, curve: newCurve2D)
graph.repSetTriangulation(repId, triangulation: newTri)
graph.repSetPolygon3D(repId, polygon: newPoly3D)
graph.repSetPolygon2D(repId, polygon: newPoly2D)
graph.repSetPolygonOnTri(repId, polygon: newPolyOnTri)
graph.repSetPolygonOnTriTriangulationId(polyOnTriRepId, triRepId: newTriRepId)
```

**Cache entry inspection** — detailed access to the algorithm-derived cache tier for diagnostics and non-destructive mesh tooling:

```swift
graph.cachedFaceMeshIsPresent(0)              // Bool
graph.cachedFaceMeshTriRepCount(0)            // Int
graph.cachedFaceMeshActiveIndex(0)            // Int (-1 if absent)
graph.cachedFaceMeshStoredOwnGen(0)           // UInt32 (cache freshness gen)
graph.cachedFaceMeshTriRepId(0, repIndex: 0)  // Int? (active or specific entry)

graph.cachedEdgeMeshIsPresent(0)
graph.cachedEdgeMeshPolygon3DRepId(0)
graph.cachedEdgeMeshStoredOwnGen(0)

graph.cachedCoEdgeMeshIsPresent(0)
graph.cachedCoEdgeMeshPolygon2DRepId(0)
graph.cachedCoEdgeMeshPolygonOnTriRepCount(0)
graph.cachedCoEdgeMeshPolygonOnTriRepId(0, repIndex: 0)
graph.cachedCoEdgeMeshStoredOwnGen(0)
```

The `StoredOwnGen` accessors expose the cache freshness generation — pair with the entity's current OwnGen (via existing readers) to detect stale cache entries.

3 new tests cover fresh-graph absence, post-`appendCachedTriangulation` state readback, and edge/coedge cache absence.

### v0.163.0 (May 2026) — EditorView ProductOps assembly building (5 ops)

Closes the **EditorView mutation surface**. With v0.163.0 the public mutation API of `BRepGraph::EditorView` is fully wrapped on `TopologyGraph`.

```swift
let parent = graph.createEmptyProduct()!
let child = graph.linkProductToTopology(
    shapeRootKind: 0, shapeRootIndex: 0,
    placement: TopologyGraph.identityLocationMatrix)!
let linked = graph.linkProducts(
    parentProductIndex: parent,
    referencedProductIndex: child,
    placement: TopologyGraph.identityLocationMatrix)!
// linked.occurrenceIndex, linked.occurrenceRefIndex

graph.productRemoveOccurrence(parent, occurrenceRefIndex: linked.occurrenceRefIndex)
graph.productRemoveShapeRoot(child)
```

`linkProductToTopology` accepts `placement: nil` for an identity placement. `linkProducts` takes a `parentOccurrenceIndex: Int?` (nil for unparented).

2 new tests cover the create/link path and remove-with-bogus-ids no-crash safety.

### v0.162.0 (May 2026) — EditorView geometric setters, location setters, PCurve API (16 ops)

Closes the EditorView wrapping started in v0.159.0. With v0.162.0 the public mutation surface of `BRepGraph::EditorView` is fully wrapped on `TopologyGraph`.

**CoEdge geometric setters:**
- `setCoEdgeUVBox(_:u1:v1:u2:v2:)`
- `setCoEdgeContinuity` / `setCoEdgeSeamContinuity` (GeomAbs_Shape: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN)
- `setCoEdgeSeamPairId`

**Face geometric setter:**
- `setFaceTriangulationRep(_:triRepId:)` — bind the active triangulation to a face's persistent tier (vs `appendCachedTriangulation` for the cache tier)

**CoEdge PCurve API** (uses existing `Curve2D` Swift type):
- `coEdgeCreateCurve2DRep(_ curve2D:)` → rep id
- `coEdgeSetPCurve(_ coedgeIndex:curve2D:)` (pass nil to clear)
- `coEdgeAddPCurve(edgeIndex:faceIndex:curve2D:first:last:orientation:)`

**Location setters via 12-double 3x4 matrix** (`gp_Trsf::SetValues` row-major convention):
- `setVertexRefLocalLocation`, `setCoEdgeRefLocalLocation`, `setWireRefLocalLocation`
- `setFaceRefLocalLocation`, `setShellRefLocalLocation`, `setSolidRefLocalLocation`
- `setOccurrenceRefLocalLocation`, `setChildRefLocalLocation`
- Convenience: `TopologyGraph.identityLocationMatrix` returns the 3x4 identity

3 new tests cover CoEdge geometric setters on real coedges, identity-matrix location setters on real refs, and face-triangulation binding with MeshView readback.

### v0.161.0 (May 2026) — EditorView Add / Remove / Ref setters (41 ops)

Continues the EditorView wrapping started in v0.159.0 with the structural-mutation surface:

**Add operations** (return ref id or nil):
- `edgeAddInternalVertex(_:vertexIndex:orientation:)`
- `faceAddVertex(_:vertexIndex:orientation:)`
- `shellAddChild(_:childKind:childIndex:orientation:)`
- `solidAddChild(_:childKind:childIndex:orientation:)`
- `compoundAddChild(_:childKind:childIndex:orientation:)`
- `compSolidAddSolid(_:solidIndex:orientation:)`

**Remove operations** (return Bool indicating active-usage removal):
- `edgeRemoveVertex`, `edgeReplaceVertex` (returns new ref id)
- `wireRemoveCoEdge`, `faceRemoveVertex`, `faceRemoveWire`
- `shellRemoveFace`, `shellRemoveChild`
- `solidRemoveShell`, `solidRemoveChild`
- `compoundRemoveChild`, `compSolidRemoveSolid`
- `removeRep(repKind:repIndex:)` — generic representation removal

**Ref setters** (entity-ref → entity-def rebinding, orientation, rep-id binding):
- Vertex: `setVertexRefOrientation`, `setVertexRefVertexDefId`
- Edge: `setEdgeStartVertexRefId`, `setEdgeEndVertexRefId`, `setEdgeCurve3DRepId`, `setEdgePolygon3DRepId`
- CoEdge: `setCoEdgeRefCoEdgeDefId`, `setCoEdgeEdgeDefId`, `setCoEdgeFaceDefId`, `setCoEdgeCurve2DRepId`, `setCoEdgePolygon2DRepId`, `setCoEdgePolygonOnTriRepId`, `clearCoEdgePCurveBinding`
- Wire: `setWireRefIsOuter`, `setWireRefOrientation`, `setWireRefWireDefId`
- Face: `setFaceSurfaceRepId`, `setFaceRefOrientation`, `setFaceRefFaceDefId`
- Shell: `setShellRefOrientation`, `setShellRefShellDefId`
- Solid: `setSolidRefOrientation`, `setSolidRefSolidDefId`
- Occurrence: `setOccurrenceChildDefId`, `setOccurrenceRefOccurrenceDefId`
- Generic: `setChildRefOrientation`, `setChildRefChildDefId`

Setters that need `TopLoc_Location` or `Bnd_Box2d` (e.g. `*RefLocalLocation`, `CoEdge.SetUVBox`, `CoEdge.SetContinuity`) are deferred until a 12-double / 4-double calling convention lands in the bridge.

3 new tests cover Add no-crash safety, Remove returning false on bogus ref ids, and Ref setters operating on real box ids without crashing.

### v0.160.0 (May 2026) — MeshCache write API + new `Triangulation` type

Completes the OCCT 8.0.0 beta1 two-tier mesh storage wrapping started in v0.158.0. The cache write side — `BRepGraph_Tool::Mesh` static helpers — is now exposed on `TopologyGraph`, and a new `Triangulation` Swift class wraps `Handle<Poly_Triangulation>` for input.

**New `Triangulation` class** (mirrors the existing `Polygon3D` / `PolygonOnTriangulation` pattern):

```swift
let tri = Triangulation.create(
    nodes: [SIMD3(0,0,0), SIMD3(1,0,0), SIMD3(0,1,0), SIMD3(1,1,0)],
    triangles: [0,1,2, 1,3,2]
)!
tri.nodeCount        // 4
tri.triangleCount    // 2
tri.node(at: 0)      // SIMD3(0, 0, 0)
tri.triangle(at: 0)  // (0, 1, 2)
tri.deflection = 0.01
```

Vertex indices are 0-based on the Swift boundary; the bridge handles OCCT's 1-based convention internally.

**MeshCache write API** on `TopologyGraph`:

```swift
let triRepId = graph.createTriangulationRep(tri)!
graph.appendCachedTriangulation(faceIndex: 0, triRepId: triRepId)
graph.setCachedActiveIndex(faceIndex: 0, activeIndex: 0)

let polyRepId = graph.createPolygon3DRep(polygon3d)!
graph.setCachedPolygon3D(edgeIndex: 0, polyRepId: polyRepId)

let polyOnTriRepId = graph.createPolygonOnTriRep(polygonOnTri, triRepId: triRepId)!
graph.appendCachedPolygonOnTri(coedgeIndex: 0, polyRepId: polyOnTriRepId)
graph.setCachedPolygon2D(coedgeIndex: 0, poly2DRepId: ...)
```

This unblocks downstream tooling (OCCTMCP, OCCTSwiftScripts) that wants to populate algorithm-derived mesh data on a graph without touching the persistent (STEP-imported) tier — important for non-destructive meshing workflows.

4 new tests cover Triangulation construction round-trip, malformed-input rejection, and rep-creation + face/edge binding with subsequent MeshView readback.

### v0.159.0 (May 2026) — EditorView field setters

OCCT 8.0.0 beta1's `BRepGraph::EditorView` exposes per-entity `Ops` classes with `Set*` methods that mutate field-level data on existing graph entities (without requiring a full topology rebuild). v0.159.0 wraps the simple-value subset (scalars, bools, orientations) on the `TopologyGraph` Swift type:

**VertexOps** — `setVertexPoint(_:x:y:z:)`, `setVertexTolerance(_:tolerance:)`

**EdgeOps** — `setEdgeTolerance`, `setEdgeParamRange(_:first:last:)`, `setEdgeSameParameter`, `setEdgeSameRange`, `setEdgeDegenerate`, `setEdgeIsClosed`

**CoEdgeOps** — `setCoEdgeParamRange`, `setCoEdgeOrientation` (Forward/Reversed/Internal/External as Int 0–3)

**WireOps** — `setWireIsClosed`

**FaceOps** — `setFaceTolerance`, `setFaceNaturalRestriction`

**ShellOps** — `setShellIsClosed`

All 14 setters are pass-through to the corresponding `g.Editor().<Entity>().Set*(...)` on the OCCT side. Invalid ids are no-ops (try/catch in bridge). Setters that require new opaque types — `SetPCurve`, `SetSurfaceRepId`, `SetTriangulationRep`, `Mut*` RAII guards — are deferred. Same with `Add*` / `Remove*` mutation methods that aren't already wrapped via the Builder bridge functions.

Driver: lets headless tooling (OCCTMCP, OCCTSwiftScripts) tweak field-level data after constructing a graph (e.g. relax a tolerance, mark an edge degenerate) without round-tripping through `TopoDS_Shape` rebuilds.

4 new tests cover set-then-read-back where a getter exists, plus no-crash safety on the readback-less setters.

### v0.158.0 (May 2026) — MeshView two-tier mesh storage (read API)

OCCT 8.0.0 beta1 introduced a two-tier mesh storage model: an algorithm-derived **cache** (populated by `BRepGraphMesh`) and the **persistent** tier (mesh data imported from STEP, stored in topology definitions). v0.158.0 wraps the read-side of this model — `BRepGraph::MeshView` queries — exposing it on the existing `TopologyGraph` Swift type:

- Counts: `polygon2DCount`, `polygonOnTriCount`, `activeTriangulationCount`, `activePolygon3DCount`, `activePolygon2DCount`, `activePolygonOnTriCount`. Pairs with the existing `triangulationCount` / `polygon3DCount` from v0.133.0.
- Per-entity cache-first queries:
  - `meshFaceActiveTriangulationRepId(_ faceIndex:)` → optional rep id (cache-first, persistent fallback)
  - `meshEdgePolygon3DRepId(_ edgeIndex:)` → optional rep id (cache-first, persistent fallback)
  - `meshCoEdgeHasMesh(_ coedgeIndex:)` → bool (cache-only)

The Swift API is unchanged for existing call sites. Driver: prep for future BRepGraphMesh-driven workflows in OCCTMCP / OCCTSwiftScripts that want to introspect mesh state without invalidating the persistent tier.

The mesh **write** API (`BRepGraph_Tool::Mesh::CreateTriangulationRep` etc.) is intentionally not yet wrapped — it requires marshaling `Handle<Poly_Triangulation>` from Swift, which is a larger lift. Targeted for v0.159 or v1.0.

### v0.157.0 (May 2026) — OCCT 8.0.0 beta1 support (final pre-1.0 release)

xcframework rebuilt against `V8_0_0_beta1`. v1.0.0 will follow on May 7, 2026 pinned to the OCCT 8.0.0 GA tag.

Bridge migrations driven by upstream API churn since rc5:

- **`BRepGraph_BuilderView` removed** ([OCCT #1237](https://github.com/Open-Cascade-SAS/OCCT/pull/1237)) → migrated all 22 mutation entry points to `BRepGraph_EditorView`. Old: `g.Builder().AddVertex(p, t)`; new: `g.Editor().Vertices().Add(p, t)`. Swift API surface unchanged.
- **`NCollection_Vector` deprecated** ([OCCT #1230](https://github.com/Open-Cascade-SAS/OCCT/pull/1230)) → switched 4 internal sites to `NCollection_DynamicArray`, including the `BRepGraph_History::Record` mapping container.
- **`Builder().AppendFlattenedShape` / `AppendFullShape` consolidated** → both now route through the static `BRepGraph_Builder::Add(graph, shape, options)`. The `Flatten` and `CreateAutoProduct` options preserve the pre-beta1 distinction.
- **`Builder().ClearFaceMesh` / `ClearEdgePolygon3D` moved** → now `BRepGraph_Tool::Mesh::ClearFaceCache` / `ClearEdgeCache`. Semantic shift: clears only the new cached-mesh tier, not persistent (STEP-imported) mesh data.
- **`graph.Build(shape, parallel)` removed** → wrapper now calls the static `BRepGraph_Builder::Add(graph, shape, opts)` with `CreateAutoProduct = false` to preserve the historical "no auto Product wrap" behaviour.
- **`graph.RootNodeIds()` → `graph.RootProductIds()`** — root iteration is now Products only.
- **`BRepGraph_Copy::CopyFace` → `CopyNode`** — single-node deep copy now takes any NodeId kind.
- **`Topo().Occurrences().ParentOccurrence` removed** — beta1 model is `Product → Occurrence → Product`; an occurrence has no parent occurrence. Wrapper retained as `-1` sentinel for ABI; will be removed in v1.0.
- **`BRepGraph_ChildExplorer::Current()` returns `BRepGraphInc::NodeInstance`** (was `NodeUsage`); field accessor unchanged.
- **`BRepGraph_Tool::Edge::StartVertex` / `EndVertex` renamed** to `StartVertexId` / `EndVertexId`; return type simplified from a `VertexRef` struct to `BRepGraph_VertexId`.
- **`Topo().Poly().Nb*` moved to `Mesh().Poly().Nb*`** — triangulation/polygon counts live on the new MeshView, paired with the two-tier mesh storage.

New beta1 surface (`BRepGraph_MeshCache`, `BRepGraph_MeshView` read-side, `EditorView` per-entity Ops methods, `BRepGraph_Tool::Mesh` cache-write API) is **deferred to v0.158 / v1.0** — kept v0.157 minimal to preserve the soak window.

The 1300+ existing tests continue to pass under serial execution (`OCCT_SERIAL=1` with `--num-workers 1`); the pre-existing parallel-execution NCollection arm64 race remains the same as v0.156.

### v0.156.3 (Apr 2026) — `Document.node(at:)` warms up the labelId registry (issue #95)

The `Document.node(at:)` lookup added in v0.156.1 returned `nil` on a freshly-loaded STEP document if `rootNodes` hadn't been walked first. Cause: the bridge's labelId-to-`TDF_Label` registry is populated lazily via `registerLabel(...)` calls — `OCCTDocumentLabelIsNull(0)` reports null because `labels[0]` doesn't exist yet. `rootNodes` warms it up because `OCCTDocumentGetRootLabelId(handle, i)` calls `registerLabel`, but `OCCTDocumentGetRootCount` alone doesn't.

`node(at:)` now eagerly iterates root indices to register top-level labels before the IsNull check:

```swift
public func node(at labelId: Int64) -> AssemblyNode? {
    let rootCount = OCCTDocumentGetRootCount(handle)
    for i in 0..<rootCount { _ = OCCTDocumentGetRootLabelId(handle, i) }
    guard !OCCTDocumentLabelIsNull(handle, labelId) else { return nil }
    return AssemblyNode(document: self, labelId: labelId)
}
```

Deep-child labelIds aren't registered by this warmup — those are expected to have been registered earlier by an explicit traversal (e.g. via `node.children`). The contract docstring spells this out.

`mainLabel` was checked for the same lazy-init quirk and is fine as-is — `OCCTDocumentGetMainLabel` calls `registerLabel(main)` itself.

Driver: [OCCTSwiftScripts#23](https://github.com/gsdali/OCCTSwiftScripts/issues/23)'s `set-metadata` verb. The downstream workaround (`_ = document.rootNodes.count` before `node(at:)`) can be removed.

One new regression test: load a STEP doc, look up `node(at: 0)` *without* touching `rootNodes` first, expect a non-nil node with `labelId == 0`.

### v0.156.2 (Apr 2026) — Public `Mesh(vertices:normals:indices:)` constructor (issue #94)

`Mesh` had `internal init(handle:)` and no public way to construct from raw vertex/index arrays. This blocked sibling packages (notably [OCCTSwiftMesh](https://github.com/gsdali/OCCTSwiftMesh)) from returning `Mesh` instances produced by mesh-domain algorithms (decimation, smoothing, repair, remeshing) that operate purely on vertex/index buffers and have no B-Rep state.

```swift
let mesh = Mesh(
    vertices: [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)],
    indices: [0, 1, 2]
)
```

Optional `normals: [SIMD3<Float>]?` parameter — when nil, per-vertex normals are computed by averaging the face normals of adjacent triangles (smooth shading default). Per-triangle normals are always computed from the geometry. `faceIndices` is set to `-1` for every triangle (no B-Rep source).

Failable initializer rejects: empty inputs, index count not divisible by 3, indices out of range, mismatched normals count.

Bridge: one new symbol `OCCTMeshCreateFromArrays(vertices, vertexCount, normals, indices, indexCount) -> OCCTMeshRef?` — caller releases via the existing `OCCTMeshRelease`. Unblocks [OCCTSwiftMesh#1](https://github.com/gsdali/OCCTSwiftMesh/issues/1) (v0.1.0 — `Mesh.simplified(_:)` via vendored meshoptimizer).

7 new tests covering round-trip, computed-normals correctness, supplied-normals preservation, and all four invalid-input rejection paths.

### v0.156.1 (Apr 2026) — Public `AssemblyNode.labelId` + `Document.node(at:)` lookup (issue #93)

`AssemblyNode.labelId` was `internal` even though every other `Document` API works in terms of `Int64` labelIds (`removeShape(labelId:)`, `componentLabelId(...)`, `expandShape(labelId:)`, etc.). Consumers walking the assembly via `Document.rootNodes → AssemblyNode.children` couldn't read each node's `labelId` to identify it across calls. Driver: [OCCTSwiftScripts#23](https://github.com/gsdali/OCCTSwiftScripts/issues/23) (`occtkit inspect-assembly` / `set-metadata`) needs stable IDs that round-trip.

Two tiny additive changes:

```swift
// 1. labelId is now public
public let labelId: Int64

// 2. New lookup on Document
public func node(at labelId: Int64) -> AssemblyNode?
```

`node(at:)` validates the labelId via `OCCTDocumentLabelIsNull` (O(1), consistent with the rest of the int64-based Document API) and returns `nil` for unknown labelIds. LabelIds are stable within a single `Document` instance — round-trips with `rootNodes` traversal in the same session.

No bridge changes. Two new tests covering the round-trip and rejection of nonexistent labelIds.

### v0.156.0 (Apr 2026) — Quality release: drop deprecated `GCE2d_*` symbols

OCCT 8.0.0 deprecated the entire `GCE2d_Make*` family of 2D geometry constructors in favour of the canonical `GC_Make*2d` names — each old class is now literally a `using GCE2d_X = GC_X2d` typedef alias. This release migrates all internal C++ uses inside `OCCTBridge.mm` to the canonical names so we're no longer building against deprecated identifiers.

```
GCE2d_MakeArcOfCircle   → GC_MakeArcOfCircle2d
GCE2d_MakeArcOfEllipse  → GC_MakeArcOfEllipse2d
GCE2d_MakeArcOfHyperbola → GC_MakeArcOfHyperbola2d
GCE2d_MakeArcOfParabola → GC_MakeArcOfParabola2d
GCE2d_MakeCircle        → GC_MakeCircle2d
GCE2d_MakeEllipse       → GC_MakeEllipse2d
GCE2d_MakeHyperbola     → GC_MakeHyperbola2d
GCE2d_MakeLine          → GC_MakeLine2d
GCE2d_MakeMirror        → GC_MakeMirror2d
GCE2d_MakeParabola      → GC_MakeParabola2d
GCE2d_MakeRotation      → GC_MakeRotation2d
GCE2d_MakeScale         → GC_MakeScale2d
GCE2d_MakeSegment       → GC_MakeSegment2d
GCE2d_MakeTranslation   → GC_MakeTranslation2d
```

14 `#include` directives + ~30 internal symbol uses migrated. Bridge ABI unchanged: the bridge's own C function names (`OCTGCE2dMake*`) are preserved so Swift wrappers continue to call them by their existing names — this is a **non-breaking** internal hygiene release.

Operation count, test count, and suite count are unchanged — same OCCT objects, just constructed via canonical names. The `@Suite("GCE2d_MakeLine")` test label was renamed to `@Suite("GC_MakeLine2d")` for consistency. Source comments and `// MARK:` headers in `Sources/OCCTSwift/Curve2D.swift` and `Sources/OCCTSwift/Document.swift` were updated similarly.

This was the cleanup-half of a rescoped v0.156.0 plan. The OCAF/Message data introspection scope originally pencilled in for v0.156.0 was abandoned after a full audit revealed the project is at the asymptote of useful OCCT public surface — most flagged "missing" classes were already wrapped via the established `OCCTDocumentRef` + `int64_t labelId` pattern, and the genuinely unwrapped classes (~25 ops total: `gp_Vec2f/3f`, `GeomConvert_FuncCone/Cylinder/SphereLSDist`) are too small to justify a 100-op release on their own.

### v0.155.1 (Apr 2026) — `Wire(_:Shape)` convenience initializer (issue #91)

Completes the v0.154.0 trio. Recovers a typed `Wire` from a generic `Shape` that wraps a `TopoDS_Wire`, returning nil on type mismatch. Mirrors `Face(_:Shape)` and `Edge(_:Shape)`.

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
let wireShapes = box.subShapes(ofType: .wire)
if let wire = Wire(wireShapes[0]) {
    // typed Wire recovered from a wire-typed Shape
}
```

Unblocks face-rebuild flows where existing inner wires (returned as `[Shape]` from `Shape.wires` or `subShapes(ofType: .wire)`) need to be passed back into `Shape.face(outer:holes:)` — previously those wires were stuck as `Shape` because the `Wire(handle:)` initializer was internal. Concrete motivating case: preserving both bore and chamfer outlines on the same mid-face when extracting countersink mid-surfaces in [UnfoldEngine](https://github.com/gsdali/UnfoldEngine).

Bridge: one new symbol `OCCTWireFromShape(OCCTShapeRef) -> OCCTWireRef?`.

### v0.155.0 (Apr 2026) — `SheetMetal.Builder`: convex bends (issue #89)

The v0.151–v0.153 builder only supported **concave** bends (L-bracket-style, where the two flanges' bodies overlap in volume around the seam). **Convex** bends — Z-section middle bends, offset brackets, gusseted brackets where one flange folds back on the opposite side — failed with `BuildError.filletFailed` because the seam edge is non-manifold (a kiss point with four boundary faces meeting at one line, which `BRepFilletAPI_MakeFillet` rejects).

v0.155 adds first-class convex bend support:

- **Auto-detected direction.** Each bend is classified concave or convex from the relative position of the two flanges' body centroids. No caller change needed; the existing v0.151–v0.153 fixtures (L, U, stepped Z) continue to build identically because they're all concave.

- **Convex bend material.** Convex bends build a **curved-triangle prism** that bridges the two flanges' outer-corner edges with a cylindrical fillet on the outside surface, then boolean-fuses with the flanges. The "kiss point" stays sharp on the inside (which is the natural CAD interpretation when the user's flange placements don't leave room for an inside cylinder); the outside is rounded to the bend radius.

- **`Bend` struct expanded** with optional explicit controls:
  - `angle: Double?` — bend angle in radians, signed (positive = concave, negative = convex). Nil means auto-infer from flange positions. Sign convention follows OCCT's right-hand rule: angles are CCW-positive about the bend axis derived from `cross(fromFlange.normal, toFlange.normal)`, with concave-positive matching how a CAD designer thinks about bends.
  - `insideRadius: Double` — replaces the legacy single `radius` (which still works as a convenience init).
  - `outsideRadius: Double?` — independent control of the outside fillet radius. Defaults to nil = match insideRadius for convex builds.
  - `materialThicknessAtBend: Double?` — allow thinner material in the bend region than the flange thickness, common in etched parts where a thinned bend line allows tighter folds without cracking.
  - `direction: BendDirection` — `.auto` (default), `.concave`, or `.convex` for explicit override.

- **The legacy `Bend(from:to:radius:)` initializer is unchanged.** All v0.151–v0.153 callers continue to work without modification.

The 93-face inside-corner-reinforcing-bracket from #89 (Z-section with both same-direction and convex bends) now builds cleanly. Test fixtures from the issue: symmetric Z, offset L with very short web, channel-with-flange, all pass.

Bridge: one new symbol `OCCTWireCreateArcThroughPoints(s, m, e)` for 3-point arc-wire construction (avoids the `gp_Ax2` X-direction ambiguity of the angle-based arc API). Exposed as `Wire.arc(start:midpoint:end:)`.

### v0.154.0 (Apr 2026) — `Face(_:Shape)` and `Edge(_:Shape)` convenience initializers

Two tiny additive bridge symbols and their Swift conveniences. Recovers a typed `Face` or `Edge` from a generic `Shape` that wraps a `TopoDS_Face` / `TopoDS_Edge` (returns nil on type mismatch). Useful when a method gives back a `Shape` (e.g. `subShapes(ofType: .face)`) and you want the typed wrapper to call methods like `area()`, `outerWire`, `length`, etc., directly.

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
let faceShapes = box.subShapes(ofType: .face)
if let face = Face(faceShapes[0]) {
    print(face.area())   // 100
}
```

Bridge: `OCCTFaceFromShape(OCCTShapeRef) -> OCCTFaceRef?` and `OCCTEdgeFromShape(OCCTShapeRef) -> OCCTEdgeRef?`. Both return NULL when the shape's `ShapeType()` doesn't match. Unblocks the upcoming `UnfoldEngine` package, which builds on these.

### v0.153.0 (Apr 2026) — `SheetMetal.Builder` step-aware bends (issue #86)

The v0.151 `SheetMetal.Builder` implementation extruded each flange at its full profile, fused them, then filleted the seam edge. That works when both flanges have matching extents along the seam direction, but fails on **stepped seams** — flanges that meet along less than their full extent (a narrow tab on a wider base, a U-channel with sides narrower than the spine). OCCT can't cleanly fillet an edge that terminates at a free-face boundary, so the v0.151 builder reported `BuildError.filletFailed` and the downstream `OCCTDesignLoop` pipeline padded the narrower flange to match — both expensive and incorrect.

v0.153 lifts that limitation:

- `SheetMetal.Builder.build(flanges:bends:)` now computes the seam intersection between each pair of flanges in a bend and **splits the wider flange** at the intersection endpoints before extruding. The matched-extent middle piece carries the bend; the outer pieces stay flat. The fillet machinery from v0.151 runs unchanged on the matched-extent piece, where it's always well-formed.
- For matched-extent inputs (where v0.151 already worked), the result is identical: the splitting step is a no-op.
- Two new error cases: `BuildError.seamsDoNotOverlap(fromID:toID:)` if the two flanges' seam edges don't actually intersect along the seam line; `BuildError.nonRectangularStepFlange(id:)` if a flange would need to be split but its profile isn't axis-aligned-rectangular (rectangular profiles cover the issue's three test fixtures and the common cases; non-rectangular stepped seams are deferred).

The three reference fixtures from issue #86 all build cleanly:

- **L-bracket** with 80×40 base + 20×30 centred mounting tab.
- **Z-bracket** with 50×30 base + full-seam mid + 20×30 stepped top tab.
- **U-channel** with 100×40 spine + 80×15 stepped side flanges (narrower than the spine in the seam direction).

OCCTDesignLoop's `eval/describer_to_features.py` can drop its seam-padding workaround and emit actual described flange dimensions; the existing typed `SheetMetal.Flange` / `SheetMetal.Bend` API and the JSON envelope are unchanged.

The unrelated v0.151 limitation about the bend axis being on the *outside* corner (sharp inner corner, filleted outer corner) still applies — that's a different construction (real inside-radius + outside-radius bend) and is filed separately.

### v0.152.1 (Apr 2026) — `FeatureReconstructor.buildJSON` decodes `boolean` (issue #88)

`FeatureSpec.boolean` (with `op` ∈ `union | subtract | intersect`, `leftID`, `rightID`) has been wired through `applyBoolean` since the typed Swift API landed, and v0.152's `inputBody` makes it useful for cuts that reference the seeded body via `@input`. But the JSON decoder never picked it up — `FeatureEntry.init(from:)` had no `case "boolean":` branch, so JSON entries with `"kind": "boolean"` fell into the `default:` clause and were silently dropped.

- **Adds the `case "boolean":` decoder branch.** Reads `op` (string), `left`, `right`, optional `id`. Coding keys for these were already declared.
- **Bad `op` rawValue surfaces as a recordable skip** with reason `unsupported("boolean(op:smush)")` rather than throwing — matches the rest of the reconstructor's "graceful degradation" policy.
- **Unknown `kind` strings now also surface as `Skipped` entries** when the JSON entry carries an `id`. Reason: `unsupported("unknown JSON kind: …")`. Stage: `additive`. Without this, typos in `kind` and version-drift schemas were silently swallowed; now they're visible. Entries without an id continue to be silently ignored, matching the rest of `FeatureReconstructor` (the kernel only records skips when there's an id to attach them to).

Together these mean the `inputBody → boolean(@input, slot)` chain that v0.152 implies should work, actually does work end-to-end from JSON.

### v0.152.0 (Apr 2026) — `FeatureReconstructor.inputBody` for chained composition (issue #87)

`FeatureReconstructor.build(from:)` previously always started from an empty `BuildContext.current`, with the in-progress shape grown purely from additive feature entries. That blocks **chaining** — composing a body via one kernel API (e.g. `SheetMetal.Builder` from v0.151) and then cutting / finishing into it via the reconstructor. v0.152 makes the kernel itself accept a starting body.

- **Optional `inputBody` parameter on both build entry points:** `FeatureReconstructor.build(from: specs, inputBody: Shape? = nil)` and `FeatureReconstructor.buildJSON(_:inputBody:)`. When non-nil, `BuildContext.current` is seeded with the input and the input is registered in `namedShapes` under the sentinel id `@input`. When nil, behaviour is byte-for-byte identical to v0.151.
- **`FeatureReconstructor.inputBodySentinel`** — the literal string `@input`, exposed as a public constant so JSON envelopes and Swift callers share one source of truth. Boolean `leftID` / `rightID`, `Fillet.edgeSelector.onFeature`, and `Chamfer.edgeSelector.onFeature` all resolve `@input` via the standard `namedShapes` lookup — no separate code path. Last-write-wins semantics: a feature with `id == "@input"` shadows the seed, which is the obvious behaviour.
- **No JSON schema change.** Downstream callers using `buildJSON` pass `inputBody:` from Swift; the JSON envelope itself is unchanged. Within the envelope, references to `@input` are just regular id strings.
- **Stage ordering preserved.** Additive features still union onto whatever `current` is at the start of stage 1 (input or empty). Subtractive / finishing / annotation stages run with the same dispatch as v0.151. The existing `Skipped` reporting (under-determined / OCCT failure / unresolved-ref / unsupported) is unchanged.

The immediate driver is the sheet-metal → reconstructor chain referenced by [OCCTSwiftScripts#13](https://github.com/gsdali/OCCTSwiftScripts/issues/13): build a bent bracket via `SheetMetal.Builder`, then drill mounting holes into it with the reconstructor's hole-placement and `Skipped` machinery. The verb-side wiring downstream is one line — `FeatureReconstructor.buildJSON(envelope, inputBody: try GraphIO.loadBREP(at: path))`.

This is also the primitive the planned `Skipped` resume-from-last-good-shape behaviour will need: "given a partially-built shape, continue applying remaining specs" reduces to an `inputBody`-aware build.

**Out of scope:** multi-body input lists (use `Shape.compound` upstream), round-tripping face / edge tags from prior history (gone after BREP serialisation), reverse decomposition (`Shape → [FeatureSpec]`).

### v0.151.0 (Apr 2026) — Sheet-metal composition API (issue #85)

OCCT has no sheet-metal bend primitive and is not expected to grow one — CATIA / SolidWorks / FreeCAD all compose bends from extrude + union + fillet. v0.151 adds the canonical Swift-level composition so downstream consumers (OCCTDesignLoop's VLM reconstructor, scripts, MCP tooling) do not each reinvent it.

- **`SheetMetal.Flange`** — a closed 2D profile positioned in world space by explicit `(origin, uAxis, vAxis, normal)`. All three axes are independent so left-handed world placements (e.g. a flange normal along +Y with the profile reading +X / +Z) are expressible without handedness surprises. `vAxis` defaults to `cross(normal, uAxis)` when omitted.
- **`SheetMetal.Bend`** — names two flanges + an inside radius. No geometric data; the builder resolves the seam edge from the flange placements.
- **`SheetMetal.Builder.build(flanges:bends:)`** — extrudes each flange along its normal by `thickness`, fuses the bodies in order, then for each bend finds the seam edge(s) and applies `Shape.filleted(edges:radius:)`. Seam finding walks the fused shape's edges, keeps only those parallel to `cross(nA, nB)`, and selects the one whose midpoint lies on each flange's face that points *toward* the other flange — which uniquely identifies the bend and rejects the coincidental convex back corner.
- **`SheetMetal.BuildError`** — named cases for invalid thickness, empty flange list, duplicate/unknown IDs, invalid profile, extrusion/union/fillet failures, parallel flanges (no seam direction), and missing seam edge. `CustomStringConvertible` for direct logging.

**Known limitation:** stepped seams (flanges meeting along less than their full seam-direction extent, e.g. a narrow upright on a wider base) surface as `BuildError.filletFailed`. OCCT cannot cleanly round an edge that terminates at a free-face boundary; downstream callers should match flange widths along the seam or split the wider flange. Reverse-direction unwrap (bent BRep → flat cutting pattern) is the planned next addition to this namespace.

### v0.150.0 (Apr 2026) — Pure-Swift PDF + SVG export + BOM + balloons

Second half of the v0.149 → v0.150 drawing-automation arc. Drawings now have three readable output formats (DXF for engineering tools, PDF for humans, SVG for the web) plus the assembly-drawing primitives that make BOM-driven output a one-call operation.

- **`PDFWriter` + `Exporter.writePDF(drawing:to:pageSize:)` / `writePDF(sheet:body:to:)`** — pure-Swift PDF 1.4 writer. No UIKit / AppKit / Core Graphics dependency; works on macOS, iOS, and Linux. Helvetica font, one page per file, content stream installs a mm→pts CTM so staged geometry stays in drawing units. Per-layer ISO 128-20 stroke weights (0.5 mm VISIBLE / OUTLINE, 0.25 mm HIDDEN / CENTER / DIMENSION / TEXT, 0.18 mm HATCH) with dashed / chain patterns on HIDDEN / CENTER. Circles rendered as four cubic Bézier segments; arcs split into ≤90° Bézier chunks.
- **`SVGWriter` + `Exporter.writeSVG(drawing:to:)` / `writeSVG(sheet:body:to:)`** — pure-Swift SVG 1.1 writer. One `<g>` group per layer with stroke / stroke-width / stroke-dasharray attributes. Arcs emitted as native SVG `<path d="M… A …"/>`. ViewBox explicit or computed from content bounds. Drawing's mathematical Y (up) mapped to SVG's screen Y (down) via a group-level `scale(1,-1)`; each `<text>` carries its own counter-transform so glyphs read right-side up.
- **`DrawingAnnotation.balloon(Balloon)`** — new case carrying `itemNumber` + `centre` + `radius` + optional `leaderTo`. Rendered in every writer (DXF / PDF / SVG) as a circle + number text + optional leader line that exits the circle at the point nearest the target. `Drawing.addBalloon(itemNumber:at:leaderTo:radius:id:)` is the convenience entry point.
- **`BillOfMaterials`** — pure-Swift `Codable` value type. Seven-column table (ITEM / PART NO / DESCRIPTION / QTY / MAT / MASS / NOTES) with per-column default widths; caller populates `[Item]` and calls `render(into: DXFWriter, at:)`. Origin is the **bottom-right** anchor so the table grows up and to the left (idiomatic placement above a title block). `Sheet.renderBOM(_:into:at:)` convenience places the BOM right-aligned to the inner frame's top edge.
- **`DrawingDispatch.swift`** — shared internal annotation + dimension dispatcher used by `PDFWriter` and `SVGWriter`. `DrawingPrimitiveOps` struct bundles the five drawing primitives (addLine / addPolyline / addCircle / addArc / addText) as closures; a single dispatch path handles every `DrawingAnnotation` case (centreline, centermark, textLabel, hatch, cuttingPlaneLine, balloon) and every `DrawingDimension` case including tolerance rendering. `DXFWriter` continues to use its own inline logic — not because it couldn't be ported, but to keep its test coverage load-bearing and avoid regression risk.
- **`Exporter.pdfA3Landscape` / `pdfA4Landscape`** — named pts-space page-size constants. Also `PDFWriter.addDimension(_:)` / `SVGWriter.addDimension(_:)` mirror the DXF-side method added in v0.149 for ad-hoc dimension staging without a `Drawing`.

After v0.150, the only substantive drawing-layer gap is native DXF `DIMENSION` entities (still exploded LINE+TEXT), which remains demand-gated.

### v0.149.0 (Apr 2026) — Sheet automation + tolerance + ordinate dimensioning

First of a two-release arc closing the last substantive drawing-automation gaps: one-call multi-view layout, typed tolerance data on every dimension, and ISO 129-1 §9.3 ordinate dimensioning.

- **`Sheet.standardLayout(of:scale:margin:includeIso:)`** — composes front / top / side / optional isometric views of a `Shape` onto the sheet's inner frame as a 2x2 grid. Arrangement follows the sheet's `ProjectionAngle`: first-angle places top below front, third-angle places top above. Uniform scale is computed to fit the widest projected view; callers can pass a smaller `DrawingScale` to override. Returns a `StandardLayout` whose `PlacedView`s hold the original Drawings (attach dimensions per view before calling `render(into:)`).
- **`Drawing.addAutoDimensions(from:viewDirection:minRadius:dimensionOffset:bounds:)`** — heuristic dimensioner: adds a linear dimension for the projected X and Y extents of the shape's bounding box, plus a diameter dimension on every visible circular edge. Edge-on circles are skipped (mirrors the `addAutoCentermarks` detection); `minRadius` filters noise holes.
- **`DrawingTolerance`** — typed, `Codable` enum carried as `tolerance: DrawingTolerance` on every `DrawingDimension` payload (Linear, Radial, Diameter, Angular, Ordinate). Cases: `.none`, `.symmetric(Double)`, `.bilateral(plus:minus:)`, `.unilateral(Double)`, `.fitClass(String)`, `.limits(lower:upper:)`. Inline cases fold into the nominal label; multi-value cases render as stacked upper/lower TEXT in DXF at ~55% height, placed perpendicular to each dimension's text baseline.
- **`DrawingDimension.ordinate(Ordinate)`** — shared-origin X+Y dimensioning for CNC reference-datum workflows. Each feature carries its own position plus optional custom label; a single `tolerance` applies across all features. DXF emit draws a small origin cross, per-feature extension lines with ticks at the origin baseline, and offset labels perpendicular to each line. `Drawing.addOrdinateDimensions(origin:features:tolerance:id:)` is the convenience entry point. `DrawingDimension.Ordinate` + `Feature` are `Codable` for JSON-driven pipelines.
- **`DXFWriter.addDimension(_:)`** — public single-entity dispatch over every `DrawingDimension` case; useful for tests and for scripts that compose DXFs from dimension values without going through a `Drawing`.

### v0.148.0 (Apr 2026) — Drawing.append(_:) unified dispatcher

Small release closing #83 and #84 — both asked for the same thing: a public `Drawing.append(_:)` that dispatches every `DrawingAnnotation` case without the consumer-side switch blind spot.

- **`Drawing.append(_ annotation: DrawingAnnotation)`** — appends any `DrawingAnnotation` case (centreline, centermark, textLabel, hatch, cuttingPlaneLine). When new cases land, the dispatcher updates in one place, not in every consumer.
- **`Drawing.append(contentsOf: [DrawingAnnotation])`** — for factory output like `DrawingAnnotation.surfaceFinish(...)`, `.featureControlFrame(...)`, `.datumFeature(...)`, `.breakLine(...)`, `.cosmeticThreadSideView(...)` which all return arrays.
- **`Drawing.append(_ dimension: DrawingDimension)`** / `append(contentsOf: [DrawingDimension])` — symmetric for dimensions.

Downstream `replay(...)` helpers (OCCTSwiftScripts, OCCTSwiftPartsAgent) collapse to one-line `drawing.append(contentsOf: DrawingAnnotation.surfaceFinish(...))`. The existing `addCentreLine` / `addCentermark` / `addTextLabel` / `addHatch` / `addCuttingPlaneLine` typed factories continue to work unchanged; they're now a thin convenience over `append(_:)` conceptually (though the storage path is identical either way).

### v0.147.0 (Apr 2026) — Drawing + FeatureSpec consumer polish

Closes four small follow-up issues (#79, #80, #81, #82) that downstream consumers (OCCTSwiftScripts, OCCTDesignLoop, MCP tooling) asked for to remove boilerplate and unblock JSON-driven workflows.

- **#80 `Edge.curve3D`**: Direct `Edge → Curve3D` bridge. Ensures the 3D curve is built via `BRepLib::BuildCurves3d` for pcurve-only edges. Returns the raw `Geom_Curve` so consumers can call `curve.circleProperties` / `lineProperties` / etc. without DownCast gymnastics.
- **#79 `Drawing.addAutoCentermarks(from:viewDirection:extent:minRadius:bounds:)`**: symmetric to `addAutoCentrelines`. Walks circular edges, projects each centre into the view plane, adds `.centermark` annotations. Skips edges whose circle plane is parallel to the view (edge-on). `minRadius` filters small holes; `bounds` filters centermarks outside the view.
- **#81 `DrawingAnnotation.CuttingPlaneLine` + `Drawing.addCuttingPlaneLine`**: typed ISO 128-40 cutting-plane line. Computes trace in view 2D from cutting plane normal × view direction. DXFWriter renders heavy-chain ends, thin-chain middle, perpendicular arrows, and label letters at both ends.
- **#82 `FeatureSpec` Codable conformance**: `FeatureSpec` + all nested types (`Revolve`, `Extrude`, `Hole`, `Thread`, `EdgeSelector`, `Fillet`, `Chamfer`, `Boolean`) now `Codable`. Unblocks `FeatureReconstructor.buildJSON` + Python / MCP driven reconstruction pipelines without each consumer mirroring the types in their own schema.

### v0.146.0 (Apr 2026) — ISO drawings III: cosmetic threads, surface finish, GD&T symbols, detail views

Closes the ISO drawings arc (#78). Final release ships cosmetic threads (#77), ISO 1302 surface finish, ISO 1101 GD&T symbols, and compressed-view conventions (detail + break lines).

- **#77 `DrawingAnnotation.cosmeticThreadSideView` / `cosmeticThreadEndView`**: ISO 6410 cosmetic thread representation. Side view: two parallel lines at minor diameter spanning the thread length, optional callout text. End view: 3/4 broken arc set (0–90° / 90–180° / 180–315° with a 45° gap). `Drawing.addCosmeticThreadSide(...)` and `DXFWriter.addCosmeticThreadEndView(...)` convenience wrappers.
- **ISO 1302 surface finish**: `SurfaceFinishSymbol` enum (`.any` / `.machiningRequired` / `.machiningProhibited`). `DrawingAnnotation.surfaceFinish(at:leaderTo:ra:symbol:method:)` produces the check-mark geometry with Ra value label, horizontal bar for machiningRequired, optional production-method text, and leader line to the target feature.
- **ISO 1101 GD&T symbols**: `GDTSymbol` enum covering all 15 ASME/ISO geometric characteristics (straightness, flatness, circularity, cylindricity, profile of line/surface, perpendicularity, parallelism, angularity, position, concentricity, symmetry, coaxiality, circular runout, total runout). `DrawingAnnotation.featureControlFrame(at:symbol:tolerance:datums:leaderTo:)` emits the classic `[⌖] [0.1] [A] [B] [C]` rectangular frame. `DrawingAnnotation.datumFeature(label:at:pointingTo:)` emits the boxed letter + triangle pointer.
- **Detail views**: `Drawing.detailView(at:scale:)` returns a `TransformedDrawing` suitable for placing a scaled-up region of the parent drawing at a specific sheet location.
- **Break lines**: `DrawingAnnotation.breakLine(from:to:amplitude:)` emits ISO 128-30 compressed-length zigzag marker as 5 line segments.

### v0.145.0 (Apr 2026) — ISO drawings II: sheet templates, title blocks, projection symbols

Second release in the ISO drawings arc (#78). Closes #76 — adds ISO 5457 trimmed-sheet templates, ISO 7200 title blocks, and ISO 5456-2 projection symbols as first-class OCCTSwift API.

- **`PaperSize`**: `A0` / `A1` / `A2` / `A3` / `A4` with `.size(in: .landscape)` / `.portrait` returning ISO 5457 trimmed dimensions in mm.
- **`Orientation`**: `.landscape` / `.portrait`.
- **`ProjectionAngle`**: `.first` (ISO / Europe) / `.third` (ANSI / USA).
- **`TitleBlock`**: ISO 7200 mandatory + optional fields (title, drawingNumber, owner, creator, approver, documentType, dateOfIssue, revision, sheetNumber, language, material, weight, scale).
- **`Sheet`**: ties PaperSize + Orientation + ProjectionAngle + TitleBlock together. `render(into: DXFWriter)` emits border + ISO 5457 inner frame with correct margins (20 mm binding left, 10 mm other edges on A0–A3), centring marks at edge midpoints, and the title block in the bottom-right. `innerFrame` property exposes the drawable rectangle for layout.
- **`ProjectionSymbol`**: `ProjectionSymbol.render(.first, at:, into:)` emits the ISO 5456-2 truncated-cone + circle pair at the correct relative position for first / third angle.
- DXFWriter gets two new layers: `BORDER` and `TITLE`.

### v0.144.0 (Apr 2026) — ISO drawings I: section views, hatch, multi-view, style foundations

First of a three-release ISO-drawings arc (tracked in #78). Closes #73, #74, #75 and adds the ISO 128-20 / 3098 / 5455 style primitives every downstream sheet producer needs.

- **#75 `Drawing.transformed(translate:scale:)` + `Drawing.bounds`**: new `TransformedDrawing` wrapper and `DXFWriter.collectFromDrawing(_ transformed:)` overload. `Drawing.bounds(deflection:includeAnnotations:)` returns the drawing's 2D axis-aligned bounding box. Unblocks multi-view sheet composition: `writer.collectFromDrawing(view.transformed(translate: offset, scale: 0.5))`.
- **#73 `Shape.section2D(planeOrigin:planeNormal:planeU:deflection:)`** + `Shape.section2DView(...)`: slice a shape with a plane, return a `Drawing` in the plane's own 2D frame (not world space). `section2DView` wraps the contour with automatic ISO 128-40 hatching at 45° and an optional "A-A" label.
- **#74 `Drawing.addHatch(boundary:angle:spacing:islands:)`**: ISO 128-50 sectional-view fill. DXFWriter tessellates into line segments at the specified angle and spacing with island (hole) subtraction via even-odd rule scanlines. Adds `HATCH` + `SECTION` XCAF layers.
- **G1 ISO 128-20 line widths + ISO 128-21 arrows + ISO 3098 text heights**: `DrawingLineWidth` enum (w013 → w200, ISO 1:1.4 series), `DrawingTextHeight` enum (h25 → h200) with `.recommended(forPaper:)` and `.snap(_:)`, `DrawingArrowStyle` (filledClosed / openClosed90 / openClosed30 / tick), `DrawingLineStyle.defaultWidth` / `.boldWidth` per style.
- **G2 ISO 5455 `DrawingScale`**: enum cases `.one` / `.reduction(Int)` / `.enlargement(Int)` / `.custom(Double)` with `.factor` and `.label` accessors. `DrawingScale.preferred` returns the ISO-standard scale series (50:1 down to 1:1000).

### v0.143.0 (Apr 2026) — Measurement ergonomics + clearing v0.142 deferrals

Small-but-broad release that sands the measurement papercuts surfaced by the v0.143 audit and retires every deferral the v0.142 release notes flagged. Roughly 40 ops: 4 measurement additions, 5 deferral clearings.

**Measurement ergonomics (M1–M4):**

- **`Shape.volume` / `Shape.surfaceArea`** — verified already wrapped as optional properties (audit had missed them); no new code, just confirmation.
- **`Curve3D.distance(to: SIMD3)` / `Edge.distance(to: SIMD3)`** — one-liner point-to-curve distance when you don't need the projected point / parameter.
- **Angle helpers**: `Edge.angle(to:)`, `Edge.isParallel(to:tolerance:)`, `Edge.isPerpendicular(to:tolerance:)`, `Face.angle(to:)`, `Face.isParallel(to:)`, `Face.isPerpendicular(to:)`, `Face.isCoplanar(with:tolerance:)`. Plus `ConstructionAxis.angle(to:in:)`, `ConstructionPlane.angle(to:in:)`. `unsignedAngle(between:and:)` free function for SIMD3 pairs.
- **Circle / revolution property extraction**: `Edge.circleProperties` returns `(center, radius, axis, isFullCircle, startAngle, endAngle)?` for circular edges (three-point circle fit). `Face.revolutionProperties` returns `(axis, radius)?` for cylindrical / conical / spherical / toroidal / surface-of-revolution faces.

**Deferral clearings (from v0.142 release notes):**

- **Constructionspeak persistence (D1)**: `Document.addConstructionShape(_:)` tags a shape with the `CONSTRUCTION` XCAF layer; `Document.constructionShapeLabels` enumerates on reload. `ConstructionContext.materialize(in:graph:options:)` resolves every plane/axis/point recipe and creates a finite representative shape (rectangular face for planes, bounded edge for axes, vertex for points) on the layer. STEP export preserves layer tags; import produces layer-marked shapes but not the typed recipes. Matches FreeCAD's long-standing ceiling.
- **Arc / circle tessellation in `Sketch.buildProfile` (D2)**: `SketchElement.CurveKind.tessellate2D(segmentsPerRadian:)` for all four curve kinds (line / polyline / arc / circle). `Sketch.buildProfile` now lifts tessellated samples through the host plane's frame. D-shaped and circular profiles now produce wires.
- **Named-shape registry for `FeatureSpec.Boolean` (D3)**: Each feature with a non-nil `id` registers its produced shape in an internal dict; `Boolean.leftID` / `rightID` look up by id. `.union` / `.subtract` / `.intersect` all supported. Missing-id cases report `.unresolvedRef`.
- **Multi-leaf `.createdBy` disambiguation (D4)**: new `leafOccurrence: Int? = 0` parameter on `TopologyRef.createdBy` — pick the Nth leaf when a creation has split into multiple live descendants. `TopologyGraph.currentForms(of:)` returns all leaves. `leafOccurrence: nil` disables forward-walk.
- **FeatureReconstructor ↔ TopologyGraph coupling for `EdgeSelector` (D5)**: `.nearPoint(point, tolerance)` resolves edges by midpoint-distance within the target shape. `.onFeature(featureID)` looks up the source feature's shape via the named-shape registry and heuristically matches target edges whose midpoints coincide with the source's edges. `.all` for uniform fillet/chamfer still works. (v1 heuristic; full graph-history dispatch remains available if consumers need per-op edge identity.)

Scope cuts: chamfer per-edge selector still requires a per-edge distance array the bridge doesn't yet expose — falls through to `.unsupported` for `.nearPoint` / `.onFeature` on chamfer specifically. Uniform chamfer (`.all`) works. Flagged as a v0.144 candidate.

### v0.142.0 (Apr 2026) — Construction geometry, sketches, FeatureReconstructor

Second release in the v0.141 → v0.143 arc — ships Phases 2–6 from #72 plus #62 in one go. With this release, OCCTSwift has the full construction-geometry vocabulary that agentic modelling needs: recipe-based references (v0.141) → typed construction entities → document context → sketches → declarative feature reconstruction.

- **`ConstructionPlane` / `ConstructionAxis` / `ConstructionPoint`** (#72 Phase 2): Fusion-style recipe enums carrying `TopologyRef`s. 7 plane variants (absolute, offsetFromFace, throughAxis, tangentToFace, midPlane, byThreePoints, normalToEdge), 5 axis variants (absolute, alongEdge, normalToFace, throughPoints, intersectionOfPlanes), 6 point variants (absolute, atVertex, midpointOfEdge, centroidOfFace, atEdgeParameter, intersectionOfAxisAndPlane). Resolvers compute `Placement` / `(origin, direction)` / `SIMD3<Double>` against a `TopologyGraph`. Typed `ConstructionResolutionError`.
- **`TopologyRef.containedIn` now resolves** (#72 Phase 2 unblock): new `OCCTBRepGraphChildIndices` bridge + `TopologyGraph.childIndices(rootKind:rootIndex:targetKind:)` Swift wrapper.
- **`ConstructionContext`** (#72 Phase 3): Document-level collection with typed opaque IDs (`PlaneID` / `AxisID` / `PointID`), named entities, per-entity resolution against a graph, and `allBroken(in:)` diagnostic returning every entity that fails to resolve. `Document.constructionContext` is a lazy per-document property.
- **`Sketch` + `SketchElement`** (#72 Phase 4): `Sketch` is hosted on a `ConstructionPlane` ID, carries an array of `SketchElement`s with per-element `isConstruction` flag. `buildProfile(in:graph:)` is the **single filter site** (FreeCAD-inspired) — construction elements are excluded when assembling the profile wire. Elements: `.line`, `.polyline`, `.arc`, `.circle` (arcs/circles tessellation comes later).
- **`FeatureReconstructor`** (#62): Declarative `FeatureSpec` tagged union (revolve / extrude / hole / thread / fillet / chamfer / boolean). `FeatureReconstructor.build(from:)` with staged additive → subtractive → finishing → annotation dispatch. `EdgeSelector` enum with `.all`, `.nearPoint`, `.onFeature` — `.onFeature` currently reports `.unsupported` pending full TopologyGraph-integrated dispatcher; `.all` works today for uniform fillet/chamfer. `FeatureReconstructor.buildJSON(_:)` front end parses the OCCTDesignLoop-compatible schema.
- **`Placement`** shared value type (origin + orthonormal basis) with ergonomic `init(origin:normal:)` that picks deterministic x/y axes.

Scope of what the v1 implementation deliberately does **not** do (deferred to later iterations as concrete consumers surface):
- Constraint solving in `Sketch` — explicit non-goal (see #72).
- Named-shape registry for `FeatureSpec.Boolean` with id-based left/right selection.
- `.onFeature` / `.nearPoint` edge resolution in fillet/chamfer dispatch — requires coupling `FeatureReconstructor` to a live `TopologyGraph`, which is the natural next iteration once agents drive it.
- XCAF `CONSTRUCTION` layer persistence — recipes live in-memory; STEP round-trip drops them (matches FreeCAD's 20-year limitation documented in #72).
- Multi-leaf `.createdBy` disambiguation when a single creation splits into many live descendants.

### v0.141.0 (Apr 2026) — Construction-geometry foundation: BRepGraph history readback + TopologyRef

First release in the v0.141 → v0.143 "Construction Geometry" arc (tracked in #72). Builds the substrate for recipe-based topology references that survive mutations — the prerequisite for agent-driven CAD where construction planes / axes / points stay attached to model features through edits.

- **BRepGraph history record readback (#72 Phase 0)**: Exposes the old→new node mappings that the OCCT kernel was already recording. `TopologyGraph.historyRecord(at:)`, `.historyRecords`, `.findOriginal(of:)`, `.findDerived(of:)`, `.recordHistory(operationName:original:replacements:)`. New `TopologyGraph.NodeRef` value type (kind + index) and `HistoryRecord` with full mapping.
- **`TopologyRef` recipe type (#72 Phase 1)**: Indirect enum expressing topology references as *recipes evaluated against the current graph*, not as indices (Onshape FeatureScript-inspired). Cases: `.literal(NodeRef)`, `.createdBy(operationName:kind:occurrence:)`, `.containedIn(parent:kind:occurrence:)`, `.splitOf(original:occurrence:)`. Typed `TopologyResolutionError` enum for failure modes.
- **`TopologyGraph.resolve(_:)`**: Evaluates recipes by walking history records, returns `Result<NodeRef, TopologyResolutionError>`. `.createdBy` picks up newly-introduced replacements by operation name and walks forward to the current form; `.splitOf` picks the Nth replacement of a split original; ancestor-resolution failures surface as `.ancestorMissing`.

Scope: `.containedIn` returns `.noCurrentDescendant` until Phase 2 adds child-at-index accessors. `.createdBy` current-form walk picks the first leaf in deterministic order; multi-leaf disambiguation (useful when a single creation splits into many live descendants) comes in later phases.

### v0.140.0 (Apr 2026) — GD&T write path + typed dimension/tolerance enums

Completes the read-only GD&T support shipped in v0.21.0 with a write path. Downstream callers can now author `XCAFDoc_Dimension` / `XCAFDoc_GeomTolerance` / `XCAFDoc_Datum` attributes, attach them to shape labels, and round-trip through STEP AP242. Typed Swift enums replace the raw `Int32` type codes from v0.21.0 for the full list of XCAFDimTolObjects types.

- **Typed enums**: `Document.DimensionType` (all 32 `XCAFDimTolObjects_DimensionType` cases — Location_Linear, Size_Diameter, Size_Radius, toroidal variants, etc.) and `Document.GeomToleranceType` (all 16 — flatness, perpendicularity, position, profileOfLine, etc.).
- **Typed value types**: `Document.Dimension`, `Document.GeomTolerance`, `Document.Datum`. Accessors: `typedDimension(at:)`, `typedGeomTolerance(at:)`, `typedDatum(at:)`, `typedDimensions`, `typedGeomTolerances`, `typedDatums`.
- **Write path**: `Document.createDimension(on:type:value:lowerTolerance:upperTolerance:)`, `createGeomTolerance(on:type:value:)`, `createDatum(name:)`, `setDimensionTolerance(at:lower:upper:)`. Returns the new attribute's index or nil on failure.
- **Bridge additions**: `OCCTDocumentCreateDimension`, `OCCTDocumentCreateGeomTolerance`, `OCCTDocumentCreateDatum`, `OCCTDocumentSetDimensionTolerance`.

Scope: full modifier / qualifier / grade sequences (`XCAFDimTolObjects_DimensionModif`, `GeomToleranceModif`, `DatumSingleModif` etc.) remain partial wrapping — added on demand. This release covers the 90%-case authoring path.

### v0.139.0 (Apr 2026) — Thread Form v2 + cleanup

Replaces v0.138's circular-sweep thread placeholder with a real truncated V-profile following ISO-68 / UN conventions. Also folds in two quality-of-life cleanups (#68 boolean arg labels, #69 versioned MARK headers).

**Behaviour change**: callers of v0.138's `Shape.threadedHole` / `threadedShaft` will now receive geometry that actually looks like a thread in HLR reprojection (alternating diagonal edges at pitch spacing) rather than a helical groove. API signatures unchanged; new default parameters (`starts: 1`, `runout: .none`) preserve single-start no-runout behaviour.

- **Thread Form v2 (#66 follow-up)**: `ThreadCutterProfile` builds a truncated trapezoidal cross-section with 30° flanks (60° included), H/8 crest flat, H/4 root flat. Swept along a helical spine with `BRepOffsetAPI_MakePipeShell` (correctedFrenet mode) and boolean-cut against the target. New `crestFlat` / `rootFlat` / `minorDiameter` accessors on `ThreadSpec`. New `RunoutStyle` enum (`.none` / `.filleted(radius:)` / `.tapered(turns:)`). New `starts: Int` parameter on `threadedHole` / `threadedShaft` for multi-start threads.
- **Boolean op labels (#68)**: `Shape.union(_:)`, `Shape.intersection(_:)`, `Shape.section(_:)` now match `Shape.subtracting(_:)` — all unlabelled, consistent with `Set.union(_:)` / `Set.intersection(_:)`. Deprecated `with:`-labelled shims kept for backwards compatibility.
- **MARK header refactor (#69)**: 32 versioned grab-bag MARK headers (`// MARK: - v0.X.Y: A, B, C`) renamed to feature-first format (`// MARK: - A, B, C (v0.X.Y)`). Xcode jump-to-section and grep-for-feature now work; OCCTMCP's MARK-based API-reference generator can categorise without a regex fallback.

Tapered-runout law-based pipe-shell is tracked as a follow-up — the `.tapered` case falls back to `.filleted` until `BRepOffsetAPI_MakePipeShell::SetLaw` is wrapped.

### v0.138.0 (Apr 2026) — Engineering Drawings II: DXF export + thread features

Second release in the v0.137 → v0.139 arc. Closes #63 (DXF export) and #66 (ISO thread features). ~50 ops.

- **DXF 2D writer (#63)**: Custom pure-Swift DXF R12 ASCII writer (OCCT ships no DXF support — confirmed by audit). `Exporter.writeDXF(drawing:to:deflection:)` walks a `Drawing`'s visible / hidden / outline edges through `Shape.allEdgePolylines` and emits LINE / LWPOLYLINE / CIRCLE / ARC / TEXT entities. Layers: VISIBLE / HIDDEN / OUTLINE / CENTER / DIMENSION / TEXT, with appropriate linetypes (CONTINUOUS / DASHED / CHAIN). Dimensions from v0.137's `DrawingDimension` are emitted as exploded LINE+TEXT geometry (universally readable). `Exporter.writeDXF(shape:to:viewDirection:)` convenience combines projection and write. Public `DXFWriter` for callers composing DXF manually.
- **Thread features (#66)**: `ThreadForm` enum (iso68 / unified); `ThreadSpec` struct with `parse("M5x0.8")`, `parse("1/4-20 UNC")`, metric-coarse-pitch table, theoretical and cut depth accessors, minor-diameter computation. `Shape.threadedHole(axisOrigin:axisDirection:spec:depth:)` and `Shape.threadedShaft(axisOrigin:axisDirection:spec:length:)` produce helical cut / boss geometry via `BRepOffsetAPI_MakePipeShell` sweep of a circular profile. Integrates with #62's `FeatureReconstructor` — `FeatureSpec.Thread` can now route through real geometry instead of annotation-only.

Scope decisions: v1 threads use a circular sweep cross-section rather than full 60° flank triangle — produces correct handedness, pitch, diameter, and depth for reprojection diff and visualisation; manufacturing-accurate flanks land in a follow-up release. Multi-start threads, ACME / BSP / NPT forms, and full BRepOffsetAPI_MakePipeShell option wrapping (SetForceApproxC1, multi-profile Add()) deferred. GLTF Shape-level export, PLY import, STEP/IGES option completeness dropped from v0.138 — Document-level GLTF already ships, and the remaining gaps are low priority vs. closed-loop pipeline needs.

### v0.137.0 (Apr 2026) — Engineering Drawings I: axes, dimensions, centrelines

Keystone release for the v0.137 → v0.139 "Engineering Drawings" series (tracked in #67). Adds axis extraction from shapes (#65), a pure-Swift value-type dimensioning API on `Drawing` (#64), and auto-centreline generation bridging the two. ~60 ops.

- **Axis extraction (#65)**: `Face.primaryAxis`, `Shape.revolutionAxes(tolerance:)`, `Shape.symmetryAxes(fractionalTolerance:)`, `Surface.torusAxis`, `Surface.revolutionAxis`. New `ShapeAxis` value type with `.cylinder`/`.cone`/`.sphere`/`.torus`/`.revolution`/`.extrusion`/`.symmetry` kinds. Bridge: `OCCTSurfaceTorusAxis`, `OCCTSurfaceRevolutionAxis`, `OCCTSurfaceRevolutionLocation`, `OCCTFaceGetPrimaryAxis`, `OCCTShapeRevolutionAxes`, `OCCTShapeSymmetryAxes`.
- **Surface introspection completeness**: typed `Surface.SurfaceType` + `Surface.surfaceKind`; `Surface.Continuity` + `Surface.continuityClass`; type-predicate conveniences `isPlane` / `isCylinder` / `isCone` / `isSphere` / `isTorus` / `isBezier` / `isBSpline` / `isSurfaceOfRevolution` / `isSurfaceOfExtrusion` / `isOffsetSurface`.
- **Drawing dimensioning API (#64)**: `DrawingDimension` tagged union (linear / radial / diameter / angular) + `DrawingAnnotation` tagged union (centreline / centremark / text label). `DrawingLineStyle` enum. Methods on `Drawing`: `addLinearDimension`, `addRadialDimension`, `addDiameterDimension`, `addAngularDimension`, `addCentreLine`, `addCentermark`, `addTextLabel`, `clearAnnotations`, plus `dimensions` / `annotations` accessors. Pure-Swift value types — XDE round-trip deferred to v0.139 (#67).
- **Auto-centreline generation (#64 ↔ #65)**: `Drawing.addAutoCentrelines(from:viewDirection:overshoot:tolerance:bounds:)` projects a shape's revolution axes into the drawing's view plane and emits chain-pattern centrelines; axes parallel to the view direction are returned in `.skipped`.

Scope decisions (see #67 for rationale): Full PrsDim display-dimension completeness (MaxRadius / MinRadius / Chamf2d / Chamf3d) and PrsDim geometric-relation wrapping (Concentric / Parallel / etc.) were cut from v0.137 — they are AIS display objects with low marginal value compared to the Swift value-type API that drives the closed-loop drawing workflow.

### v0.132.0 - v0.136.0 (Apr 2026) — BRepGraph Topology Graph

Wraps OCCT's new BRepGraph API — graph-based B-Rep topology with cache-friendly traversal, O(1) upward navigation, and parallel geometry extraction. 163 operations across 5 releases.

- **v0.136.0**: ML-friendly graph export (COO adjacency, node features, JSON), UV-grid face sampling (positions/normals/curvatures), edge curve sampling — for GNN/UV-Net/BRepNet pipelines
- **v0.135.0**: Builder mutations — AddVertex/Shell/Solid, AddFaceToShell/ShellToSolid, AddCompound, RemoveNode/Subgraph, AppendShape, deferred invalidation, SplitEdge, ReplaceEdgeInWire
- **v0.134.0**: Product/Occurrence assembly queries, RefsView per-kind counts and entry access, edge start/end vertices, shell closure, compound hierarchy
- **v0.133.0**: Shape reconstruction from graph nodes, BRepGraph_Tool vertex/edge/face geometry access, CoEdge half-edge queries, history tracking, graph copy/transform, poly counts
- **v0.132.0**: Core graph — build from shape, topology/geometry counts, face adjacency, shared edges, edge boundary/manifold, child/parent explorers, validate, compact, deduplicate, stats

### v0.129.0 - v0.131.0 (Apr 2026) — RC5 New APIs

- **v0.131.0**: Approx_BSplineApproxInterp, GeomEval TBezier/AHTBezier curves+surfaces, GeomAdaptor_TransformedCurve
- **v0.130.0**: GeomEval analytical curves (helix, sine wave), analytical surfaces (ellipsoid, hyperboloid, paraboloid, helicoid), Geom2dEval spirals, GeomFill_Gordon, PointSetLib, ExtremaPC
- **v0.129.0**: IGES mutex serialization (thread safety fix per OCCT #1179)

### v0.120.0 - v0.128.0 (Apr 2026) — Completion & Polish

Final method-level coverage of all user-facing OCCT classes.

- **v0.128.0**: v0.128.0 release (3333 ops total)
- **v0.125.0**: BSplineSurface deep (20), Geom2d_BSpline (20), BezierCurve (8), BezierSurface (12)
- **v0.124.0**: ChamferBuilder (20), FilletBuilder (16), WireAnalyzer (18)
- **v0.123.0**: ThruSections/CellsBuilder/PipeShell/UnifySameDomain/Section extensions
- **v0.122.0**: WireFixer, ShapeFix_Edge, BRepTools/BRepLib statics, History, Sewing extensions
- **v0.121.0**: GLTF import/export (xcframework rebuilt with RapidJSON), FilletBuilder, ChamferBuilder
- **v0.120.0**: IsCN, ReversedParameter, ParametricTransformation, gp extras, surface reversed copies

### v0.110.0 - v0.119.0 (Mar-Apr 2026) — Constraint Solvers & Serialization

- **v0.119.0**: BREP serialization, gp_Pln/gp_Lin distance/contains, BezierSurface queries
- **v0.118.0**: BRepBndLib, ShapeAnalysis tolerance, BRepAlgoAPI_Check/Defeaturing
- **v0.116.0**: Helix construction, gp_Ax3/GTrsf2d/Mat2d, quaternion interpolation
- **v0.115.0**: Interpolation expansion, ThruSections builder, Triangulation queries
- **v0.114.0**: TopoDS_Builder, ShapeContents, FreeBoundsProperties, WireBuilder
- **v0.113.0**: MakeEdge completions, multi-result projections, DistShapeShape full results
- **v0.112.0**: RWMesh iterators, Intf_Tool, BRepAlgo_AsDes, BiTgte, wire/shell construction
- **v0.111.0**: PSO, GlobOptMin, FunctionRoots, GaussIntegration, BRepLProp
- **v0.110.0**: Constraint solver infrastructure — C callback adapters for OCCT math solvers

### v0.100.0 - v0.109.0 (Mar 2026) — Geometry Factories & Extrema

- **v0.109.0**: Extrema elementary distances, TrigRoots, IntAna2d, BRepAlgo_NormalProjection
- **v0.108.0**: Complete Geom_ and Geom2d_ method coverage — all conic/surface property methods
- **v0.107.0**: BSpline manipulation (3D/2D/surface), Bezier methods, BRepTools, Sewing, Hatch
- **v0.106.0**: GC surface factories, ShapeAnalysis_Wire/Edge, BRepLib_MakeEdge2d
- **v0.105.0**: GC/GCE2d geometry factories, GCPnts uniform sampling, CompCurveToBSpline (90 ops)
- **v0.104.0**: BndLib analytic bounding, OSD_Host/PerfMeter, IntAna_IntQuadQuad
- **v0.103.0**: gce transform factories, GProp element properties, Plate constraints
- **v0.102.0**: TopExp adjacency, Poly_Connect mesh adjacency, BRepOffset_Analyse
- **v0.101.0**: Geom_TrimmedCurve, BRepLib_FindSurface, ShapeAnalysis_Surface, Resource_Manager
- **v0.100.0**: RWStl I/O, ShapeAnalysis_Curve statics, BRepExtrema_SelfIntersection

### v0.90.0 - v0.99.0 (Mar 2026) — OCAF Extensions & Math

- **v0.99.0**: Convert_CompBezierCurves, Geom_OffsetSurface, OSD_File, ShapeFix_Wireframe
- **v0.98.0**: IntAna analytic intersections, OSD_Chronometer/Process, Draft_Modification
- **v0.97.0**: BRepAlgo_Loop, Bnd_BoundSortBox, BRepGProp_Domain, TNaming_Naming, Precision
- **v0.96.0**: XCAFDoc_AssemblyItemRef, BRepAlgo_Image, OSD_Path, BRepClass_FClassifier
- **v0.95.0**: Convert ellipse/hyperbola/parabola/cylinder/cone/torus to BSpline
- **v0.94.0**: math_Matrix/Gauss/SVD/PolynomialRoots/Jacobi, Convert circle/sphere to BSpline
- **v0.93.0**: OSD_MemInfo, ShapeFix_EdgeProjAux, Geom2dAPI_Interpolate, BRepAlgo_FaceRestrictor
- **v0.92.0**: Bnd_OBB, Bnd_Range, BRepClass3d point-in-solid, TDataXtd_Constraint
- **v0.91.0**: ElCLib curve evaluation, ElSLib surface evaluation, gp_Quaternion, OSD_Timer
- **v0.90.0**: TDF_ChildIDIterator, TDocStd_PathParser, TFunction_DriverTable, TNaming extensions

### v0.80.0 - v0.89.0 (Mar 2026) — Extrema, Color Science & OCAF Deep

- **v0.89.0**: TDF_Transaction/Delta, TDF_ComparisonTool, TDocStd_XLinkTool
- **v0.88.0**: TNaming extensions, TDataStd_IntPackedMap, TDataStd_NoteBook
- **v0.87.0**: TDataStd_Tick/Current, ShapeAnalysis_Shell, CanonicalRecognition
- **v0.86.0**: TDataStd extended attributes (BooleanArray, ByteArray, IntegerList, etc.)
- **v0.85.0**: UnitsAPI, BinTools binary I/O, Message_Messenger/Report
- **v0.84.0**: VrmlAPI_Writer, TDataStd_Directory/Variable, TDocStd_XLink
- **v0.83.0**: XCAFDoc attributes, Notes, ClippingPlaneTool, AssemblyGraph (97 ops)
- **v0.82.0**: Quantity_Period/Date, Font_FontMgr, Image_AlienPixMap (39 ops)
- **v0.81.0**: Quantity_Color, Quantity_ColorRGBA, Graphic3d materials (24 ops)
- **v0.80.0**: Extrema 3D/2D, GeomTools persistence, ProjLib, gce factories (35 ops)

### v0.70.0 - v0.79.0 (Mar 2026) — TKBool, TKFillet, TKHlr & Geometry Deep

- **v0.79.0**: Poly_CoherentTriangulation, BRepFill_Evolved, BRepExtrema_DistanceSS, GeomFill
- **v0.78.0**: BRepTools modifications, ShapeUpgrade_SplitSurface, GeomConvert, Poly_Polygon
- **v0.77.0**: GeomLib utilities, GccAna circle/line solvers, Approx_SameParameter
- **v0.76.0**: Geom_CartesianPoint, Geom_Direction, Axis1/2Placement, ShapeConstruct_Curve (41 ops)
- **v0.75.0**: BiTgte_Blend, GeomConvert_ApproxCurve/Surface, GCPnts, BRepGProp
- **v0.74.0**: TKMesh/TKOffset/TKPrim/TKShHealing/TKTopAlgo gap closure
- **v0.73.0**: Extended HLR edges, HLRAppli_ReflectLines, Intrv_Interval (29 ops)
- **v0.72.0**: LocOpe_Gluer, ChFi2d_Builder/ChamferAPI/FilletAPI, FilletSurf_Builder
- **v0.71.0**: IntTools_BeanFaceIntersector, BOPAlgo_WireSplitter, BRepFeat_SplitShape
- **v0.70.0**: IntTools EdgeEdge/EdgeFace/FaceFace, BOPAlgo BuilderFace/BuilderSolid

### v0.60.0 - v0.69.0 (Mar 2026) — Data Exchange & TKGeomAlgo

- **v0.69.0**: NLPlate G2/G3, Plate_Plate solver, GeomPlate, GeomFill Generator (20 ops)
- **v0.68.0**: TopTrans_CurveTransition, GeomFill trihedrons, GccAna_Circ2d3Tan (18 ops)
- **v0.67.0**: FairCurve, LocalAnalysis, TopTrans SurfaceTransition (8 ops)
- **v0.66.0**: Full TkG2d — Point2D, Transform2D, AxisPlacement2D, Vector2D (44 ops)
- **v0.65.0**: BOPAlgo RemoveFeatures/Section, ShapeBuild, ShapeExtend, ShapeUpgrade (24 ops)
- **v0.64.0**: ProjLib, BRepOffset_Offset, Adaptor3d_IsoCurve (9 ops)
- **v0.63.0**: GeomLProp, BRepOffset_SimpleOffset, GeomInt_IntSS, Contap_Contour (17 ops)
- **v0.62.0**: BRepLib topology, MakeEdge2d, ShapeCustom, LocOpe, CPnts (22 ops)
- **v0.61.0**: Approx, Contap, BOPAlgo, IntCurvesFace, BRepMesh, GeomPlate (19 ops)
- **v0.60.0**: XDE/XCAF Full Coverage (42 ops)

### v0.50.0 - v0.59.0 (Feb-Mar 2026) — OCAF & Data Exchange

- **v0.59.0**: IGES/OBJ/PLY Full Coverage (23 ops)
- **v0.58.0**: STEP Full Coverage (25 ops)
- **v0.57.0**: OCAF Persistence (17 ops)
- **v0.56.0**: TDataXtd + TFunction (29 ops)
- **v0.55.0**: TDataStd Attributes (25 ops)
- **v0.54.0**: TDF Core + TDocStd (31 ops)
- v0.50.0-v0.53.0: Various additions

### v0.38.0 - v0.49.0 (Feb 2026) — Audit & Gap Closure

Systematic OCCT test suite audit rounds (7 rounds total), closing gaps in primitives, sweeps, booleans, modifications, healing, measurement, and topology.

### v0.27.0 - v0.37.0 (Feb 2026) — RC4 Upgrade & Feature Expansion

- OCCT 8.0.0-rc3 → rc4 upgrade
- Feature-based modeling, pattern operations, shape editing
- Topological naming (TNaming), OCAF framework
- TDataStd/TDataXtd attributes, TFunction framework

### v0.16.0 - v0.26.0 (Feb 2026) — Parametric Geometry

- 2D/3D parametric curves (Geom2d, Geom) with Metal draw methods
- Parametric surfaces with curvature analysis
- Law functions for variable-section sweeps
- Medial axis transform
- Camera, selection, presentation mesh
- Color science, materials

### v0.6.0 - v0.15.0 (Jan 2026) — XDE & Annotations

- XDE document support (assembly, colors, materials, GD&T)
- Annotations (dimensions, text labels, point clouds)
- KD-tree spatial queries
- Polynomial solver, hatch patterns

### v0.1.0 - v0.5.0 (Dec 2025 - Jan 2026) — Foundation

- Basic primitives, booleans, transforms
- Wire creation, sweep operations
- Mesh generation, STL/STEP import/export
- Shape validation and healing
- STEP optimization
