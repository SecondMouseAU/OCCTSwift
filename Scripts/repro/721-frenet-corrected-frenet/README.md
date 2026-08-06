# #721: could not reproduce the reported Frenet/corrected-Frenet divergence

`Wire.helix(radius: 10, pitch: p, turns: 3)` swept with a circular profile of radius 1.5. The issue
reports `.frenet`'s volume barely moving across a 30x pitch change (ratio to textbook 1.000, 0.998,
0.982, 0.902) and `.correctedFrenet` diverging non-monotonically (1.005, 1.073, 1.270, 0.814).

**This probe, and an independent `Shape.pipeShell` reproduction, could not reproduce either pattern.**
Every profile construction tried gives `.frenet` == `.correctedFrenet` to 5-6 significant figures:
sometimes both matching the textbook Pappus volume, sometimes both wrong together, but never
*differing from each other* the way the issue reports. See "What was tried" below.

```bash
clang++ -std=c++17 -ObjC++ -w -O2 \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/721-frenet-corrected-frenet/occt_721_probe.mm -o /tmp/occt_721_probe
/tmp/occt_721_probe
```

## What was verified clean

1. **`helix.length` is right.** A 40,000-panel Gauss-Legendre reference against
   `BRepAdaptor_CompCurve::D1` agrees with the closed-form `turns * 2*pi*sqrt(R^2 + (pitch/2*pi)^2)`
   to 3e-5 absolute at every pitch tested, ruling out a #603-class arc-length error as a contributor.
   The issue's own "textbook" column is trustworthy.

2. **`GeomFill_Frenet::D0`, evaluated directly** on the wire's own per-edge curves (replicating
   `BRepFill_Edge3DLaw`'s exact construction: a fresh `GeomAdaptor_Curve` per spine edge, matching
   `Sources/OCCTBridge/src/OCCTBridge_Modeling.mm`'s `occtPipeShellSetMode`/`BRepFill_PipeShell::Set`
   call path), computes a mathematically correct, pitch-**tilted** trihedron. `BiNormal`'s
   axis-component matches the closed-form `cos(pitchAngle) = R / sqrt(R^2 + (pitch/2*pi)^2)` to 4+
   significant figures at every sampled parameter (Part 3 of the probe). Orthogonality
   (`T.N`, `T.B`, `N.B`) holds to 1e-17..1e-32 everywhere sampled. This rules out a defect in the core
   curvature-vector computation for this curve family (a `Geom_BSplineCurve`, degree 8, one per full
   2*pi turn, see below).

3. **A correctly-built sweep shows zero measurable Frenet/corrected-Frenet divergence, at every
   pitch tested (1, 4, 12, 30), matching the textbook volume to ~2e-6 relative.** Built three
   independent ways: a hand-rolled `BRepOffsetAPI_MakePipeShell` call (Part 1 of this probe), and
   two separate `Shape.pipeShell` calls (one orienting the profile via the wire's first edge's own
   `Curve3D.d1(at:)`, one via the top-level `Wire.point(at:)`/`Wire.tangent(at:)`). All three give
   the same answer, and match under both `OCCTSWIFT_LOCAL=1` and the pinned `v2.0.0-kernel.1`
   release (`env -u OCCTSWIFT_LOCAL`). This directly confirms the issue's own theoretical claim
   (rotation about tangent is a symmetry for a circular profile) rather than contradicting it.

## A real, separate defect found along the way (does not explain the volume report)

