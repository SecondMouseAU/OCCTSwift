---
title: Sheet Metal
parent: API Reference
---

# Sheet Metal

`SheetMetal` is a declarative namespace for composing bent sheet-metal parts from planar flanges and bend specifications. `StandardLayout` (in `SheetLayout.swift`) is a companion `Sheet` extension that auto-arranges front/top/side/iso engineering views on a drawing sheet. Neither type wraps OCCT sheet-metal primitives directly; both build on `Shape.extrude`, `Shape.union`, `Shape.filleted`, and `Drawing` view factories.

## Topics

- [SheetMetal.Flange](#sheetmetalflange) · [SheetMetal.BendDirection](#sheetmetalblenddirection) · [SheetMetal.Bend](#sheetmetalbend) · [SheetMetal.BuildError](#sheetmetalbuilderror) · [SheetMetal.Builder](#sheetmetalbuilder) · [StandardLayout](#standardlayout) · [StandardLayout.PlacedView](#standardlayoutplacedview) · [Sheet Extension — standardLayout](#sheet-extension--standardlayout)

---

## SheetMetal.Flange

A single sheet-metal flange: a closed 2D profile positioned in world space via `(origin, uAxis, vAxis)`, extruded along `normal` by the builder's `thickness`.

```swift
public struct Flange: Sendable {
    public let id: String
    public let profile: [SIMD2<Double>]
    public let origin: SIMD3<Double>
    public let uAxis: SIMD3<Double>
    public let vAxis: SIMD3<Double>
    public let normal: SIMD3<Double>
}
```

All three axes are stored explicitly to avoid handedness surprises when flanges are placed in arbitrary world orientations. If `vAxis` is omitted at init, it is derived as `cross(normal, uAxis)`.

---

### `Flange.init(id:profile:origin:normal:uAxis:vAxis:)`

Constructs a positioned flange from a 2D profile and world-space axes.

```swift
public init(
    id: String,
    profile: [SIMD2<Double>],
    origin: SIMD3<Double>,
    normal: SIMD3<Double>,
    uAxis: SIMD3<Double>,
    vAxis: SIMD3<Double>? = nil
)
```

The `normal` is normalised at init time; `vAxis` defaults to `cross(normal, uAxis)` if `nil`.

- **Parameters:**
  - `id` — unique string identifier referenced by `Bend.fromFlangeID`/`Bend.toFlangeID`.
  - `profile` — ordered 2D polygon vertices (at least 3 points) in the flange's local `(u, v)` space.
  - `origin` — world-space origin of the profile plane.
  - `normal` — extrusion direction; normalised automatically.
  - `uAxis` — local U axis in world space.
  - `vAxis` — local V axis; computed from `normal × uAxis` if omitted.
- **Note:** Stepped-seam bends (issue #86, v0.153) require rectangular profiles for split-flange support; non-rectangular profiles still work when no step split is needed.
- **Example:**
  ```swift
  let base = SheetMetal.Flange(
      id: "base",
      profile: [SIMD2(0, 0), SIMD2(100, 0), SIMD2(100, 50), SIMD2(0, 50)],
      origin: .zero,
      normal: SIMD3(0, 0, 1),
      uAxis:  SIMD3(1, 0, 0)
  )
  ```

---

## SheetMetal.BendDirection

Direction of a bend, measured from the metal's perspective.

```swift
public enum BendDirection: Sendable, Equatable {
    case auto
    case concave
    case convex
}
```

- `.concave` — the metal folds toward itself (interior dihedral < 180°), as in an L-bracket.
- `.convex` — the metal folds back on the opposite side (interior dihedral > 180°, reflex), as in the middle bend of a Z-section.
- `.auto` — direction inferred from flange-body positions: concave when flange B's centroid sits on flange A's `+normal` side.

---

## SheetMetal.Bend

A bend between two flanges, with inside/outside radius, optional angle, material thickness override, and direction control.

```swift
public struct Bend: Sendable {
    public let fromFlangeID: String
    public let toFlangeID: String
    public let angle: Double?
    public let insideRadius: Double
    public let outsideRadius: Double?
    public let materialThicknessAtBend: Double?
    public let direction: BendDirection
}
```

- `angle` — bend angle in radians; `nil` means infer from flange placements. `0` = flat continuation; `±π` = fully closed. Positive = concave; negative = convex.
- `insideRadius` — concave (inner) bend radius. `0` for a sharp inside corner.
- `outsideRadius` — convex (outer) bend radius; defaults to `insideRadius + thickness` when `nil`.
- `materialThicknessAtBend` — material thickness through the bend zone; defaults to the builder's global `thickness`. Set to a fraction for etched/thinned bend lines.
- `direction` — explicit override; defaults to `.auto`.

---

### `Bend.init(from:to:radius:)`

Backward-compatible convenience init: `radius` becomes the inside bend radius; direction is inferred.

```swift
public init(from fromID: String, to toID: String, radius: Double)
```

- **Parameters:**
  - `fromID` — ID of the originating flange.
  - `toID` — ID of the target flange.
  - `radius` — inside bend radius. Outside radius defaults to `radius + thickness`.
- **Example:**
  ```swift
  let bend = SheetMetal.Bend(from: "base", to: "upright", radius: 2.0)
  ```

---

### `Bend.init(from:to:angle:insideRadius:outsideRadius:materialThicknessAtBend:direction:)`

Full init exposing all bend controls.

```swift
public init(
    from fromID: String,
    to toID: String,
    angle: Double? = nil,
    insideRadius: Double,
    outsideRadius: Double? = nil,
    materialThicknessAtBend: Double? = nil,
    direction: BendDirection = .auto
)
```

- **Parameters:**
  - `fromID` — ID of the originating flange.
  - `toID` — ID of the target flange.
  - `angle` — bend angle in radians (`nil` = infer from geometry).
  - `insideRadius` — concave radius.
  - `outsideRadius` — convex radius; `nil` = `insideRadius + thickness`.
  - `materialThicknessAtBend` — local material thickness override; `nil` = global `thickness`.
  - `direction` — `.auto`, `.concave`, or `.convex`.
- **Example:**
  ```swift
  let bend = SheetMetal.Bend(
      from: "base", to: "upright",
      insideRadius: 2.0,
      outsideRadius: 3.0,
      direction: .concave
  )
  ```

---

### `Bend.radius`

Legacy alias for `insideRadius`.

```swift
public var radius: Double { insideRadius }
```

Retained for backward compatibility with pre-v0.155 call sites that used the single-`radius` init. New code should use `insideRadius` directly.

---

## SheetMetal.BuildError

Errors thrown by `SheetMetal.Builder.build(flanges:bends:)`.

```swift
public enum BuildError: Error, CustomStringConvertible {
    case invalidThickness(Double)
    case noFlanges
    case duplicateFlangeID(String)
    case unknownFlangeID(String)
    case invalidFlangeProfile(id: String)
    case flangeExtrusionFailed(id: String)
    case unionFailed
    case parallelFlangesHaveNoSeam(fromID: String, toID: String)
    case noSeamEdgeFound(fromID: String, toID: String)
    case filletFailed(fromID: String, toID: String, radius: Double)
    case seamsDoNotOverlap(fromID: String, toID: String)
    case nonRectangularStepFlange(id: String)
}
```

| Case | Meaning |
|------|---------|
| `.invalidThickness` | `thickness` ≤ 0. |
| `.noFlanges` | `flanges` array is empty. |
| `.duplicateFlangeID` | Two flanges share the same `id`. |
| `.unknownFlangeID` | A `Bend` references a flange `id` not in `flanges`. |
| `.invalidFlangeProfile` | Flange profile has fewer than 3 points. |
| `.flangeExtrusionFailed` | `Shape.extrude` returned `nil` for this flange. |
| `.unionFailed` | Boolean union of extruded pieces failed. |
| `.parallelFlangesHaveNoSeam` | The two flanges are parallel — their normals cross-product is zero, so there is no seam line. |
| `.noSeamEdgeFound` | Union succeeded but no shared seam edge was found between the two flanges' matched-extent pieces. |
| `.filletFailed` | `Shape.filleted(edges:radius:)` returned `nil` for the seam edge(s). |
| `.seamsDoNotOverlap` | The two flanges' seam-direction extents have no overlap — they cannot meet. |
| `.nonRectangularStepFlange` | A stepped-seam bend targets a non-rectangular flange profile; v0.153 split logic requires rectangles. |

---

## SheetMetal.Builder

Composes a list of flanges and bends into a single bent `Shape`.

```swift
public struct Builder: Sendable {
    public let thickness: Double
}
```

The builder validates inputs, optionally splits flanges at stepped-seam intersections, extrudes each piece along its `normal`, fuses all pieces with `Shape.union`, then fillets each bend seam with `Shape.filleted(edges:radius:)`.

- **OCCT:** Internally delegates to `BRepPrimAPI_MakePrism` (via `Shape.extrude`), `BRepAlgoAPI_Fuse` (via `Shape.union`), and `BRepFilletAPI_MakeFillet` (via `Shape.filleted`).

---

### `Builder.init(thickness:)`

Creates a builder for sheet metal of the given uniform thickness.

```swift
public init(thickness: Double)
```

- **Parameters:** `thickness` — sheet thickness in model units; must be > 0 or `build` throws `.invalidThickness`.
- **Example:**
  ```swift
  let builder = SheetMetal.Builder(thickness: 2.0)
  ```

---

### `Builder.build(flanges:bends:)`

Build the bent sheet-metal part from the supplied flanges and bend specifications.

```swift
public func build(flanges: [Flange], bends: [Bend] = []) throws -> Shape
```

**Build sequence:**

1. Validate `thickness > 0` and `flanges` non-empty; check all `Bend` IDs exist.
2. For each bend, compute the seam direction (`cross(a.normal, b.normal)`) and the overlap range along the seam. If a flange extends past the intersection (a *stepped* seam), split that flange's profile at the intersection endpoints — the matched-extent middle piece carries the bend; outer pieces remain flat.
3. Extrude every piece via `Wire.polygon3D` + `Shape.extrude(profile:direction:length:)`.
4. Fuse all pieces with sequential `Shape.union`.
5. For each **concave** bend: locate seam edges between the matched-extent pieces and call `Shape.filleted(edges:radius:)`.
   For each **convex** bend: build a curved-triangle prism of bend material (three-point arc cross-section extruded along the seam) and fuse it in.

- **Parameters:**
  - `flanges` — ordered list of flanges; IDs must be unique; each profile needs ≥ 3 points.
  - `bends` — list of bend connections; defaults to `[]` (no bends = simple multi-flange union).
- **Returns:** Fused and filleted `Shape`.
- **Throws:** `BuildError` on validation failure, extrusion failure, union failure, or fillet failure.
- **OCCT:** `BRepPrimAPI_MakePrism` (extrude) · `BRepAlgoAPI_Fuse` (union) · `BRepFilletAPI_MakeFillet` (fillet) · `GC_MakeArcOfCircle` / `BRepBuilderAPI_MakeWire` (convex bend arc) · `GC_MakeSegment` (convex bend lines).
- **Example:**
  ```swift
  let base = SheetMetal.Flange(
      id: "base",
      profile: [SIMD2(0,0), SIMD2(80,0), SIMD2(80,50), SIMD2(0,50)],
      origin: .zero,
      normal: SIMD3(0, 0, 1),
      uAxis:  SIMD3(1, 0, 0)
  )
  let upright = SheetMetal.Flange(
      id: "upright",
      profile: [SIMD2(0,0), SIMD2(80,0), SIMD2(80,40), SIMD2(0,40)],
      origin: SIMD3(0, 50, 0),
      normal: SIMD3(0, 1, 0),
      uAxis:  SIMD3(1, 0, 0)
  )
  let bend = SheetMetal.Bend(from: "base", to: "upright", radius: 3.0)
  let builder = SheetMetal.Builder(thickness: 2.0)
  if let bracket = try? builder.build(flanges: [base, upright], bends: [bend]) {
      // bracket is a filleted L-shape
  }
  ```
- **Note:** Convex bends (`.convex` or auto-inferred) add bend material rather than filleting an existing edge — the inside corner stays sharp at the kiss line. For a fully-rounded inside, position flanges to leave room for the inner cylinder.

---

## StandardLayout

Result of `Sheet.standardLayout(of:scale:margin:includeIso:)`. Holds four placed views in ISO 5456-2 projection-angle order (first-angle or third-angle, following the sheet's `projection` setting).

```swift
public struct StandardLayout: Sendable {
    public let front: PlacedView
    public let top: PlacedView
    public let side: PlacedView
    public let iso: PlacedView?
}
```

Each `PlacedView` carries the original unannotated `Drawing` (so callers can attach dimensions or centrelines to a specific view) together with the `offset` and `scale` that `render(into:)` applies.

---

### `StandardLayout.front`

The front-view placed drawing.

```swift
public let front: PlacedView
```

Position within the 2×2 grid follows ISO 5456-2: lower-left cell for first-angle; lower-left cell for third-angle as well (both conventions place the front view at the primary position).

---

### `StandardLayout.top`

The top-view placed drawing.

```swift
public let top: PlacedView
```

First-angle: lower-left cell (below front). Third-angle: upper-left cell (above front).

---

### `StandardLayout.side`

The right-side-view placed drawing.

```swift
public let side: PlacedView
```

First-angle: upper-right cell (beside front). Third-angle: lower-right cell.

---

### `StandardLayout.iso`

The isometric-view placed drawing, or `nil` if `includeIso: false` was passed.

```swift
public let iso: PlacedView?
```

Always placed in the remaining corner: upper-right for third-angle; lower-right for first-angle.

---

### `StandardLayout.placed`

Every placed view in draw order: front, top, side, then iso (if present).

```swift
public var placed: [PlacedView] { get }
```

Pure-Swift. Useful for iterating all views uniformly.

- **Example:**
  ```swift
  for p in layout.placed {
      print(p.scale, p.offset)
  }
  ```

---

### `StandardLayout.render(into:)`

Emits every placed view onto a `DXFWriter` via its scaled/translated transform.

```swift
public func render(into writer: DXFWriter)
```

Calls `writer.collectFromDrawing(_:translate:scale:)` for each view in `placed` order. The writer accumulates all geometry; call its output method after `render` to produce the DXF bytes.

- **Parameters:** `writer` — `DXFWriter` to receive the drawing entities.
- **Example:**
  ```swift
  let writer = DXFWriter()
  layout.render(into: writer)
  let dxf = writer.dxfString()
  ```

---

## StandardLayout.PlacedView

A single view with its position and scale within the layout.

```swift
public struct PlacedView: Sendable {
    public let drawing: Drawing
    public let offset: SIMD2<Double>
    public let scale: Double
}
```

- `drawing` — the original unannotated `Drawing`. Mutate this (add dimensions, centrelines) before calling `render(into:)`.
- `offset` — translation applied to the drawing's coordinate system: `apply(p) = scale * p + offset`.
- `scale` — uniform scale factor. Computed as `min(caller's scale, fit-to-cell scale)` so no view overflows its cell.

---

## Sheet Extension — standardLayout

### `Sheet.standardLayout(of:scale:margin:includeIso:)`

Auto-composes front / top / side / optional isometric views of `shape` onto this sheet at the supplied scale, arranged in a 2×2 grid following ISO 5456-2.

```swift
public func standardLayout(of shape: Shape,
                            scale: DrawingScale = .one,
                            margin: Double = 20,
                            includeIso: Bool = true) -> StandardLayout?
```

**Algorithm:**

1. Generate `Drawing.frontView`, `topView`, `sideView` (and optionally `isometricView`) via the `Drawing` projection API.
2. Compute the sheet's inner frame, subtract `margin` on each outer edge and `margin/2` between cells to get four equal cells.
3. Choose a uniform `appliedScale = min(callerScale, fit-to-cell scale)` that prevents any view from overflowing its cell.
4. Assign views to the 2×2 grid slots per the sheet's `projection` setting (`.first` or `.third`).
5. Compute each view's `offset` so the view's bounding-box centre aligns with its cell centre.

- **Parameters:**
  - `shape` — the solid to project.
  - `scale` — caller's preferred uniform scale (default `.one` = 1:1). Applied only if smaller than the fit-to-cell scale.
  - `margin` — outer and inter-cell margin in sheet units (default 20).
  - `includeIso` — when `false`, the isometric cell is left empty; `StandardLayout.iso` is `nil`.
- **Returns:** `StandardLayout` with four placed views, or `nil` if any of the front/top/side projections fail.
- **Note:** The isometric view failure is non-fatal — if `Drawing.isometricView` returns `nil`, `iso` is simply `nil`.
- **Example:**
  ```swift
  let sheet = Sheet(size: .a3, projection: .first)
  let box = Shape.box(width: 80, height: 50, depth: 30)!
  if let layout = sheet.standardLayout(of: box, scale: .oneToTwo, margin: 15) {
      let writer = DXFWriter()
      layout.render(into: writer)
      try writer.dxfString().write(toFile: "/tmp/bracket.dxf",
                                   atomically: true, encoding: .utf8)
  }
  ```
