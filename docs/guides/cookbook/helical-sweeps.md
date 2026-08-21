---
title: Helical Sweeps
parent: Cookbook
nav_order: 5
---

# Helical Sweeps

Sweeping a profile along a **helix** is how you build worms, augers, screw conveyors, and screw
threads. OCCTSwift gives you two routes, and picking the right one matters:

- `Shape.helicalSweep(profile:…)`: sweeps a profile along an exact analytic helix into a
  **standalone helicoid** (a helical ridge / auger flight). Great on its own; **not** something to
  boolean onto a shaft.
- `Shape.threadedRod(customProfile:…)`: composes a custom tooth profile with a core cylinder
  **directly, with no boolean**, into a smooth, valid, analytic **threaded rod** (worm / screw).

If you only need a standard fastener thread (ISO, Unified, ACME, trapezoidal, square, buttress…),
reach for [`threadedShaft` / `threadedHole`](threads.md) with a `ThreadForm` spec instead, this page
is for **custom** helical profiles.

<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer/dist/model-viewer.min.js"></script>

## A standalone helicoid

`helicalSweep` runs the profile along the helix using an auxiliary-spine framing, so the section
stays roughly radial. A triangular rib over a few turns gives an auger-style flight:

```swift
let R = 3.0, crest = 6.0, pitch = 4.0

// rib profile in the (radial, axial) plane: inner edge at radius R, peak at `crest`.
guard let rib = Wire.polygon3D([SIMD3(R, 0, 0),
                                SIMD3(crest, 0, pitch * 0.4),
                                SIMD3(R, 0, pitch * 0.8)], closed: true),
      let ridge = Shape.helicalSweep(profile: rib,
                                     axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                     radius: R, pitch: pitch, turns: 3) else { return }
// ridge.isValidSolid == true, a valid helicoid on its own
```

<table>
<tr>
<td align="center"><model-viewer src="models/helical-ridge.glb" poster="images/helical-ridge.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:320px;height:320px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>helicalSweep</code>, a standalone helical ridge</td>
</tr>
</table>

> **Framing caveat.** The auxiliary-spine framing isn't *exactly* radial: the result bulges ~10–15%
> beyond the nominal radius for moderate profiles, and for narrow / fine-pitch profiles (e.g. ISO V
> forms) it balloons badly. Use `helicalSweep` for coarse worm/auger ribs, not precise fastener
> threads, and build threads with `threadedRod` / `threadedShaft`, which don't use this path.

## A worm / screw thread from a custom profile

To turn a custom tooth into an actual threaded rod, use `Shape.threadedRod(customProfile:…)`. You give
it a `ThreadProfile`, the tooth cross-section in normalized `(axial, depth)` coordinates: `axial`
runs `0…1` over one pitch, and `depth` runs `0` (crest, at `nominalDiameter / 2`) to `1` (root, at
`nominalDiameter / 2 − cutDepth`). Here a symmetric trapezoidal worm tooth:

```swift
guard let tooth = ThreadProfile(vertices: [
    .init(axial: 0.000, depth: 1), .init(axial: 0.125, depth: 1),   // root half-flat
    .init(axial: 0.375, depth: 0), .init(axial: 0.625, depth: 0),   // flanks up to the crest flat
    .init(axial: 0.875, depth: 1), .init(axial: 1.000, depth: 1),   // flank back down to the root
]),
      let worm = Shape.threadedRod(customProfile: tooth, nominalDiameter: 12,
                                   pitch: 5, cutDepth: 1.8, length: 22) else { return }
// worm.isValidSolid == true, smooth, analytic (a handful of B-spline faces → a small STEP),
// and built with NO boolean, so it's BRepCheck-valid where a boolean compose is not.
```

<table>
<tr>
<td align="center"><model-viewer src="models/helical-worm.glb" poster="images/helical-worm.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:320px;height:320px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>threadedRod</code>, a smooth worm from a custom profile</td>
</tr>
</table>

<sub>🖱️ Drag to orbit · scroll to zoom · auto-rotating. (Models exported straight from the snippets
above via `Exporter.writeGLTF`.)</sub>

The profile must be **smooth-rod-buildable**, a real crest flat and at most two flanks (trapezoidal /
ACME / square / buttress / worm forms qualify). Check with `tooth.supportsSmoothRodBuild`. A
pointed-crest or many-flank (rounded / knuckle) profile returns `false`, and `threadedRod` returns
`nil` rather than silently producing an invalid result.

## Don't boolean a helicoid onto a cylinder

The intuitive way to make a thread, `helicalSweep` a rib, then `union` (or `subtract`) it with a
coaxial cylinder whose surface is coincident with the helicoid's inner edge, **does not work**:

```swift
// ❌ DON'T: OCCT's boolean engine can't resolve the coincident/tangent helicoid faces.
let core = Shape.cylinder(radius: 3, height: 13)!
let bad  = core.union(ridge)            // BRepCheck-INVALID (volume ~right, topology not)
// subtracting a continuous helicoid collapses to volume 0. fuzzyValue / healed() / sewn()
// don't recover either, this is inherent, not a tuning problem (OCCTSwift #225, #213, #181).
```

`threadedRod` exists precisely to avoid this: it lofts the thread region (`ruled:false` cam slices of
the profile, swept along the exact helix) and **sews** it to the core, the boolean engine is never
invoked, so the result is valid and analytic.

## See also

- [Threads](threads.md), standard fastener forms (`threadedShaft` / `threadedHole`, `ThreadSpec`).
- [Helices & Springs](helices.md), `Wire.helix`, sweeping a circle into a coil.
- [Lofting & Sweeps](lofting-and-sweeps.md), the general sweep/loft primitives.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
