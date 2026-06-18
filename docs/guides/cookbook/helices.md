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

A spring is just a **circular profile swept along the helix** — the stock pipe-sweep
(`Shape.pipeShell`, OCCT's `BRepOffsetAPI_MakePipeShell`). Place the profile circle at the helix
start, with its normal along the helix tangent there:

```swift
let r = 10.0, pitch = 4.0, turns = 5.0, wireRadius = 1.5
guard let spine = Wire.helix(radius: r, pitch: pitch, turns: turns) else { return }

// helix tangent at the start point (r, 0, 0): d/dt(r·cos t, r·sin t, pitch·t/2π) at t = 0
let tangent = simd_normalize(SIMD3<Double>(0, r, pitch / (2 * .pi)))
guard let profile = Wire.circle(origin: SIMD3(r, 0, 0), normal: tangent, radius: wireRadius),
      let spring  = Shape.pipeShell(spine: spine, profile: profile,
                                    mode: .correctedFrenet, solid: true) else { return }
// spring.isValid == true; spring.volume ≈ π·wireRadius²·(coil length)
```

<script type="module" src="https://cdn.jsdelivr.net/npm/@google/model-viewer/dist/model-viewer.min.js"></script>

<table>
<tr>
<td align="center"><model-viewer src="models/helices-spring.glb" poster="images/helices-spring.png" camera-controls auto-rotate environment-image="neutral" exposure="1.1" shadow-intensity="1" style="width:320px;height:320px;background:#eef1f5;border-radius:6px"></model-viewer><br><code>pipeShell</code> — circle along a helix</td>
</tr>
</table>

<sub>🖱️ Drag to orbit · scroll to zoom · auto-rotating. The static render shows until the 3D model loads. (Model exported straight from the snippet above via `Exporter.writeGLTF`.)</sub>

Use `mode: .correctedFrenet` — for a coil it keeps the section true (its volume matches `π·r²` times
the coil length). Plain `.frenet` also builds a valid solid but lets the section twist slightly along
the path.

## Conical, tapered, and variable-pitch coils

```swift
// Conical spring — radius varies linearly along the axis.
let cone = Wire.helixTapered(startRadius: 12, endRadius: 4, pitch: 3, turns: 6)

// Variable section — scale the profile with a law along the spine
// (BRepOffsetAPI_MakePipeShell::SetLaw): e.g. a coil whose wire tapers to half thickness.
guard let law = LawFunction.linear(from: 1.0, to: 0.5) else { return }
let varying = Shape.pipeShellWithLaw(spine: spine, profile: profile, law: law)
```

## Why a thread isn't built this way

It's tempting to assume a screw thread is "just another sweep along a helix" — but it isn't, and the
reason is exactly what makes springs easy:

- **A pipe-sweep re-frames the cross-section as it travels the helix** (Frenet trihedron). A circle is
  **rotationally symmetric**, so re-framing changes nothing — the coil comes out clean.
- **A thread's V-profile is asymmetric**, so the same re-framing tilts/distorts it (the thread crest
  wanders off the nominal radius — the old "lead bulge"). And the natural alternative — sweep a V
  cutter and **subtract** it — is unreliable: OCCT's boolean engine can't robustly subtract a smooth
  helical cutter from a cylinder (it under-cuts / no-ops on ~half of all orientations).

So [threads](threads.md) take a different route entirely: `threadedShaft` **builds the threaded rod
directly** — lofting the thread's true cross-section along the helix and sewing on any unthreaded
margin, with no boolean (OCCTSwift [#213](https://github.com/gsdali/OCCTSwift/issues/213)). Springs
ride the stock `pipeShell`; threads needed a bespoke builder.

## See also

- [Threads](threads.md) — the direct, boolean-free thread builder.
- API mapping: [`../../API_REFERENCE.md`](../../API_REFERENCE.md)
- Concepts (B-Rep topology, handles): [`occt-concepts.md`](../occt-concepts.md)
