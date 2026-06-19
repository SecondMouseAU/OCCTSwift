---
title: Lofting & Sweeps
parent: Cookbook
nav_order: 4
---

# Lofting & Sweeps

Most solids that aren't primitives are made by **moving a profile through space**: push a flat
section along a straight line (extrude), spin it around an axis (revolve), drag it down a path
(sweep), or **skin a surface across several sections** (loft). OCCTSwift exposes each as a static
factory on `Shape`; underneath they map to OCCT's `BRepPrimAPI_MakePrism` / `MakeRevol`,
`BRepOffsetAPI_MakePipe` / `MakePipeShell`, and `BRepOffsetAPI_ThruSections`.

All of these are **fallible** — a self-intersecting path or a degenerate section returns `nil` — so
every example unwraps with `guard`.

<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer/dist/model-viewer.min.js"></script>

## Extrude — push a profile along a direction

The simplest sweep: a closed profile pushed a fixed distance. The profile is a `Wire`; the result is
a solid prism.

```swift
guard let profile = Wire.rectangle(width: 20, height: 12),
      let prism = Shape.extrude(profile: profile,
                                direction: SIMD3(0, 0, 1), length: 8) else { return }
// prism.isValid == true; prism.volume == 20 * 12 * 8
```

`Shape.extrude(profile:direction:length:)` takes a *wire*. To extrude an existing solid/face along a
vector instead, use the instance form `shape.extruded(by: SIMD3(0, 0, 8))`, or
`shape.extrudedInfinite(direction:)` for a half-space cutter.

## Revolve — spin a profile around an axis

Sweep a profile through an angle about an axis. Here a rectangular meridian in the XY plane, revolved
around the **Y axis**, makes a cylindrical drum (a full turn by default):

```swift
guard let meridian = Wire.polygon([
    SIMD2(5, 0), SIMD2(7, 0), SIMD2(7, 10), SIMD2(5, 10),
], closed: true),
      let drum = Shape.revolve(profile: meridian,
                               axisOrigin: .zero,
                               axisDirection: SIMD3(0, 1, 0),
                               angle: 2 * .pi) else { return }
```

Pass a smaller `angle` (e.g. `.pi`) for a half-revolution. To revolve an existing shape rather than a
wire, use `shape.revolved(axisOrigin:axisDirection:)`. For a profile given as a `Curve3D` (e.g. a
lathe meridian), `Shape.revolution(meridian:axisOrigin:axisDirection:angle:)` is the curve-based form.

## Sweep — drag a section along a path

`Shape.sweep(profile:along:)` sweeps a section wire down an arbitrary path wire — OCCT's
`BRepOffsetAPI_MakePipe`. Place the section **at the path's start point with its plane square to the
path tangent there** (otherwise an edge-on section sweeps into a degenerate, zero-thickness tube). A
circular section along a quarter-circle path gives a pipe elbow:

```swift
// path: a quarter-circle in the XY plane from (16,0,0) → (0,16,0); its tangent at the
// start is +Y, so the section's normal points along +Y.
guard let section = Wire.circle(origin: SIMD3(16, 0, 0),
                                normal: SIMD3(0, 1, 0), radius: 5),
      let path = Wire.arc(center: .zero, radius: 16,
                          startAngle: 0, endAngle: .pi / 2),
      let elbow = Shape.sweep(profile: section, along: path) else { return }
// elbow.isValid == true
```

