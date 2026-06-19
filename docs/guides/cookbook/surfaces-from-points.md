---
title: Surfaces from Points
parent: Cookbook
nav_order: 11
---

# Surfaces from Points

Given a set of 3D points, OCCTSwift can fit a smooth B-spline `Surface` through them. There are two
cases — and they take different functions:

- **A regular grid** of samples (rows × columns — a height field, a scan) → `Surface.fromPointGrid`
  (`GeomAPI_PointsToBSplineSurface`).
- **A scattered cloud** with no grid structure → `Surface.plateThrough` (`GeomPlate`).

Both return a `Surface`; call `.toFace()` to get a renderable / sewable `Shape`.

<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer/dist/model-viewer.min.js"></script>

## A grid of samples → `fromPointGrid`

When the points form a topological grid, pass them **row-major** (`point[v*uCount + u]`) with the row
and column counts. The result approximates the points within `tolerance`:

```swift
var pts = [SIMD3<Double>]()
let n = 6
for v in 0..<n {
    for u in 0..<n {
        let x = Double(u) * 4, y = Double(v) * 4
        pts.append(SIMD3(x, y, 3 * sin(x * 0.3) * cos(y * 0.3)))   // a wavy height field
    }
}

guard let surface = Surface.fromPointGrid(points: pts, uCount: n, vCount: n,
                                          degMin: 3, degMax: 8,
                                          continuity: 2, tolerance: 1e-3) else { return }
let face = surface.toFace()
```

It **approximates** (not strictly interpolates): tighten `tolerance` to pull the surface closer to the
samples, raise `degMax` for more flexibility. `points.count` must equal `uCount * vCount`.

<table>
<tr>
<td align="center"><model-viewer src="models/points-grid.glb" poster="images/points-grid.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:340px;height:300px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>fromPointGrid</code> — a B-spline through a 6×6 height field</td>
</tr>
</table>

## A scattered cloud → `plateThrough`

When the points have no grid order, the **plate** surface (`GeomPlate_BuildPlateSurface`) builds a
smooth, energy-minimizing B-spline through them — minimum 3 points:

```swift
let points: [SIMD3<Double>] = [
    SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(10, 10, 2),
    SIMD3(0, 10, 1), SIMD3(5, 5, 3),     // a high point in the middle
]
guard let plate = Surface.plateThrough(points, degree: 3, tolerance: 0.01) else { return }
```

`plateThrough` doesn't need any ordering or counts — it's the right tool for an irregular set of
constraint points (probe data, feature points). The trade-off is less direct control over the
parametrization than the grid fit gives you.

## Deform an existing surface to hit target points

If you already have a surface and want to **pull it through** specific positions, the non-linear plate
solver deforms it to meet `(u, v) → target` constraints:

```swift
let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
let bumped = plane.nlPlateDeformed(
    constraints: [(uv: SIMD2(0, 0), target: SIMD3(0, 0, 5))],   // lift the centre to z = 5
    maxIterations: 4, tolerance: 1e-3)
```

This keeps the surface's existing shape and only displaces it to satisfy the constraints — distinct
from fitting a fresh surface to a point set. (A `G0+G1` variant also takes tangent constraints.)

## Which to use

| You have | Use |
|----------|-----|
| Points on a regular **grid** (rows × cols) | `Surface.fromPointGrid` |
| A **scattered** point cloud | `Surface.plateThrough` |
| An existing surface to **pull through** target points | `surface.nlPlateDeformed` |
| A wireframe of **curves** (profiles × guides) | [`Surface.gordon`](gordon-surfaces.md) |

## See also

- [Gordon Surfaces](gordon-surfaces.md) — fit through a network of *curves* rather than points.
- [Meshing & Export](meshing-and-export.md) — `mesh.toShape` lifts a triangle mesh to a B-Rep.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
