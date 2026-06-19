---
title: Gordon Surfaces
parent: Cookbook
nav_order: 10
---

# Gordon Surfaces

A **Gordon surface** is built to pass through a *network* of curves — two families that cross to form
a grid: **profiles** (running one way, the U direction) and **guides** (running across them, V). Where
a [loft](lofting-and-sweeps.md) interpolates a single family of sections and a Coons patch fills four
boundary curves, a Gordon surface honours the **whole interior network** — every profile *and* every
guide lies on the result. It's the tool for skinning a hull, a turbine blade, or any panel defined by
a wireframe of feature curves.

OCCTSwift wraps OCCT's `GeomFill_Gordon` (and the lower-level `GeomFill_NetworkSurface`).

## Build from a curve network

Give it ≥ 2 profiles and ≥ 2 guides. The catch is the **grid must close**: each profile must meet
each guide, and shared corners must coincide (within `tolerance`). Here a domed 2×2 network — two
profiles bowed up in X, two guides bowed up in Y, meeting at four coplanar corners:

```swift
// profiles (U): the y = 0 and y = 10 edges, bowed up to z = 3 mid-span
guard let p1 = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(5, 0, 3), SIMD3(10, 0, 0)]),
      let p2 = Curve3D.interpolate(points: [SIMD3(0, 10, 0), SIMD3(5, 10, 3), SIMD3(10, 10, 0)]),
      // guides (V): the x = 0 and x = 10 edges, bowed up to z = 2 mid-span
      let g1 = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(0, 5, 2), SIMD3(0, 10, 0)]),
      let g2 = Curve3D.interpolate(points: [SIMD3(10, 0, 0), SIMD3(10, 5, 2), SIMD3(10, 10, 0)])
else { return }

guard let surface = Surface.gordon(profiles: [p1, p2], guides: [g1, g2], tolerance: 1e-3) else { return }
```

The four corners are shared between a profile and a guide — `p1` starts at `(0,0,0)` where `g1`
starts, and so on. The interior bows (`z = 3` on the profiles, `z = 2` on the guides) need *not* match;
the Gordon construction blends the two families into one B-spline.

To render or sew the result, turn the `Surface` into a face:

```swift
let face = surface.toFace()        // -> Shape?  (a trimmed face over the surface's UV domain)
```

<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer/dist/model-viewer.min.js"></script>

<table>
<tr>
<td align="center"><model-viewer src="models/gordon-dome.glb" poster="images/gordon-dome.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:340px;height:300px;background:#eef1f5;border-radius:6px"></model-viewer><br>A Gordon surface through a 2×2 domed network</td>
</tr>
</table>

## Diagnose a build with `gordonReport`

A network can fail in many specific ways (the curves don't intersect, reparametrization fails, the
result isn't rational-compatible…). `gordonReport` returns the surface **plus** a status and an
`isApproximate` flag instead of a bare `nil`:

```swift
let report = Surface.gordonReport(profiles: [p1, p2], guides: [g1, g2], tolerance: 1e-3)
switch report.status {
case .done:        print("exact:", report.surface != nil, "approx:", report.isApproximate)
case .invalidInput, .intersectionFailed, .compatibilityFailed:
    print("network problem:", report.status)
default:           print("build failed:", report.status)
}
```

By default the build is **exact-only** — it returns no surface if it can't interpolate the network
exactly. Set `allowApproximateFallback: true` to accept a sampled B-spline approximation when the exact
construction fails (the result is then flagged `isApproximate`):

```swift
let r = Surface.gordonReport(profiles: [p1, p2], guides: [g1, g2],
                             allowApproximateFallback: true)
// r.surface may be non-nil with r.isApproximate == true
```

## The lower-level network builder

`networkSurface` exposes OCCT's raw `GeomFill_NetworkSurface` and returns its own status. It's pickier
than `gordon` — it requires the curves' knot structures to line up, so a network that `gordon` handles
can still come back `.knotAlignmentFailed` here:

```swift
let (surface, status) = Surface.networkSurface(profiles: [p1, p2], guides: [g1, g2], tolerance: 1e-3)
if status != .done { print("network builder declined:", status) }   // e.g. .knotAlignmentFailed
```

Reach for `gordon` / `gordonReport` first; drop to `networkSurface` only when you need the low-level
builder's exact behaviour.

## Gordon vs. loft vs. fill

| Want | Use |
|------|-----|
| Skin through one family of section curves | [`Shape.loft`](lofting-and-sweeps.md) |
| Fill between 2 or 4 boundary curves | `Surface.bsplineFill` |
| Interpolate a full **grid** of profile + guide curves | `Surface.gordon` |
| Interpolate a cloud of scattered points | `Surface.plateThrough` |

## See also

- [Lofting & Sweeps](lofting-and-sweeps.md) — single-family skinning.
- [Healing & Validity](healing-and-validity.md) — clean up a sewn surface model.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