You don't, however, need to worry about the section's *sense* relative to the tangent: `sweep`
re-orients the result so the volume is always positive (OCCTSwift
[#170](https://github.com/gsdali/OCCTSwift/issues/170)) — no "point the normal against the tangent"
trick required.

<table>
<tr>
<td align="center"><model-viewer src="models/sweep-pipe.glb" poster="images/sweep-pipe.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:320px;height:320px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>sweep</code> — circle along an arc (elbow)</td>
</tr>
</table>

For sweeping along a **helix** (springs, coils) and for full orientation control
(`.frenet` / `.correctedFrenet` / fixed binormal / auxiliary spine), see
[Helices & Springs](helices.md), which covers `Shape.pipeShell` in depth.

## Loft — skin a surface across sections

Lofting (a.k.a. *thru-sections*, `BRepOffsetAPI_ThruSections`) builds a solid by **skinning across two
or more profile wires you place in space** — there is no path; the surface interpolates the sections
directly. Position each profile in its own plane (here a square base at `z = 0` and a circle at
`z = 12`):

```swift
guard let base = Wire.polygon3D([
    SIMD3(-5, -5, 0), SIMD3(5, -5, 0), SIMD3(5, 5, 0), SIMD3(-5, 5, 0),
], closed: true),
      let top = Wire.circle(origin: SIMD3(0, 0, 12), radius: 4),
      let transition = Shape.loft(profiles: [base, top], solid: true) else { return }
// a square-to-round transition duct
```

<table>
<tr>
<td align="center"><model-viewer src="models/loft-frustum.glb" poster="images/loft-frustum.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:320px;height:320px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>loft</code> — square base → round top</td>
</tr>
</table>

### Ruled vs. smooth

The advanced overload exposes `ruled`: **straight (ruled) surfaces** between sections, or a **smooth
B-spline** blend. Same two squares, two very different skins:

```swift
guard let bottom = Wire.polygon3D([
    SIMD3(-6, -6, 0), SIMD3(6, -6, 0), SIMD3(6, 6, 0), SIMD3(-6, 6, 0),
], closed: true),
      let upper = Wire.polygon3D([
    SIMD3(-3, -3, 10), SIMD3(3, -3, 10), SIMD3(3, 3, 10), SIMD3(-3, 3, 10),
], closed: true) else { return }

let ruled  = Shape.loft(profiles: [bottom, upper], solid: true, ruled: true)   // flat, faceted sides
let smooth = Shape.loft(profiles: [bottom, upper], solid: true, ruled: false)  // curved, blended sides
```

### Loft to a point — cones and tips

Pass `firstVertex` / `lastVertex` to cap a loft at a single point instead of a wire — the classic way
to taper to a tip. A single circle lofted to a point is a cone:

```swift
guard let circle = Wire.circle(radius: 5),
      let cone = Shape.loft(profiles: [circle], solid: true, ruled: true,
                            lastVertex: SIMD3(0, 0, 10)) else { return }
// give BOTH firstVertex and lastVertex for a bicone (vertex–circle–vertex)
```

<table>
<tr>
<td align="center"><model-viewer src="models/loft-cone.glb" poster="images/loft-cone.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:320px;height:320px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>loft</code> — circle to a vertex tip (cone)</td>
</tr>
</table>

## Multi-section sweep — varying section along a spine

When sections **should ride a defining path** rather than float free, use
`Shape.pipeShellMultiSection(spine:profiles:...)` — OCCT's `BRepOffsetAPI_MakePipeShell` with several
profiles. Three coaxial circles of different radius along a straight spine make a vase:

```swift
guard let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 12)) else { return }
let stations = zip([0.0, 6.0, 12.0], [4.0, 2.0, 5.0]).compactMap {
    Wire.circle(origin: SIMD3(0, 0, $0.0), radius: $0.1)
}
guard stations.count == 3,
      let vase = Shape.pipeShellMultiSection(spine: spine, profiles: stations,
                                             mode: .frenet, solid: true) else { return }
// vase.isValid == true; volume > 0
```

`mode:` controls how each section is framed as it travels the spine (`.frenet`, `.correctedFrenet`,
`.fixed(binormal:)`, `.auxiliary(spine:)`); `withContact` / `withCorrection` move and re-orthogonalise
the profiles onto the spine. To scale a *single* profile by a law along the spine instead of supplying
many, use `Shape.pipeShellWithLaw(spine:profile:law:)` — see [Helices & Springs](helices.md).

<table>
<tr>
<td align="center"><model-viewer src="models/sweep-vase.glb" poster="images/sweep-vase.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:320px;height:320px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>pipeShellMultiSection</code> — varying circles along a spine</td>
</tr>
</table>

<sub>🖱️ Drag to orbit · scroll to zoom · auto-rotating. The static render shows until the 3D model
loads. (Models exported straight from the snippets above via `Exporter.writeGLTF`.)</sub>

## Loft or multi-section sweep — which?

Both skin a surface across several closed sections, but they answer different questions:

- **Loft (`Shape.loft`, `ThruSections`)** — you **place each profile in space yourself** and OCCT
  interpolates between them. There is no path. Reach for it when the sections are arbitrary and you
  want the surface to pass through them directly (transition ducts, blended bodies, point-capped
  tapers).
- **Multi-section sweep (`pipeShellMultiSection`, `MakePipeShell`)** — the sections **ride an explicit
  spine**, and the framing modes control their orientation as they travel. Reach for it when a path
  defines the shape (pipes with varying bore, swept channels, coils).

## See also

- [Helices & Springs](helices.md) — sweeping along a helix, `pipeShell` orientation modes, section laws.
- [Booleans](booleans.md) — combine swept/lofted bodies.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
- Concepts (B-Rep topology, handles): [`occt-concepts.md`](../occt-concepts.md)
