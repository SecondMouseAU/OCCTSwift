---
title: API Reference
nav_order: 3
has_children: true
---

# OCCTSwift API Reference

A **detailed, per-type function reference** for the OCCTSwift Swift API — modelled on OCCT's own
Doxygen class reference (`dev.opencascade.org`, indexed on context7 as `/open-cascade-sas/occt`).
One page per public Swift type, every public method documented: signature, behaviour, parameters,
return, the **OCCT class/method it wraps**, a runnable example, and gotchas.

This complements the other docs — it's the *exhaustive* surface, vs:
- [`API_REFERENCE.md`](../API_REFERENCE.md) — the compact Swift→OCCT **mapping table**.
- [`guides/cookbook/`](../guides/cookbook/) — *task-oriented* example pages.

> **Generation.** These pages are produced by subagents (see `/document-api`), one per source file,
> each reading the Swift source + the `OCCTBridge` mapping + the upstream OCCT docs. Built over time;
> see [Status](#status) for coverage.

## Page layout

One file `docs/reference/<Type>.md` per public Swift type (matching `Sources/OCCTSwift/<Type>.swift`).
Large types are split by their `// MARK:` sections into `<Type>-<Area>.md` (see [Status](#status)).

Each page:

```markdown
---
title: <Type>
parent: API Reference
---

# <Type>

<1–3 sentences: what the type represents, its OCCT analog(s), and how you obtain one.>

## Topics

- [<Group A>](#group-a) · [<Group B>](#group-b) · …

---

## <Group>        ← one ## per source `// MARK:` section, in source order

### `Type.method(label:)`     ← `###` per public member, in source order

<one-line summary — what it does.>

​```swift
public func method(label: Type) -> ReturnType
​```

<optional 1–2 sentences of detail / when to use.>

- **Parameters:** `label` — meaning. *(omit if none)*
- **Returns:** what comes back; **state nil/throws conditions** for optionals/throwing calls.
- **OCCT:** `Upstream_Class::Method` — the wrapped C++ API. *(omit only if pure-Swift)*
- **Example:**
  ​```swift
  let r = Type.method(label: …)
  ​```
- **Note:** gotchas / edge cases. *(omit if none)*
```

## Entry rules (the template contract)

1. **Signature is verbatim** from the source — copy the full public declaration, including defaults.
2. **Every public `func` / `var` / `static func` / `init`** of the type gets a `###` entry, in source
   order, grouped under its `// MARK:` section.
3. **OCCT mapping is required** wherever the method calls a bridge function — name the upstream class
   (`BRepBuilderAPI_MakeWire`, `Geom_BSplineCurve`, …). Find it from the bridge `.mm` implementation
   or the cross-reference index in `OCCTBridge.h`. Omit only for pure-Swift helpers.
4. **Examples must be signature-faithful and runnable.** Reuse a snippet from a cookbook page or a
   test where one exists (these are compile-checked); otherwise write a minimal, type-correct one.
   Fallible APIs unwrap with `guard`/`if let`, never force-unwrap.
5. **No invention.** Behaviour comes from the source doc comment, the bridge, and the OCCT docs — not
   guessed. If a method's purpose is unclear, say so briefly rather than fabricate.
6. **Concise.** Reference, not prose — one tight summary line, parameters/returns as bullets.

## Rollout

- **Unit of work:** one source file = one subagent job. Run a batch per session; `/document-api <Type>`
  for a single page.
- **Order:** core types first (Shape, Wire, Surface, Curve3D, Curve2D, Edge, Face, Mesh), then I/O &
  documents (Exporter, Document), then the long tail (drawing, annotation, measurement, etc.).
- **Giants** (`Document` ~1865, `Shape` ~993, `BRepGraph`, `Surface`, `Curve2D`, `Curve3D`): split by
  `// MARK:` section into `<Type>-<Area>.md`, one subagent per chunk, linked from the type's index page.

## Status

Coverage tracker — update as pages land. (Counts = public decls in the source file.)

| Type | decls | page | status |
|------|------:|------|--------|
| Wire | 61 | `Wire.md` | ✅ done |
| Shape | 867 | `Shape.md` + 8 (Features, Healing, Measurement, Builders I/II, HLR-Geom, Recognition, Completions) | ✅ done |
| Surface | 234 | `Surface.md` + 4 (Analytic Types, BSpline & Bezier, Analysis, Advanced) | ✅ done |
| Curve3D | 177 | `Curve3D.md` + 3 (Analytic Types, Analysis, Construction) | ✅ done |
| Curve2D | 205 | `Curve2D.md` + 3 (Analytic Types, Analysis, Constraint Solvers) | ✅ done |
| Edge | 36 | `Edge.md` | ✅ done |
| Face | 32 | `Face.md` | ✅ done |
| Mesh | 34 | `Mesh.md` | ✅ done |
| Exporter | 39 | `Exporter.md` | ✅ done |
| Document | 1735 | `Document.md` + 12 (Persistence-IO, XCAF-Notes, OCAF-Attributes, Math-Bounds, Analysis-Builders, Geometry-Constructors, BSpline-Extrema, Math-Solvers, Mesh-Fixing, Transforms, Builders-Fillet, Completions) | ✅ done |
| TopologyGraph (BRepGraph) | 375 | `TopologyGraph.md` + 4 (Detail-History, Builders, Editor-Identity, Attributes) | ✅ done |
| ThreadFeatures | 30 | `ThreadFeatures.md` | ✅ done |
| DrawingAnnotation | 100 | `DrawingAnnotation.md` | ✅ done |
| Drawing & Sheets (Drawing, DrawingSheet, DrawingStyle, DisplayDrawer) | 94 | `Drawing.md` | ✅ done |
| Drawing Automation (Composition, AutoCenterlines/Dimensions, ThreadAnnotation, Symbols, HatchPattern) | 39 | `Drawing-Automation.md` | ✅ done |
| Annotation & GD&T (Annotation, GDTWrite) | 75 | `Annotation.md` | ✅ done |
| Construction & Sketching (ConstructionContext/Layer/Entity, Sketch, Section2D) | 91 | `Construction.md` | ✅ done |
| 2D Geometry Primitives (Point2D, Transform2D, ShapeAxis, AxisPlacement2D) | 52 | `Geometry2D.md` | ✅ done |
| FeatureReconstructor | 67 | `FeatureReconstructor.md` | ✅ done |
| Feature Recognition & Medial Axis (FeatureRecognition, MedialAxis) | 63 | `FeatureRecognition.md` | ✅ done |
| Vector & Raster Export (PDF, SVG, DXF, PixMap) | 72 | `Export-Vector.md` | ✅ done |
| Color & Material (Color, Material) | 76 | `Color-Material.md` | ✅ done |
| Display & Presentation (ZLayerSettings, ClipPlane, Camera, PresentationMesh, FontManager) | 77 | `Display.md` | ✅ done |
| Measurement (MeasurementHelpers, ShapeMeasurements) | 32 | `Measurement.md` | ✅ done |
| Sheet Metal (SheetMetal, SheetLayout) | 39 | `SheetMetal.md` | ✅ done |
| Bill of Materials & Selection (BillOfMaterials, Selector, Selection) | 48 | `Selection.md` | ✅ done |
| Date & Period (Date, Period) | 33 | `DateTime.md` | ✅ done |
| Curve Adaptors & Wire Ordering (WireCurve, EdgeCurve, WireOrder) | 31 | `CurveAdaptors.md` | ✅ done |
| Geometry Solvers & Builders (BSplineApproxInterp, PlateSolver, FillingSurface, LawFunction, PolynomialSolver, KDTree) | 59 | `GeometrySolvers.md` | ✅ done |
| Concurrency & Progress (OCCTSerial, ImportProgress) | 6 | `Concurrency.md` | ✅ done |
