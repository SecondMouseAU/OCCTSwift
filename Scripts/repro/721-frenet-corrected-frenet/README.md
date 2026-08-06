# #721 — `.correctedFrenet`'s reported divergence is a profile-placement artifact

The issue: `.correctedFrenet` pipe sweeps were reported up to 27% off the true volume (and
reversing sign) on `Wire.helix(radius: 10, pitch: p, turns: 3)` swept with a circular profile,
while `.frenet` was exact. Two rounds of measurement on the issue reproduced that table. A prior
investigation branch (`investigate/721-frenet-corrected-frenet`) found a real, separate mechanism —
`BRepFill_Edge3DLaw` gives each of `Wire.helix(turns: n)`'s `n` edges an independent
`GeomFill_CorrectedFrenet`, whose twist-angle law resets to zero at the start of every edge — and
called it volume-neutral for a circular profile, which the second round of measurement's own table
contradicted.

**Neither the per-edge reset nor `.correctedFrenet` is the cause.** The profile in every prior
measurement, and in the already-shipped `Issue598PipeShellFrenetModeTests.cookbookSpringRecipeVolumeInvariant`
test and `docs/guides/cookbook/helices.md`'s "coiled spring" recipe it was modeled on, was placed at
`SIMD3(r, 0, 0)` with tangent `normalize(0, r, pitch/2pi)`, describing that as the helix's own start
point and tangent. It is neither: `Wire.helix`'s default `clockwise: false` reverses the build axis
to -Z, so the wire's actual start is `(-r, ~0, 0)`, descending, and the real tangent's Z-component
has the opposite sign. `.frenet`'s volume happens not to depend on this (`BRepOffsetAPI_MakePipeShell`
re-derives the Frenet trihedron from the spine itself, and a circle has no preferred rotation, so a
profile plane merely consistent with *some* congruent — here, mirrored — helix still sweeps
correctly). `.correctedFrenet`'s per-edge twist-angle law is referenced to the input frame and is
not insensitive to it.

With the profile placed at the spine's own **measured** start point and tangent, `.frenet` and
`.correctedFrenet` agree with each other and with the textbook tube volume to ~1e-6 relative, at
every pitch (1, 4, 12, 30) and turn count (1 through 8, including half-turns — 0 through 7 internal
edge boundaries) tested. The per-edge reset is real (confirmed directly, see probe 1 below) but
volume-neutral, exactly as the issue's own symmetry argument predicts.

## Probes

```bash
clang++ -std=c++17 -ObjC++ -w -O2 \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/721-frenet-corrected-frenet/<file>.mm -o /tmp/probe
/tmp/probe
```

- **`occt_721_boundary_probe.mm`** — the issue's own suggested discriminator ("does a single-edge
  spine show no divergence, with the error scaling with boundary count?"), run first, with the
  profile's origin/tangent **measured** from the actual wire (`BRepAdaptor_CompCurve::D1`). Result:
  no divergence at any turn count (1, 2, 3, 6) at any pitch (4, 12, 30) — contradicting the issue's
  own reproduction using what looked like the same construction. Also instruments
  `GeomFill_CorrectedFrenet::D0` directly against `GeomFill_Frenet::D0` on a single edge (turns=1,
  no boundary at all): confirms a real, large, *smooth* drift within one edge (up to -159° by the
  end of one turn at pitch=30) that costs nothing in swept volume — the smooth-twist/circular-profile
  symmetry argument holding within an edge, independent of any boundary question.
- **`occt_721_boundary_probe2.mm`** — same sweep, profile placed with the issue's own **analytic**
  formula instead of a measured one. This one *does* reproduce the reported divergence pattern
  (rising through pitch=4/turns=6, and at pitch=12 rising to 1.29 then reversing to 0.98 and back —
  an oscillation with period related to edge count). The only difference from probe 1 is how the
  profile is placed, which is what the isolation in probe 3 confirms directly.
- **`occt_721_boundary_probe3.mm`** — isolates which half of the analytic formula's mismatch
  (wrong origin, wrong tangent sign, or both) drives the divergence, at the issue's own worst case
  (pitch=12, turns=3) and the shipped test's fixture (pitch=4, turns=5). Both mismatches together
  (`origin=(+r,0,0)`, `tangent=(0,r,+c)` — the "textbook, as shipped" row) leave `.frenet` exact by
  a mirror-symmetry coincidence but reproduce `.correctedFrenet`'s reported ratios (1.2758, 1.1215)
  almost exactly. Correcting both (`origin=(-r,0,0)`, `tangent=(0,r,-c)`, matching a direct
  measurement) collapses both modes back to 1.0000.

## Where the fix landed

Not the kernel, not the bridge — `Sources/OCCTBridge/src/OCCTBridge_Modeling.mm`'s
`OCCTShapeCreatePipeShellMultiSection` and `OCCTWireCreateHelix` were read line-for-line against
these probes and match exactly; there is nothing to patch there. The fix is:

- `Tests/OCCTModelingTests/Issue598PipeShellFrenetModeTests.swift`'s
  `cookbookSpringRecipeVolumeInvariant` corrected to measure the profile placement instead of
  computing it, and its "must not match" assertion replaced with "must match" (both modes now
  agree); its old construction is kept as a second test,
  `misplacedProfileReproducesIssue721Divergence`, a permanent regression against reintroducing it.
- `Tests/OCCTModelingTests/Issue721CorrectedFrenetPlacementTests.swift` (new): the dense
  pitch/turns sweep with the correct construction, plus a direct instrument confirming the per-edge
  reset is real without affecting volume.
- `docs/guides/cookbook/helices.md`'s "coiled spring" recipe corrected to measure the tangent from
  the wire, and its prose no longer claims `.correctedFrenet` fails to preserve the tube volume.
- `docs/CHANGELOG.md`'s pre-existing #598 entry (still `## Unreleased`) carried the same wrong
  claim (that a circular profile only guarantees agreement on a torsion-free spine); corrected in
  place rather than left to mislead the next reader.
- `Sources/OCCTSwift/Wire.swift`'s `Wire.helix` doc comment gained a note on where the wire
  actually starts under the default `clockwise: false`, and to measure rather than compute that
  point/tangent analytically — the mistake this whole issue traces back to.
