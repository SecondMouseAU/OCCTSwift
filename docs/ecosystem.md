# OCCTSwift Ecosystem

OCCTSwift is the kernel of a layered family of Swift packages that wrap [OpenCASCADE Technology](https://www.opencascade.com/) for CAD on Apple platforms. Each package has a narrow, well-bounded role; you pick the ones you need.

This page exists so you don't have to guess which dep to add.

## Map

```
┌────────────────────────────────────────────────────────────────────────┐
│  Applications & tooling                                                │
│  ┌──────────────────────┐  ┌──────────────────────┐                    │
│  │ OCCTSwiftScripts     │  │ OCCTMCP              │                    │
│  │ (occtkit CLI +       │  │ (MCP server for AI   │                    │
│  │  ScriptHarness)      │  │  CAD modeling)       │                    │
│  └──────────┬───────────┘  └──────────┬───────────┘                    │
└─────────────┼─────────────────────────┼────────────────────────────────┘
              │                         │
┌─────────────┼─────────────────────────┼────────────────────────────────┐
│  Interactive viewport stack           │                                │
│  ┌──────────▼────────────┐            │                                │
│  │ OCCTSwiftAIS          │            │                                │
│  │ (selection, widgets,  │            │                                │
│  │  manipulators)        │            │                                │
│  └──────────┬────────────┘            │                                │
│             │                         │                                │
│  ┌──────────▼────────────┐            │                                │
│  │ OCCTSwiftTools        │            │                                │
│  │ (kernel ↔ viewport    │            │                                │
│  │  bridge layer)        │            │                                │
│  └──────────┬────────────┘            │                                │
│             │                         │                                │
│  ┌──────────▼────────────┐            │                                │
│  │ OCCTSwiftViewport     │            │                                │
│  │ (Metal 3D viewport)   │            │                                │
│  └──────────┬────────────┘            │                                │
└─────────────┼─────────────────────────┼────────────────────────────────┘
              │                         │
┌─────────────┼─────────────────────────┼────────────────────────────────┐
│  Headless / batch                     │                                │
│  ┌──────────┴───────┐  ┌──────────────┴─────┐  ┌────────────────────┐  │
│  │ OCCTSwiftIO      │  │ OCCTSwiftMesh      │  │ ... your code ...  │  │
│  │ (STEP / IGES /   │  │ (decimation,       │  │                    │  │
│  │  STL / glTF /    │  │  smoothing,        │  │                    │  │
│  │  OBJ / BREP I/O) │  │  repair)           │  │                    │  │
│  └──────────┬───────┘  └──────────┬─────────┘  └─────────┬──────────┘  │
│             │                     │                      │             │
└─────────────┼─────────────────────┼──────────────────────┼─────────────┘
              │                     │                      │
┌─────────────▼─────────────────────▼──────────────────────▼─────────────┐
│  Kernel                                                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ OCCTSwift                                                       │   │
│  │ Swift wrapper for OCCT — shapes, curves, surfaces, OCAF,        │   │
│  │ TopologyGraph, drawing/projection, ML-friendly samplers.        │   │
│  │ Bundles a pre-built OCCT 8.0.0 GA xcframework (arm64,           │   │
│  │ macOS / iOS / visionOS / tvOS).                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

Lower layers don't know about upper layers. You can depend on the kernel alone for headless work and never pull a Metal framework.

## When to use which

### Doing solid modeling, headless

You want **OCCTSwift** alone. Construct shapes, do booleans, sample geometry, walk topology, do measurements and feature recognition. No viewport, no graphics framework dep.

If you also need to read or write STEP / IGES / STL / OBJ / BREP / glTF, add **OCCTSwiftIO**. It separates file format concerns from the kernel so that batch pipelines (CLIs, server-side, CI) don't drag in Viewport.

If you need to simplify or repair meshes (decimation, smoothing, repair), add **OCCTSwiftMesh**. It vendors `meshoptimizer` under an LGPL wrapper.

### Building a CAD application with a 3D viewport

You want the full visualization stack:

- **OCCTSwiftViewport** — the Metal-backed `MetalViewportView` (UIKit / AppKit / SwiftUI). Renders `ViewportBody` arrays and exposes camera, lighting, and selection events.
- **OCCTSwiftTools** — converts kernel `Shape` instances into `ViewportBody` arrays with picking metadata (`vertexIndices`, `edgeIndices`, `faceIndices`). This is the layer that knows about *both* kernels and viewports.
- **OCCTSwiftAIS** — high-level interactive services on top: selection-from-topology, manipulator widgets, dimension annotations, scene objects (Trihedron / WorkPlane / PointCloud / etc.). Inspired by OpenCASCADE's `AIS_*` API.

`OCCTSwiftTools` re-exports `OCCTSwiftIO` symbols, so if you've already pulled Tools you can use the file loaders without an extra import.

### Building a headless CLI or script runner

You want **OCCTSwiftScripts**. It ships:

- `occtkit` — a CLI binary with verbs like `compose`, `reconstruct`, `drawing-export`, `metrics`, `simplify-mesh`, `render-preview`, `xcaf`. Ready to drive from a Makefile or a server-side parametric pipeline.
- `ScriptHarness` library — JSON-driven manifest format you can embed in your own tools, with topology-graph descriptors for downstream watchers.

Scripts depends on the full ecosystem (kernel + IO + Mesh + Tools + AIS + Viewport for `render-preview`). If your use case is purely batch and you don't need preview rendering, depend on the lower-tier packages directly instead.

### Exposing CAD modeling to AI agents

You want **OCCTMCP** — an MCP (Model Context Protocol) server that exposes OCCT modeling primitives to LLM-driven tooling. Wraps `OCCTSwiftScripts` verbs as MCP tools.

### Working from C, not Swift

If you can't depend on Swift (e.g. you're writing a C plugin for a host application), look at **simpleOCCTVP** — a pure C API over OpenCASCADE for shape I/O, healing, mesh extraction, and offscreen 3D rendering. Independent of the Swift stack; useful if you're integrating OCCT into a non-Swift codebase on macOS.

### Engineering-drawing ML pipelines

`OCCTSwift` itself ships `TopologyGraph` for graph-based topology representation, plus UV-grid samplers and curve samplers for ML feature extraction. Combined with `OCCTSwiftIO.exportForML()` (extension on `TopologyGraph` lifted from the kernel in v0.171.0), you can produce flat / COO-format adjacency tensors for GNN / UV-Net / BRepNet pipelines.

For trained model artifacts and CoreML wrappers:

- **occt-design-loop-models** — pre-trained models published as ML artifacts: a GATv2 link predictor (F1 0.995 dimension-geometry) and a Random Forest line classifier.
- **coreml-occt-models** — convenience wrappers for Apple's CoreML vision models tuned for engineering-drawing workflows.

## Compatibility matrix (v1.0.0 cohort, May 2026)

All public packages graduated to **SemVer-stable v1.0.0** alongside OCCTSwift v1.0.0 (OCCT 8.0.0 GA, 2026-05-07). Floors below are the recommended pins:

| Package | Floor | Pulls (transitively) |
|---------|-------|----------------------|
| OCCTSwift | `from: "1.1.0"` | — |
| OCCTSwiftIO | `from: "1.0.0"` | OCCTSwift |
| OCCTSwiftMesh | `from: "1.0.0"` | OCCTSwift |
| OCCTSwiftViewport | `from: "1.0.4"` | — (leaf; renders `ViewportBody`, no kernel dep) |
| OCCTSwiftTools | `from: "1.1.1"` | OCCTSwift, OCCTSwiftViewport, OCCTSwiftIO |
| OCCTSwiftAIS | `from: "1.0.2"` | OCCTSwiftTools (→ Viewport, IO, kernel) |
| OCCTSwiftScripts | `from: "1.0.3"` | full stack |
| OCCTMCP | `from: "1.4.2"` | OCCTSwiftScripts |
| simpleOCCTVP | — | own C build of OCCT; independent of Swift packages |

## Notable v1.0.x patches

- **OCCTSwift v1.0.1** — `TopologyGraph.NodeKind` extended to cover `Product` / `Occurrence` raw values; without this, `rootNodes` silently returned `[]` for any graph with assembly roots.
- **OCCTSwift v1.0.2** — per-input boolean history surface (`unionWithFullHistory` / `subtractedWithFullHistory` / `intersectionWithFullHistory` / `splitWithFullHistory`), used by selection-remapping consumers (e.g. OCCTMCP's `remap_selection`) to walk selection IDs across boolean / split mutations exactly instead of falling back to a centroid-distance heuristic.
- **OCCTSwift v1.0.3** — extends per-input history to modification ops (`filletedWithFullHistory` / `chamferedWithFullHistory` / `shelledWithFullHistory` / `defeaturedWithFullHistory`) and threads it through `FeatureReconstructor.BuildResult.histories[featureID]`. Closes the long-running #165 selection-survival epic.
- **OCCTSwift v1.0.4** — wires `applyFillet` / `applyChamfer` through the Tier 2 history variants and implements chamfer's `.nearPoint` / `.onFeature` selectors that were stubbed before. After this, every `FeatureSpec` kind (boolean / hole / additive / fillet / chamfer) populates `BuildResult.histories[id]` for specs with non-nil ids — closes #166.
- **OCCTSwiftViewport v1.0.2** — point-cloud rendering pipeline (point sprites with screen-space disk masking via `[[point_size]]`). Adds `BodyPrimitiveKind`, `vertexColors`, `pointRadius` to `ViewportBody`. Closes Viewport [#28](https://github.com/gsdali/OCCTSwiftViewport/issues/28).
- **OCCTSwiftViewport v1.0.3** — fixes an **uncatchable** crash (`fatalError`, not a thrown error) on body load: `NormalSmoothing.quantize(_:)` overflowed `Int32` for any mesh vertex beyond ±21,474.8 model units (or `NaN`/`±inf`). Now clamps non-finite/out-of-range coords before the trapping conversion. Closes Viewport [#30](https://github.com/gsdali/OCCTSwiftViewport/issues/30).
- **OCCTSwiftViewport v1.0.4** — packaging fix: the demo target's dependency on `OCCTSwiftTools` (which depends back on Viewport) formed a package cycle that broke standalone `swift build`. The demo moved to `Examples/MetalDemo`; **the published Viewport package now has zero external dependencies** (its library never used the kernel or Tools). No library API change — fully compatible with v1.0.3. Closes Viewport [#32](https://github.com/gsdali/OCCTSwiftViewport/pull/32).
- **OCCTSwiftTools v1.1.0** — first MINOR bump under the [cohort SemVer policy](SEMVER.md). `PointConverter.pointsToBody` now wires `pointRadius` and `perPointColors` through to the new `ViewportBody` fields and stamps `primitiveKind = .point`. Companion follow-up to Viewport v1.0.2.
- **OCCTSwift v1.1.0** — `TopologyGraph.findDerivedOrSelf(of:)` and `hasHistoryRecord(for:)` disambiguate untouched-vs-deleted nodes that both returned `[]` from `findDerived` (closes #167). Direct unblocker for OCCTMCP `remap_selection`'s history path.
- **OCCTSwiftTools v1.0.1** — `PointConverter.pointsToBody(_:)` for rendering point clouds without sphere-compound triangulation. Renderer-side support for drawing the points as visible primitives is tracked at [OCCTSwiftViewport#28](https://github.com/gsdali/OCCTSwiftViewport/issues/28).
- **OCCTMCP v1.2.0** — full `apply_feature` history surface (consumes OCCTSwift v1.0.4's per-input histories) plus visible point clouds end-to-end (Viewport v1.0.2 + Tools v1.1.0).
- **OCCTMCP v1.3.0** — `find_correspondences` tool (closes OCCTMCP #24) for matching topology across model variants, with a history-path fix.
- **OCCTMCP v1.4.0** — consumes OCCTSwift v1.1.0 (`findDerivedOrSelf` / `hasHistoryRecord`) and drops the identity-flag workaround `remap_selection` previously needed.
- **OCCTMCP v1.4.1** — dependency hygiene: drops the `gsdali/swift-sdk` fork branch for the official `modelcontextprotocol/swift-sdk` at a tagged version (0.12.1), back-porting the one-property `Value.numberValue` accessor locally until it lands upstream ([swift-sdk#226](https://github.com/modelcontextprotocol/swift-sdk/pull/226)). No behavioral change; the dependency graph is now reproducible.
- **Cohort floor alignment** (OCCTSwiftTools v1.1.1, OCCTSwiftAIS v1.0.2, OCCTSwiftScripts v1.0.3, OCCTMCP v1.4.2) — propagates the Viewport v1.0.3 `quantize()` crash fix as a hard floor through every Viewport consumer. OCCTMCP's lockfile in particular was still pinned to Viewport v1.0.2 (the crashing version) and now locks v1.0.4. All pure dep-floor bumps; no API changes.

## Versioning posture

- **OCCTSwift** sets the OCCT-version pin for the whole ecosystem. A new OCCTSwift major (e.g. v2.0.0) signals an OCCT 9.x bump and a coordinated cohort upgrade.
- **Other packages** version independently within their own SemVer line, but their major versions tend to graduate alongside the kernel's. For routine work you can take patch and minor updates everywhere without re-pinning OCCTSwift.
- **Pre-1.0 history**: the ecosystem went through ~170 OCCTSwift point releases tracking OCCT 8.0 release candidates (rc3 → rc4 → rc5 → beta1 → beta2) before graduating with OCCT GA. Pre-1.0 was free to break; v1.0+ follows the [cohort SemVer policy](SEMVER.md).

The full versioning policy — what counts as MAJOR / MINOR / PATCH, how the cohort coordinates, and when dep floors get bumped — is documented in [`docs/SEMVER.md`](SEMVER.md).

See [`docs/CHANGELOG.md`](CHANGELOG.md) for the OCCTSwift release history and [`docs/occt-upgrades.md`](occt-upgrades.md) for OCCT version migration notes.
