---
title: Threads
parent: Cookbook
nav_order: 2
---

# Threads

OCCT ships no "thread feature" — a screw thread is a *composite* feature with no single kernel op.
OCCTSwift provides one on `Shape`: **`threadedShaft`** (external) and **`threadedHole`** (internal),
producing real helical ISO-68 / Unified V-form geometry (60° included flank angle, truncated crest
and root per the standard).

For the common case — a plain cylinder coaxial with the axis — `threadedShaft` **builds the threaded
rod directly, with no boolean** ([#213](https://github.com/gsdali/OCCTSwift/issues/213)): the thread
cross-section (a "cam": root arc → flank → crest arc → flank) is lofted along the helix with
`ruled=false`, giving a **smooth, BRepCheck-valid** solid of a handful of BSpline faces (not hundreds
of facets), with any unthreaded margin closed by sewing. Because the kernel's boolean is never
invoked, the result is orientation-robust where a cut-the-cutter approach is faceted or fails.

OCCT C++ reference: the [bottle tutorial — "Building the Threading"](https://dev.opencascade.org/doc/overview/html/occt__tutorial.html)
(`/open-cascade-sas/occt` on context7).

## A threaded shaft

Cut an M12×1.75 external thread into a Ø12 shank — 18 mm of thread on a 24 mm rod:

```swift
guard let shank = Shape.cylinder(radius: 6, height: 24) else { return }
let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)
guard let threaded = shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                         spec: spec, length: 18) else { return }
// threaded.isValid == true; ~9 faces (smooth), crest at the nominal radius (6 mm)
```

<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer/dist/model-viewer.min.js"></script>

<table>
<tr>
<td align="center"><model-viewer src="models/threads-shaft.glb" poster="images/threads-shaft.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:300px;height:380px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>threadedShaft</code> — M12×1.75</td>
</tr>
</table>

<sub>🖱️ Drag to orbit · scroll to zoom · auto-rotating. The static render shows until the 3D model loads. (Model exported straight from the snippet above via `Exporter.writeGLTF`.)</sub>

### Measuring the envelope — use the *optimal* box

The smooth thread is a BSpline solid, so its default axis-aligned `bounds` is the **control-pole
hull** and overshoots the real surface by ~13% — a pole artifact, *not* a bulge. For the true extent
(the crest sits exactly at the nominal radius), use `boundingBoxOptimal()`:

```swift
threaded.bounds.max.x               // ~6.8 — pole hull, misleading
threaded.boundingBoxOptimal()?.max.x // ~6.0 — the real crest radius (= nominal/2)
```

## Specs from a string

`ThreadSpec.parse` reads the usual designations — metric `M…x…` and Unified `…-… UNC/UNF` (with the
coarse-pitch table for a bare metric diameter):

```swift
ThreadSpec.parse("M5x0.8")     // .iso68,   Ø5,    pitch 0.8
ThreadSpec.parse("M10")        // .iso68,   Ø10,   pitch 1.5  (coarse-pitch table)
ThreadSpec.parse("1/4-20 UNC") // .unified, Ø6.35, pitch 1.27 (25.4/20)
ThreadSpec.parse("3/8-16")     // .unified, Ø9.525, pitch 1.5875
```

Key derived dimensions (all per ISO-68) are available on the spec:

```swift
let m12 = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)
m12.theoreticalDepth   // H  = pitch·√3/2
m12.cutDepth           // 5H/8 — practical truncated depth
m12.minorDiameter      // nominal − 2·cutDepth
m12.halfFlankAngle     // π/6 (30° → 60° included)
```

## Thread forms

`ThreadForm` covers the common standards — set it on the `ThreadSpec`:

| Form | `ThreadForm` | Angle / shape |
|---|---|---|
| Metric M / Unified (UNC, UNF, SAE, metric-fine) | `.iso68` / `.unified` | 60° V (the standard is just a pitch) |
| Whitworth (BSW) / BSP parallel (G) | `.whitworth` / `.bspParallel` | 55° |
| ACME / metric trapezoidal (Tr) | `.acme` / `.trapezoidal` | 29° / 30° trapezoid (lead screws) |
| Square | `.square` | 0° walls |
| Buttress | `.buttress` | asymmetric 7° / 45° |
| Knuckle / round | `.knuckle` | rounded |
| NPT / BSPT (tapered pipe) | `.nptTapered` / `.bsptTapered` | 60° / 55° on a 1:16 taper |

```swift
// An ACME lead-screw thread.
let acme = ThreadSpec(form: .acme, nominalDiameter: 14, pitch: 3)
let leadScrew = stock.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                    spec: acme, length: 40)
```

<table>
<tr>
<td align="center"><model-viewer src="models/threads-acme.glb" poster="images/threads-acme.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:220px;height:280px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>.acme</code> (29°)</td>
<td align="center"><model-viewer src="models/threads-square.glb" poster="images/threads-square.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:220px;height:280px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>.square</code></td>
<td align="center"><model-viewer src="models/threads-buttress.glb" poster="images/threads-buttress.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:220px;height:280px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>.buttress</code> (7°/45°)</td>
</tr>
</table>

External threads on a cylinder use the smooth, valid direct build for every form; internal threads
(`threadedHole`) cut a smooth helical cutter into the wall (also valid). Non-cylinder external targets
and the tapered pipe forms use a robust faceted cut.

### Specs from a designation

`ThreadSpec.parse` reads the standard designations across forms:

```swift
ThreadSpec.parse("Tr40x7")      // .trapezoidal, Ø40, pitch 7  (LH: "Tr40x7LH")
ThreadSpec.parse("1.5-4 ACME")  // .acme,        Ø38.1, pitch 6.35
ThreadSpec.parse("G1/2")        // .bspParallel, Ø20.955, 14 TPI
ThreadSpec.parse("R3/4")        // .bsptTapered  ("Rc…" for the parallel-internal/taper pair)
ThreadSpec.parse("W1/2")        // .whitworth    (also "1/2 BSW")
ThreadSpec.parse("1/2-14 NPT")  // .nptTapered
```

(Metric `M…`, Unified `…-… UNC/UNF`, fractional `3/8-16` still parse as before.)

## Threading with a custom shape

Beyond the standard forms, thread a cylinder with **any** cross-section by supplying a
`ThreadProfile` — a normalized tooth outline over one pitch (`axial` 0…1 along the pitch, `depth` 0
at the crest/major radius … 1 at the root/minor radius). It builds via the same smooth direct path.

```swift
// An asymmetric sawtooth tooth.
guard let profile = ThreadProfile(vertices: [
    .init(axial: 0.0, depth: 1), .init(axial: 0.1, depth: 1),   // root flat
    .init(axial: 0.5, depth: 0), .init(axial: 0.6, depth: 0),   // up to a crest flat
    .init(axial: 0.9, depth: 1), .init(axial: 1.0, depth: 1),   // back down to root
]) else { return }
let spec = ThreadSpec(customProfile: profile, nominalDiameter: 12, pitch: 2, cutDepth: 1)
let custom = stock.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                 spec: spec, length: 16)
```

`ThreadProfile` validates the outline (periodic, spans a crest and a root) and is `Codable`, so a
custom form round-trips through JSON.

## A threaded hole

`threadedHole` taps the wall of an existing bore. It's cut with the boolean path — but because an
interior helix is cut into a *thick wall* (not a thin shaft), OCCT's boolean handles a **smooth**
helical cutter robustly, so the internal thread comes out smooth and BRepCheck-valid. Pass the
*solid with the bore already in it*:

```swift
guard let outer = Shape.cylinder(radius: 12, height: 16),
      let bore  = Shape.cylinder(radius: 6,  height: 16),
      let block = outer.subtracting(bore) else { return }   // an annulus
let tapped = block.threadedHole(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                spec: ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75),
                                depth: 14)
// tapped?.isValid == true; tapping only adds material toward the axis (outer Ø unchanged)
```

Because the body is just *any solid with a bore*, you can tap nuts of any shape — a hex prism
(extruded hexagon), a wing nut (body + wings), or a lead-screw nut. The pieces below are built from
the snippets on this page (`Wire.polygon` → `Shape.extrude` for the hex, `union` for the wings,
`.square` thread for the lead screw, and a `pipeShell` coil — see [Helices & Springs](helices.md) —
for the anti-backlash spring):

<table>
<tr>
<td align="center"><model-viewer src="models/threadedhole-nut.glb" poster="images/threadedhole-nut.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:230px;height:200px;background:#eef1f5;border-radius:6px"></model-viewer><br>ISO M12 <b>hex nut</b></td>
<td align="center"><model-viewer src="models/threadedhole-wingnut.glb" poster="images/threadedhole-wingnut.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:250px;height:200px;background:#eef1f5;border-radius:6px"></model-viewer><br>3/8-16 UNC <b>wing nut</b></td>
<td align="center"><img src="images/threadedhole-leadscrew.png" width="200" style="background:#eef1f5;border-radius:6px"><br>Square <b>lead screw</b> + anti-backlash nut & spring</td>
</tr>
</table>

<sub>🖱️ The nut and wing nut are interactive (drag to orbit). The lead-screw assembly — a square-thread
screw, a hex half-nut, and a compression spring that pushes the split nut apart to take up backlash —
is a static render of a 4-part assembly.</sub>

## Multi-start and handedness

`starts` interleaves N thread starts (lead screws, fast-advance fasteners); `leftHanded` flips the
helix. Multi-start and left-handed threads use the boolean cut path:

```swift
let leadScrew = ThreadSpec(form: .iso68, nominalDiameter: 16, pitch: 2, leftHanded: true)
let shaft = rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                              spec: leadScrew, length: 40, starts: 2)
```

## Runout

How the thread terminates where it meets the unthreaded shank:

```swift
// .none (default) — hard stop; .filleted — blend the last turns; .tapered — fade depth to zero.
rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec,
                  length: 18, runout: .filleted(radius: 0.4))
```

## See also

- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
- Concepts (B-Rep topology, handles): [`occt-concepts.md`](../occt-concepts.md)
- Why smooth threads can't be booleaned, and how the direct build works: [CHANGELOG v1.5.3](../../CHANGELOG.md).
