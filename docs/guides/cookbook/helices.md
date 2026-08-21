---
title: Helices & Springs
parent: Cookbook
nav_order: 3
---

# Helices & Springs

A helix is the path behind coils, springs, augers, and screw threads. OCCTSwift gives you the helix
both as an analytic **curve** (`Curve3D.circularHelix`) and as a ready-made **wire** (`Wire.helix`,
`Wire.helixTapered`) you can sweep along.

## A helix path

```swift
// As a wire (a sweepable path): radius, pitch (rise per turn), number of turns.
let path = Wire.helix(origin: .zero, axis: SIMD3(0, 0, 1),
                      radius: 10, pitch: 4, turns: 5, clockwise: false)

// Or as an exact analytic curve (Geom-level), for sampling / measurement:
let curve = Curve3D.circularHelix(radius: 10, pitch: 4)
```

## A coiled spring

A spring is just a **circular profile swept along the helix**, the stock pipe-sweep
(`Shape.pipeShell`, OCCT's `BRepOffsetAPI_MakePipeShell`). Place the profile circle at the helix
start, with its normal along the helix tangent there:

```swift
let r = 10.0, pitch = 4.0, turns = 5.0, wireRadius = 1.5
guard let spine = Wire.helix(radius: r, pitch: pitch, turns: turns) else { return }

// Measure the spine's own start point and tangent, don't compute them analytically.
// `Wire.helix`'s default clockwise: false reverses the build axis, so the wire's actual start
// is (-r, ~0, 0), descending, not (r, 0, 0) ascending as a naive right-handed formula would give.
guard let firstEdge = spine.edges().first, let curve = firstEdge.curve3D else { return }
let (origin, tangent) = curve.d1(at: curve.domain.lowerBound)
guard let profile = Wire.circle(origin: origin, normal: simd_normalize(tangent), radius: wireRadius),
      let spring  = Shape.pipeShell(spine: spine, profile: profile,
                                    mode: .frenet, solid: true) else { return }
// spring.isValid == true; spring.volume ≈ π·wireRadius²·(coil length)
```

<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer/dist/model-viewer.min.js"></script>

<table>
<tr>
<td align="center"><model-viewer src="models/helices-spring.glb" poster="images/helices-spring.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:320px;height:320px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>pipeShell</code>, circle along a helix</td>
</tr>
</table>

<sub>🖱️ Drag to orbit · scroll to zoom · auto-rotating. The static render shows until the 3D model loads. (Model exported straight from the snippet above via `Exporter.writeGLTF`.)</sub>

`mode: .frenet` and `mode: .correctedFrenet` both keep the section true to the textbook tube volume
here (`π·wireRadius²` times the coil length, matched to within numerical tolerance and cross-checked
against an independent `PipeShellBuilder` oracle), a circle is rotationally symmetric, so the two
trihedron laws, which differ only by a rotation about the tangent, must sweep the identical solid.
An earlier version of this page claimed `.correctedFrenet` did *not* preserve that volume (~12%
larger); that was a bug in the recipe's own profile placement, not in `.correctedFrenet`, the
snippet above computed the tangent from a formula rather than measuring it from the wire, and got
both the origin and the sign wrong (see the code comment). `.frenet`'s output happened to be
insensitive to that particular mistake; `.correctedFrenet`'s was not. See OCCTSwift
[#721](https://github.com/SecondMouseAU/OCCTSwift/issues/721) for the full investigation, including
a dense sweep across pitch and turn count confirming the two modes agree everywhere once the
profile is placed correctly.

## Conical, tapered, and variable-pitch coils

```swift
// Conical spring, radius varies linearly along the axis.
let cone = Wire.helixTapered(startRadius: 12, endRadius: 4, pitch: 3, turns: 6)

// Variable section, scale the profile with a law along the spine
// (BRepOffsetAPI_MakePipeShell::SetLaw): e.g. a coil whose wire tapers to half thickness.
guard let law = LawFunction.linear(from: 1.0, to: 0.5) else { return }
let varying = Shape.pipeShellWithLaw(spine: spine, profile: profile, law: law)
```

## Why a thread isn't built this way

It's tempting to assume a screw thread is "just another sweep along a helix", but it isn't, and the
reason is exactly what makes springs easy:

- **A pipe-sweep re-frames the cross-section as it travels the helix** (Frenet trihedron). A circle is
  **rotationally symmetric**, so re-framing changes nothing, the coil comes out clean.
- **A thread's V-profile is asymmetric**, so the same re-framing tilts/distorts it (the thread crest
  wanders off the nominal radius, the old "lead bulge"). And the natural alternative, sweep a V
  cutter and **subtract** it, is unreliable: OCCT's boolean engine can't robustly subtract a smooth
  helical cutter from a cylinder (it under-cuts / no-ops on ~half of all orientations).

So [threads](threads.md) take a different route entirely: `threadedShaft` **builds the threaded rod
directly**, lofting the thread's true cross-section along the helix and sewing on any unthreaded
margin, with no boolean (OCCTSwift [#213](https://github.com/gsdali/OCCTSwift/issues/213)). Springs
ride the stock `pipeShell`; threads needed a bespoke builder.

## See also

- [Threads](threads.md), the direct, boolean-free thread builder.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
- Concepts (B-Rep topology, handles): [`occt-concepts.md`](../occt-concepts.md)