`HelixBRep_BuilderHelix`/`HelixGeom_BuilderHelix` (`Libraries/occt-src/.../TKHelix/...`) always split
a `turns`-turn helix into exactly `turns` edges: one `Geom_BSplineCurve` per full 2*pi turn (for a
cylindrical helix, turns 2..N are literal Z-translated copies of turn 1's curve). Confirmed: `turns:
3` produces a wire with exactly 3 edges, each `range=[0, 2*pi]`, degree 8, 16 poles.

`BRepFill_Edge3DLaw` (`Libraries/occt-src/.../BRepFill/BRepFill_Edge3DLaw.cxx:34`) constructs an
**independent** trihedron-law instance per spine edge (`Law->Copy()` then `SetCurve(perEdgeAdaptor)`
in a loop over `BRepTools_WireExplorer`). `GeomFill_CorrectedFrenet::Init()`
(`GeomFill_CorrectedFrenet.cxx:364`) resets its accumulated twist-angle reference (`startAng = 0`,
matched to the LOCAL Frenet normal at that edge's own first parameter) with no memory of the
accumulated correction at the end of the previous edge.

Measured directly (Part 3 of the probe, pitch=4): `Normal`'s axis-component jumps from **-0.4004**
at the end of turn 1 (`u=6.2832`) to **0.0000** at the start of turn 2 (`u=0.0000`), a genuine ~0.4
rad discontinuity (pitch=30 shows the same effect, -0.3176 to 0.0000), reproduced at every pitch
tested, not floating-point noise (compare `GeomFill_Frenet`'s own `N.axis`, which is continuous
(0.0000 to 0.0000, both ends the same point mod one full turn) across the same boundary).

By the issue's own symmetry argument, a rotation-about-tangent discontinuity should be volume-neutral
for a *circular* profile, and that is exactly what was measured (item 3 above shows no volume effect).
It would **not** be neutral for an asymmetric profile (e.g. `Wire.rectangle`) swept with
`.correctedFrenet` along any multi-turn helix, where it would produce a visible twist/kink at each of
the `turns - 1` internal edge boundaries. Worth its own issue; not filed as one yet since it has no
measured caller-visible consequence beyond the mechanism itself.

## What was tried, and whether it reproduced a Frenet/corrected-Frenet DIVERGENCE

All at r=10, turns=3, wireRadius=1.5. "ratio" is volume / textbook, in pitch order (1, 4, 12, 30).
Values from `Shape.pipeShell`, cross-checked against this probe's direct
`BRepOffsetAPI_MakePipeShell` calls where noted. "nil" means `Shape.volume` returned `nil` (the
built shape had `solids.count == 1, isValid == true` but a negative raw volume: an
inside-out/inverted solid, not the fabricated-zero case of #605/#609).

| profile construction | `.frenet` ratio | `.correctedFrenet` ratio | frenet vs corrected |
|---|---|---|---|
| **issue's own reported table** | 1.000, 0.998, 0.982, 0.902 | 1.005, 1.073, 1.270, 0.814 | **differ, non-monotonic** |
| tangent-oriented, at the true spine start (3 independent methods, `withContact/withCorrection: false`) | 1.0000, 1.0000, 1.0000, 1.0000 | 1.0000, 1.0000, 1.0000, 1.0000 | **agree**, match textbook |
| `Wire.circle(radius: 1.5)`, untouched, at the ORIGIN (10 units from the spine), Z-normal | 0.0159, 0.0635, 0.1876, 0.4309 | 0.0159, 0.0635, 0.1876, 0.4309 | agree |
| same shape, but placed exactly ON the spine's start point (Z-normal, still not tangent) | 0.0159, 0.0635, 0.1876, 0.4309 | nil, 0.0131, 0.2059, 0.3841 | **differ** |
| same (at origin), `withContact: true, withCorrection: false` | 0.0159, 0.0635, 0.1876, 0.4309 | 0.0135, 0.0560, 0.1903, 0.4239 | **differ** |
| same (at origin), `withContact: true, withCorrection: true` | 0.8500, 0.8506, 0.8553, 0.8778 | 0.8524, 0.8860, **1.0194**, 0.9871 | **differ, non-monotonic** |
| same (at origin), `withCorrection: true` (no contact) | 0.00025, 0.0040, 0.0352, 0.1857 | 0.0162, 0.2398, **1.1292**, 0.9140 | differ, but both far from a plausible tube |
| tangent-oriented, but left at the origin (not translated to the spine) | nil, nil, 0.0352, 0.1857 | 0.0162, 0.2398, 1.1292, 0.9140 | differ, degenerate |
| profile built once from pitch=1's own tangent, reused unchanged across all four pitches | 1.0000, 0.9989, 0.9851, 0.9092 | 1.0000, 0.9989, 0.9851, 0.9092 | agree |

Two things stand out. First, **exact profile placement decides whether the two trihedron laws agree
at all**: the identical (wrong) Z-normal orientation gives `.frenet == .correctedFrenet` when the
profile starts 10 units from the spine (at the origin), but a real, non-noise divergence when the
*same* orientation is placed with zero distance from the spine instead. Automatic section placement
(`BRepFill_SectionPlacement`, `Libraries/occt-src/.../BRepFill/BRepFill_SectionPlacement.cxx`)
evidently takes a different path depending on that distance, in a way this investigation did not
fully characterize. Second, `withContact: true, withCorrection: true` on a naive flat profile is the
only construction tried whose *shape* qualitatively resembles the issue's own `.correctedFrenet`
column: rising through pitch 1/4/12 (0.852, 0.886, 1.019) then dropping at pitch 30 (0.987),
the same rise-then-fall shape as the issue's 1.005, 1.073, 1.270, 0.814, without matching its
magnitude.

None of the placements tried reproduce the issue's own numbers, or its `.frenet` column's signature
(ratios matching `cos(pitchAngle) = R / sqrt(R^2 + (pitch/2*pi)^2)` to 4 significant figures, and
absolute volumes matching `pi * wireRadius^2 * turns * 2*pi*R`: a sweep whose extrusion direction is
locked to the helix axis, as if pitch were 0, while still integrating over the true spine length).
Every "wrong orientation, correct location" placement tried here instead lands on the *opposite*
signature, `ratio ~ sin(pitchAngle)` (`pi * wireRadius^2 * turns * pitch`), a profile that stays
fixed in absolute space and never rotates at all.

## Conclusion

No defect was found in `BRepOffsetAPI_MakePipeShell`'s Frenet/corrected-Frenet sweep, in
`GeomFill_Frenet`'s own trihedron computation, or in `Wire.helix`'s length, that reproduces the
issue's reported numbers for a circular profile. A correctly-placed profile shows the two trihedron
laws agreeing exactly, as the issue's own symmetry argument predicts. But profile placement DOES
measurably change whether the two laws agree at all (table above), so the reported divergence is
plausibly a placement difference between however the issue's own `.frenet` and `.correctedFrenet`
measurements were each constructed, rather than a defect in the sweep itself. That specific
placement was not identified, only shown to be plausible and distinct from every placement tried
here. The one confirmed, reproducible defect found along the way
(`GeomFill_CorrectedFrenet`'s per-edge twist-angle reset, above) is real but measured to have no
volume consequence for a symmetric profile, so it does not explain the reported numbers either.
