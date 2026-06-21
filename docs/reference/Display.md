---
title: Display & Presentation
parent: API Reference
---

# Display & Presentation

These five types provide the rendering infrastructure for OCCTSwift: camera control, clipping planes, render-layer configuration, tessellated mesh extraction for Metal vertex buffers, and system font enumeration. They wrap OCCT's `Graphic3d_Camera`, `Graphic3d_ClipPlane`, `Graphic3d_ZLayerSettings`, `BRepMesh_IncrementalMesh` / `Poly_Triangulation`, and `Font_FontMgr` respectively.

## Topics

- [ZLayerSettings](#zlayersettings) · [ClipPlane](#clipplane) · [Camera](#camera) · [PresentationMesh (Shape extension)](#presentationmesh-shape-extension) · [FontManager](#fontmanager)

---

## ZLayerSettings

`ZLayerSettings` configures a named rendering Z-layer — controlling depth testing, depth writing, polygon offset (depth bias), ray-tracing participation, culling thresholds, and the layer coordinate origin. Wraps OCCT's `Graphic3d_ZLayerSettings`.

In a Metal renderer these properties map to: `MTLDepthStencilDescriptor` (depth test/write), depth attachment `loadAction` (clear depth), `setDepthBias()` on `MTLRenderCommandEncoder` (polygon offset), and render-pass ordering.

---

### Predefined Layer IDs

Five `static let` constants identify the built-in layer slots. Pass these to a renderer or selector when associating objects with a layer.

```swift
public static let bottomOSD: Int32   // -5 — 2D underlay, drawn behind everything
public static let `default`: Int32   // 0  — main 3D scene layer
public static let top: Int32         // -2 — 3D overlay, inherits depth from default
public static let topmost: Int32     // -3 — 3D overlay, independent depth buffer
public static let topOSD: Int32      // -4 — 2D overlay for annotations and UI
```

- **OCCT:** `Graphic3d_ZLayerId` enumeration values (`Graphic3d_ZLayerId_BotOSD`, `Graphic3d_ZLayerId_Default`, `Graphic3d_ZLayerId_Top`, `Graphic3d_ZLayerId_Topmost`, `Graphic3d_ZLayerId_TopOSD`).
- **Example:**
  ```swift
  // Place a transparent overlay object in the top OSD layer
  let overlayLayerId = ZLayerSettings.topOSD
  ```

---

### `PolygonOffsetMode`

Controls which primitive types receive the polygon-offset (depth bias).

```swift
public enum PolygonOffsetMode: Int32, Sendable {
    case off = 0
    case fill = 1     // shaded faces
    case line = 2     // line primitives
    case point = 4    // point primitives
    case all = 7      // all types
}
```

- **OCCT:** `Aspect_PolygonOffsetMode`.

---

### `PolygonOffset`

Groups the three polygon-offset parameters into a single value type.

```swift
public struct PolygonOffset: Sendable {
    public var mode: PolygonOffsetMode
    public var factor: Float
    public var units: Float
    public init(mode: PolygonOffsetMode = .off, factor: Float = 0, units: Float = 0)
}
```

Maps to Metal's `setDepthBias(depthBias:slopeScale:clamp:)`: `factor` → `slopeScale`, `units` → `depthBias`.

---

### `ZLayerSettings.init()`

Creates a new `ZLayerSettings` with default values.

```swift
public init()
```

- **OCCT:** `Graphic3d_ZLayerSettings` default constructor.
- **Example:**
  ```swift
  let layer = ZLayerSettings()
  layer.depthTestEnabled = true
  layer.clearDepth = false
  ```

---

## Depth

### `depthTestEnabled`

Whether depth testing is enabled for objects in this layer.

```swift
public var depthTestEnabled: Bool { get set }
```

- **OCCT:** `Graphic3d_ZLayerSettings::SetEnableDepthTest` / `ToEnableDepthTest`.
- **Example:**
  ```swift
  let layer = ZLayerSettings()
  layer.depthTestEnabled = false  // always-on-top overlay
  ```

---

### `depthWriteEnabled`

Whether objects in this layer write to the depth buffer.

```swift
public var depthWriteEnabled: Bool { get set }
```

Disable to allow subsequent layers to correctly depth-test against geometry underneath a transparent layer.

- **OCCT:** `Graphic3d_ZLayerSettings::SetEnableDepthWrite` / `ToEnableDepthWrite`.
- **Example:**
  ```swift
  layer.depthWriteEnabled = false  // transparent layer
  ```

---

### `clearDepth`

Whether the depth buffer is cleared before rendering this layer.

```swift
public var clearDepth: Bool { get set }
```

In Metal, maps to `loadAction = .clear` on the depth attachment for the layer's render pass. Use for layers that must not test against depth accumulated by previous layers.

- **OCCT:** `Graphic3d_ZLayerSettings::SetClearDepth` / `ToClearDepth`.
- **Example:**
  ```swift
  let topLayer = ZLayerSettings()
  topLayer.clearDepth = true   // start fresh depth for this pass
  ```

---

## Polygon Offset

### `polygonOffset`

The polygon-offset (depth bias) parameters for this layer.

```swift
public var polygonOffset: PolygonOffset { get set }
```

- **OCCT:** `Graphic3d_ZLayerSettings::SetPolygonOffset` / `PolygonOffset` → `Graphic3d_PolygonOffset` struct.
- **Example:**
  ```swift
  var layer = ZLayerSettings()
  layer.polygonOffset = PolygonOffset(mode: .fill, factor: 1, units: 1)
  ```

---

### `setDepthOffsetPositive()`

Sets a minimal positive depth offset (factor=1, units=1, mode=fill).

```swift
public func setDepthOffsetPositive()
```

Pushes coplanar geometry slightly away from the camera to avoid z-fighting.

- **OCCT:** `Graphic3d_ZLayerSettings::SetDepthOffsetPositive`.
- **Example:**
  ```swift
  let layer = ZLayerSettings()
  layer.setDepthOffsetPositive()
  ```

---

### `setDepthOffsetNegative()`

Sets a minimal negative depth offset (factor=1, units=-1, mode=fill).

```swift
public func setDepthOffsetNegative()
```

Pulls geometry slightly toward the camera — typical use is a wireframe overlay that should render on top of a co-planar shaded surface.

- **OCCT:** `Graphic3d_ZLayerSettings::SetDepthOffsetNegative`.
- **Example:**
  ```swift
  let wireLayer = ZLayerSettings()
  wireLayer.setDepthOffsetNegative()
  ```

---

## Rendering Options

### `isImmediate`

Whether this layer is drawn after all normal layers (immediate mode).

```swift
public var isImmediate: Bool { get set }
```

- **OCCT:** `Graphic3d_ZLayerSettings::SetImmediate` / `IsImmediate`.
- **Example:**
  ```swift
  layer.isImmediate = true  // draw this layer last
  ```

---

### `isRaytracable`

Whether objects in this layer participate in ray tracing.

```swift
public var isRaytracable: Bool { get set }
```

- **OCCT:** `Graphic3d_ZLayerSettings::SetRaytracable` / `IsRaytracable`.
- **Example:**
  ```swift
  layer.isRaytracable = false  // exclude UI overlays from ray-trace pass
  ```

---

### `useEnvironmentTexture`

Whether environment texture is applied to objects in this layer.

```swift
public var useEnvironmentTexture: Bool { get set }
```

- **OCCT:** `Graphic3d_ZLayerSettings::SetEnvironmentTexture` / `UseEnvironmentTexture`.
- **Example:**
  ```swift
  layer.useEnvironmentTexture = false  // flat-shaded annotation layer
  ```

---

### `renderInDepthPrepass`

Whether objects in this layer are rendered in the depth pre-pass.

```swift
public var renderInDepthPrepass: Bool { get set }
```

- **OCCT:** `Graphic3d_ZLayerSettings::SetRenderInDepthPrepass` / `ToRenderInDepthPrepass`.
- **Example:**
  ```swift
  layer.renderInDepthPrepass = false  // transparent objects skip depth pre-pass
  ```

---

## Culling

### `cullingDistance`

Distance-based culling threshold in model units.

```swift
public var cullingDistance: Double { get set }
```

Objects farther than this distance from the camera origin are culled from rendering. The default is a very large value (effectively disabled).

- **OCCT:** `Graphic3d_ZLayerSettings::SetCullingDistance` / `CullingDistance`.
- **Example:**
  ```swift
  layer.cullingDistance = 5000.0  // discard objects beyond 5 km
  ```

---

### `cullingSize`

Screen-space size culling threshold in pixels.

```swift
public var cullingSize: Double { get set }
```

Objects whose projected screen-space size falls below this threshold are culled. The default is a very large value (effectively disabled).

- **OCCT:** `Graphic3d_ZLayerSettings::SetCullingSize` / `CullingSize`.
- **Example:**
  ```swift
  layer.cullingSize = 2.0  // discard tiny details under 2 px
  ```

---

## Origin

### `origin`

Layer coordinate origin for floating-point precision in large scenes.

```swift
public var origin: SIMD3<Double> { get set }
```

When working with very large world coordinates (e.g. geospatial), set the layer origin near the camera position. Vertex shader positions are computed relative to this origin, keeping values in a numerically safe range.

- **OCCT:** `Graphic3d_ZLayerSettings::SetOrigin` / `Origin` → `gp_XYZ`.
- **Example:**
  ```swift
  layer.origin = SIMD3(500_000, 200_000, 0)  // geospatial tile offset
  ```

---

## ClipPlane

`ClipPlane` defines a half-space clipping plane using the equation `Ax + By + Cz + D = 0`. Points satisfying `Ax + By + Cz + D > 0` are considered visible. Planes can be chained for compound (AND) clipping regions. Wraps OCCT's `Graphic3d_ClipPlane`.

On Apple Silicon, the equation maps directly to `[[clip_distance]]` in a Metal vertex shader; up to 8 hardware-accelerated clip distances are supported.

---

### `ClipState`

Result of probing a point or bounding box against a clip plane (or chain).

```swift
public enum ClipState: Int32, Sendable {
    case out = 0   // fully outside — should be discarded
    case `in` = 1  // fully inside — not clipped
    case on  = 2   // on the boundary or partially clipped
}
```

- **OCCT:** `Graphic3d_ClipState` (`Graphic3d_ClipState_Out`, `Graphic3d_ClipState_In`, `Graphic3d_ClipState_On`).

---

### `HatchStyle`

Standard cross-section hatch pattern for the capping surface.

```swift
public enum HatchStyle: Int32, Sendable {
    case solid = 0, gridDiagonal = 1, gridDiagonalWide = 2
    case grid = 3, gridWide = 4
    case diagonal45 = 5, diagonal135 = 6
    case horizontal = 7, vertical = 8
    case diagonal45Wide = 9, diagonal135Wide = 10
    case horizontalWide = 11, verticalWide = 12
}
```

- **OCCT:** `Aspect_HatchStyle`.

---

### `ClipPlane.init(equation:)`

Creates a clip plane from the four equation coefficients.

```swift
public init(equation: SIMD4<Double>)
```

- **Parameters:** `equation` — `(A, B, C, D)` such that `Ax + By + Cz + D = 0`.
- **OCCT:** `Graphic3d_ClipPlane(Graphic3d_Vec4d(A, B, C, D))`.
- **Example:**
  ```swift
  // Clip everything below z = 5
  let plane = ClipPlane(equation: SIMD4(0, 0, 1, -5))
  ```

---

### `ClipPlane.init(normal:distance:)`

Creates a clip plane from a normal vector and signed distance from origin.

```swift
public init(normal: SIMD3<Double>, distance: Double)
```

The stored equation is `normal.x·x + normal.y·y + normal.z·z + distance = 0`.

- **Parameters:** `normal` — plane normal (used as-is, should be normalized); `distance` — signed distance from origin along the normal.
- **OCCT:** `Graphic3d_ClipPlane(Graphic3d_Vec4d(nx, ny, nz, distance))`.
- **Example:**
  ```swift
  let plane = ClipPlane(normal: SIMD3(0, 0, 1), distance: -5)
  // Clips everything below z = 5
  ```

---

## Equation

### `equation`

The plane equation coefficients `(A, B, C, D)`.

```swift
public var equation: SIMD4<Double> { get set }
```

- **OCCT:** `Graphic3d_ClipPlane::SetEquation` / `GetEquation`.
- **Example:**
  ```swift
  var plane = ClipPlane(equation: SIMD4(0, 0, 1, -10))
  plane.equation = SIMD4(0, 0, 1, -20)  // move cut to z = 20
  ```

---

### `reversedEquation`

The negated plane equation, useful for back-face clipping.

```swift
public var reversedEquation: SIMD4<Double> { get }
```

- **OCCT:** `Graphic3d_ClipPlane::ReversedEquation`.
- **Example:**
  ```swift
  let rev = plane.reversedEquation  // (-A, -B, -C, -D)
  ```

---

## Enable/Disable

### `isOn`

Whether this clip plane is active.

```swift
public var isOn: Bool { get set }
```

- **OCCT:** `Graphic3d_ClipPlane::SetOn` / `IsOn`.
- **Example:**
  ```swift
  plane.isOn = false  // temporarily disable without destroying
  ```

---

## Capping

### `isCapping`

Whether a filled cross-section surface (cap) is rendered at the cut.

```swift
public var isCapping: Bool { get set }
```

In Metal, implemented via the stencil-buffer technique: back faces increment, front faces decrement, fill where stencil ≠ 0.

- **OCCT:** `Graphic3d_ClipPlane::SetCapping` / `IsCapping`.
- **Example:**
  ```swift
  plane.isCapping = true
  plane.cappingColor = SIMD3(0.8, 0.8, 0.9)
  ```

---

### `cappingColor`

The RGB fill color of the capping surface (components in 0…1).

```swift
public var cappingColor: SIMD3<Double> { get set }
```

- **OCCT:** `Graphic3d_ClipPlane::SetCappingColor(Quantity_Color)` / `CappingAspect()->InteriorColor()`.
- **Example:**
  ```swift
  plane.cappingColor = SIMD3(0.9, 0.9, 0.6)
  ```

---

### `hatchStyle`

The hatch pattern drawn on the capping surface.

```swift
public var hatchStyle: HatchStyle { get set }
```

- **OCCT:** `Graphic3d_ClipPlane::SetCappingHatch(Aspect_HatchStyle)` / `CappingHatch`.
- **Example:**
  ```swift
  plane.hatchStyle = .diagonal45
  plane.isHatchOn = true
  ```

---

### `isHatchOn`

Whether the hatch pattern is rendered on the capping surface.

```swift
public var isHatchOn: Bool { get set }
```

- **OCCT:** `Graphic3d_ClipPlane::SetCappingHatchOn` / `SetCappingHatchOff` / `IsHatchOn`.
- **Example:**
  ```swift
  plane.isHatchOn = true
  ```

---

## Probing

### `probe(point:)`

Tests a world-space point against the clip plane (or chain of planes).

```swift
public func probe(point: SIMD3<Double>) -> ClipState
```

Iterates the full chain; returns `.out` immediately if any plane discards the point, `.on` if at least one plane is on the boundary, `.in` if all planes accept it.

- **Parameters:** `point` — 3D world-space point to test.
- **Returns:** The aggregate `ClipState` across the chain.
- **OCCT:** `Graphic3d_ClipPlane::ProbePointHalfspace` per plane in the chain.
- **Example:**
  ```swift
  let state = plane.probe(point: SIMD3(0, 0, 3))
  if state == .out { /* point is clipped */ }
  ```

---

### `probe(box:)`

Tests an axis-aligned bounding box against the clip plane (or chain of planes).

```swift
public func probe(box: (min: SIMD3<Double>, max: SIMD3<Double>)) -> ClipState
```

- **Parameters:** `box` — AABB defined by `(min, max)` corners.
- **Returns:** `.out` if fully clipped, `.in` if fully inside, `.on` if partially intersected.
- **OCCT:** `Graphic3d_ClipPlane::ProbeBoxHalfspace` (using `Graphic3d_BndBox3d`) per plane in the chain.
- **Example:**
  ```swift
  let box = shape.bounds
  let state = plane.probe(box: box)
  if state == .in { /* entire bounding box is visible */ }
  ```

---

## Chaining

### `chainNext(_:)`

Chains another clip plane for logical AND clipping.

```swift
public func chainNext(_ plane: ClipPlane?)
```

When planes are chained, a point or box must satisfy **all** planes in the chain to be considered visible. Pass `nil` to clear the chain.

- **Parameters:** `plane` — the next `ClipPlane` in the chain, or `nil` to detach.
- **OCCT:** `Graphic3d_ClipPlane::SetChainNextPlane`.
- **Example:**
  ```swift
  let planeA = ClipPlane(normal: SIMD3(0, 0, 1), distance: -5)
  let planeB = ClipPlane(normal: SIMD3(0, 0, -1), distance: 10)
  planeA.chainNext(planeB)  // visible only between z=5 and z=10
  ```

---

### `chainLength`

The number of planes in the forward chain, including this one.

```swift
public var chainLength: Int { get }
```

- **OCCT:** `Graphic3d_ClipPlane::NbChainNextPlanes` (returns the count of subsequent planes; OCCTSwift adds 1 to include the head).
- **Example:**
  ```swift
  #expect(planeA.chainLength == 2)  // head + one chained plane
  ```

---

## Camera

`Camera` is a 3D camera backed by `Graphic3d_Camera`. It exposes standard perspective/orthographic projection controls and produces Metal-compatible matrices (column-major, zero-to-one depth range via `SetZeroToOneDepth`). Obtain a `Camera` with `Camera()` and set its position/target before reading the matrices.

---

### `ProjectionType`

The camera projection mode.

```swift
public enum ProjectionType: Int32, Sendable {
    case perspective  = 0
    case orthographic = 1
}
```

- **OCCT:** `Graphic3d_Camera::Projection_Perspective` / `Projection_Orthographic`.

---

### `Camera.init()`

Creates a camera with default settings and zero-to-one depth range.

```swift
public init()
```

The underlying `Graphic3d_Camera` is created with `SetZeroToOneDepth(true)` so its projection matrix is directly usable in Metal shaders without remapping.

- **OCCT:** `new Graphic3d_Camera()` + `SetZeroToOneDepth(Standard_True)`.
- **Example:**
  ```swift
  let cam = Camera()
  cam.eye = SIMD3(0, -100, 50)
  cam.center = SIMD3(0, 0, 0)
  cam.up = SIMD3(0, 0, 1)
  ```

---

## Position

### `eye`

Camera eye (observer) position in world coordinates.

```swift
public var eye: SIMD3<Double> { get set }
```

- **OCCT:** `Graphic3d_Camera::SetEye(gp_Pnt)` / `Eye()`.
- **Example:**
  ```swift
  cam.eye = SIMD3(0, -200, 100)
  ```

---

### `center`

Camera look-at target in world coordinates.

```swift
public var center: SIMD3<Double> { get set }
```

- **OCCT:** `Graphic3d_Camera::SetCenter(gp_Pnt)` / `Center()`.
- **Example:**
  ```swift
  cam.center = SIMD3(0, 0, 0)
  ```

---

### `up`

Camera up direction vector.

```swift
public var up: SIMD3<Double> { get set }
```

- **OCCT:** `Graphic3d_Camera::SetUp(gp_Dir)` / `Up()`.
- **Example:**
  ```swift
  cam.up = SIMD3(0, 0, 1)  // Z-up
  ```

---

## Projection Parameters

### `projectionType`

The projection mode (perspective or orthographic).

```swift
public var projectionType: ProjectionType { get set }
```

- **OCCT:** `Graphic3d_Camera::SetProjectionType` / `ProjectionType`.
- **Example:**
  ```swift
  cam.projectionType = .orthographic
  ```

---

### `fieldOfView`

Vertical field of view in degrees (perspective mode only).

```swift
public var fieldOfView: Double { get set }
```

- **OCCT:** `Graphic3d_Camera::SetFOVy(degrees)` / `FOVy()`.
- **Example:**
  ```swift
  cam.fieldOfView = 60.0
  ```

---

### `scale`

Camera scale factor (orthographic mode only).

```swift
public var scale: Double { get set }
```

Controls the orthographic view volume size. Larger values zoom out.

- **OCCT:** `Graphic3d_Camera::SetScale` / `Scale`.
- **Example:**
  ```swift
  cam.projectionType = .orthographic
  cam.scale = 200.0  // view 200 model units tall
  ```

---

### `zRange`

Near and far clipping plane distances.

```swift
public var zRange: (near: Double, far: Double) { get set }
```

- **OCCT:** `Graphic3d_Camera::SetZRange(near, far)` / `ZNear()` + `ZFar()`.
- **Example:**
  ```swift
  cam.zRange = (near: 0.1, far: 10_000)
  ```

---

### `aspect`

Viewport aspect ratio (width / height).

```swift
public var aspect: Double { get set }
```

Update whenever the drawable size changes.

- **OCCT:** `Graphic3d_Camera::SetAspect` / `Aspect`.
- **Example:**
  ```swift
  cam.aspect = Double(viewportWidth) / Double(viewportHeight)
  ```

---

## Matrices (Metal-compatible, column-major, [0,1] depth)

### `projectionMatrix`

Projection matrix as a column-major `simd_float4x4` with Metal [0,1] depth range.

```swift
public var projectionMatrix: simd_float4x4 { get }
```

Uses `Graphic3d_Camera::ProjectionMatrixF()`. The zero-to-one depth range is set at construction; no further remapping is needed in the vertex shader.

- **OCCT:** `Graphic3d_Camera::ProjectionMatrixF()` → `Graphic3d_Mat4`.
- **Example:**
  ```swift
  var uniforms = MyUniforms()
  uniforms.projectionMatrix = cam.projectionMatrix
  ```

---

### `viewMatrix`

View (camera/orientation) matrix as a column-major `simd_float4x4`.

```swift
public var viewMatrix: simd_float4x4 { get }
```

- **OCCT:** `Graphic3d_Camera::OrientationMatrixF()` → `Graphic3d_Mat4`.
- **Example:**
  ```swift
  uniforms.viewMatrix = cam.viewMatrix
  ```

---

## Coordinate Conversion

### `project(_:)`

Projects a world-space point to normalized screen coordinates.

```swift
public func project(_ point: SIMD3<Double>) -> SIMD3<Double>
```

Returns zero on error (null camera or projection exception).

- **Parameters:** `point` — world-space 3D point.
- **Returns:** Normalized device coordinates `(x, y, z)`.
- **OCCT:** `Graphic3d_Camera::Project(gp_Pnt)`.
- **Example:**
  ```swift
  let ndc = cam.project(SIMD3(10, 0, 0))
  ```

---

### `unproject(_:)`

Unprojects a screen-space point to world coordinates.

```swift
public func unproject(_ point: SIMD3<Double>) -> SIMD3<Double>
```

Inverse of `project(_:)`. Returns zero on error.

- **Parameters:** `point` — normalized device coordinates.
- **Returns:** World-space 3D point.
- **OCCT:** `Graphic3d_Camera::UnProject(gp_Pnt)`.
- **Example:**
  ```swift
  let worldPt = cam.unproject(SIMD3(0, 0, 0.5))
  ```

---

## Fitting

### `fit(boundingBox:)`

Adjusts the camera to fit the given axis-aligned bounding box in view.

```swift
public func fit(boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>))
```

Calls `FitMinMax` with a 1% margin (`0.01`). After calling this, `eye`, `center`, and the z-range are updated.

- **Parameters:** `boundingBox` — AABB to fit, as `(min, max)` corners.
- **OCCT:** `Graphic3d_Camera::FitMinMax(Bnd_Box, margin, adjustZPlanes)`.
- **Example:**
  ```swift
  let box = myShape.bounds
  cam.fit(boundingBox: box)
  let proj = cam.projectionMatrix
  let view = cam.viewMatrix
  ```

---

## PresentationMesh (Shape extension)

Four methods on `Shape` extract GPU-ready mesh data by tessellating the shape's B-Rep geometry. Triangulation is performed on demand using `BRepMesh_IncrementalMesh`; the output structs (`ShadedMeshData`, `EdgeMeshData`) are directly usable as Metal vertex/index buffer sources.

---

### `ShadedMeshData`

Interleaved triangle mesh suitable for Metal vertex buffers.

```swift
public struct ShadedMeshData: Sendable {
    public let vertices: [SIMD3<Float>]       // per-vertex positions
    public let normals: [SIMD3<Float>]         // per-vertex normals (same count)
    public let indices: [UInt32]               // 3 indices per triangle
    public var triangleCount: Int { get }      // indices.count / 3
}
```

Positions and normals are stored in parallel arrays (not interleaved). Normals are derived from `Poly_Triangulation::Normal(i)` when available, or computed from triangle cross-products and normalized by accumulation.

---

### `EdgeMeshData`

Wireframe edge polyline data suitable for Metal line rendering.

```swift
public struct EdgeMeshData: Sendable {
    public let vertices: [SIMD3<Float>]     // all polyline vertices
    public let segmentStarts: [Int]          // start index of each edge polyline
    public var segmentCount: Int { get }     // segmentStarts.count
}
```

Segment `i` spans `vertices[segmentStarts[i] ..< segmentStarts[i+1]]` (the array has a sentinel appended internally). Edges are de-duplicated via `TopTools_IndexedMapOfShape`.

---

### `Shape.shadedMesh(deflection:)`

Extracts a triangulated shaded mesh from the shape.

```swift
func shadedMesh(deflection: Double = 0.1) -> ShadedMeshData?
```

- **Parameters:** `deflection` — chord deviation tolerance. Smaller values produce finer meshes (default 0.1).
- **Returns:** `ShadedMeshData`, or `nil` if tessellation fails or produces no triangles.
- **OCCT:** `BRepMesh_IncrementalMesh::Perform` + `TopExp_Explorer(TopAbs_FACE)` + `BRep_Tool::Triangulation` + `Poly_Triangulation`.
- **Example:**
  ```swift
  let box = Shape.box(width: 10, height: 10, depth: 10)!
  if let mesh = box.shadedMesh(deflection: 0.05) {
      print(mesh.triangleCount)   // fine mesh
      // upload mesh.vertices / mesh.normals / mesh.indices to MTLBuffer
  }
  ```

---

### `Shape.edgeMesh(deflection:)`

Extracts wireframe edge polylines from the shape.

```swift
func edgeMesh(deflection: Double = 0.1) -> EdgeMeshData?
```

- **Parameters:** `deflection` — chord deviation tolerance (default 0.1).
- **Returns:** `EdgeMeshData`, or `nil` if extraction fails or produces no vertices.
- **OCCT:** `BRepMesh_IncrementalMesh::Perform` + `TopTools_IndexedMapOfShape` + `BRep_Tool::PolygonOnTriangulation` / `Polygon3D` / `GCPnts_TangentialDeflection` (fallback).
- **Example:**
  ```swift
  if let wf = box.edgeMesh(deflection: 0.1) {
      print(wf.segmentCount)  // one segment per unique edge
  }
  ```

---

### `Shape.shadedMesh(drawer:)`

Extracts a triangulated shaded mesh using a `DisplayDrawer` for tessellation control.

```swift
func shadedMesh(drawer: DisplayDrawer) -> ShadedMeshData?
```

Uses the drawer's deflection type (relative or absolute), deviation coefficient/angle, giving fine-grained tessellation quality per-object rather than a fixed global deflection.

- **Parameters:** `drawer` — a configured `DisplayDrawer` whose properties drive `BRepMesh_IncrementalMesh`.
- **Returns:** `ShadedMeshData`, or `nil` on failure.
- **OCCT:** `BRepMesh_IncrementalMesh(shape, deflection, Standard_False, angle)` with deflection/angle read from `Prs3d_Drawer`.
- **Example:**
  ```swift
  let drawer = DisplayDrawer()
  drawer.deviationCoefficient = 0.0002
  if let mesh = shape.shadedMesh(drawer: drawer) {
      // high-quality tessellation
  }
  ```

---

### `Shape.edgeMesh(drawer:)`

Extracts wireframe edge polylines using a `DisplayDrawer` for tessellation control.

```swift
func edgeMesh(drawer: DisplayDrawer) -> EdgeMeshData?
```

- **Parameters:** `drawer` — a configured `DisplayDrawer`.
- **Returns:** `EdgeMeshData`, or `nil` on failure.
- **OCCT:** `BRepMesh_IncrementalMesh(shape, deflection, Standard_False, angle)` + `BRep_Tool::PolygonOnTriangulation`.
- **Example:**
  ```swift
  if let wf = shape.edgeMesh(drawer: drawer) {
      print(wf.segmentCount)
  }
  ```

---

## FontManager

`FontManager` is a namespace (`enum` with no cases) wrapping `Font_FontMgr`, OCCT's system font registry. Call `initDatabase()` once before querying; subsequent calls refresh the list.

---

### `FontAspect`

Font style/weight variant.

```swift
public enum FontAspect: Int32, Sendable {
    case regular    = 0
    case bold       = 1
    case italic     = 2
    case boldItalic = 3
    public var name: String { get }   // human-readable string via OCCT
}
```

- **OCCT:** `Font_FontAspect`.

---

### `FontAspect.name`

String representation of the font aspect.

```swift
public var name: String { get }
```

- **OCCT:** `Font_FontMgr::FontAspectToString(Font_FontAspect)`.
- **Example:**
  ```swift
  print(FontManager.FontAspect.bold.name)   // "Bold"
  ```

---

### `FontManager.initDatabase()`

Initialises the system font database. Call before querying any font properties.

```swift
public static func initDatabase()
```

Triggers `Font_FontMgr::InitFontDataBase()` and caches the available font list. Subsequent calls refresh the cache.

- **OCCT:** `Font_FontMgr::GetInstance()->InitFontDataBase()` + `GetAvailableFonts()`.
- **Example:**
  ```swift
  FontManager.initDatabase()
  print(FontManager.fontCount)
  ```

---

### `FontManager.fontCount`

The number of system fonts available after `initDatabase()`.

```swift
public static var fontCount: Int { get }
```

- **OCCT:** `NCollection_List<Handle(Font_SystemFont)>::Size()` on the cached font list.
- **Example:**
  ```swift
  let n = FontManager.fontCount
  for i in 0..<n { ... }
  ```

---

### `FontManager.fontName(at:)`

Returns the font family name at the given 0-based index.

```swift
public static func fontName(at index: Int) -> String?
```

- **Parameters:** `index` — 0-based position in the font list (must be less than `fontCount`).
- **Returns:** Font family name string, or `nil` if `index` is out of range.
- **OCCT:** `Font_SystemFont::FontName()` → `TCollection_AsciiString`.
- **Example:**
  ```swift
  FontManager.initDatabase()
  for i in 0..<FontManager.fontCount {
      if let name = FontManager.fontName(at: i) {
          print(name)
      }
  }
  ```

---

### `FontManager.fontPath(at:aspect:)`

Returns the file system path to the font file for the given index and style.

```swift
public static func fontPath(at index: Int, aspect: FontAspect = .regular) -> String?
```

- **Parameters:** `index` — 0-based font index; `aspect` — the desired style (default `.regular`).
- **Returns:** Absolute file path string, or `nil` if the font has no file for that aspect or the index is out of range.
- **OCCT:** `Font_SystemFont::FontPath(Font_FontAspect)` → `TCollection_AsciiString`.
- **Example:**
  ```swift
  if let path = FontManager.fontPath(at: 0, aspect: .bold) {
      print(path)  // e.g. "/System/Library/Fonts/Helvetica-Bold.ttc"
  }
  ```

---

### `FontManager.fontHasAspect(at:aspect:)`

Tests whether the font at the given index has a specific style variant available.

```swift
public static func fontHasAspect(at index: Int, aspect: FontAspect) -> Bool
```

- **Parameters:** `index` — 0-based font index; `aspect` — the style to check.
- **Returns:** `true` if a file exists for that aspect.
- **OCCT:** `Font_SystemFont::HasFontAspect(Font_FontAspect)`.
- **Example:**
  ```swift
  if FontManager.fontHasAspect(at: 0, aspect: .boldItalic) {
      let path = FontManager.fontPath(at: 0, aspect: .boldItalic)
  }
  ```

---

### `FontManager.allFontNames`

All available system font family names as a `[String]`.

```swift
public static var allFontNames: [String] { get }
```

Pure-Swift: iterates `0..<fontCount` collecting `fontName(at:)` results. Fonts whose name cannot be decoded are silently skipped.

- **Example:**
  ```swift
  FontManager.initDatabase()
  let names = FontManager.allFontNames
  let hasHelvetica = names.contains("Helvetica")
  ```
