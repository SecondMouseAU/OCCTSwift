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

## A threaded hole

`threadedHole` taps the wall of an existing bore. The internal form is cut with the robust boolean
path (it's valid, just faceted — there's no smooth-build shortcut for an interior helix), so pass the
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
