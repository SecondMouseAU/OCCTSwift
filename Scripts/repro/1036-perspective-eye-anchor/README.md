# `.perspective(focus:)` eye anchor and the regime beyond it (#1036)

Three ground-truth probes behind the fix in `OCCTDrawingCreate`
(`Sources/OCCTBridge/src/OCCTBridge_Modeling.mm`). Each replicates the bridge's own projector
construction rather than calling the bridge, so the measurements are of OCCT, not of the wrapper.

Compile each per CLAUDE.md's "Compile a Ground Truth C++ Test":

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1036-perspective-eye-anchor/probe.mm -o /tmp/probe_1036
/tmp/probe_1036
```

| file | question it answers | transcript |
|---|---|---|
| `probe.mm` | what each focus really returns, sign included | `transcript-probe.txt` |
| `guard_probe.mm` | where the bounding-box guard's boundary lands | `transcript-guard.txt` |
| `guard_comment_probe.mm` | what the pre-existing guard comment's own four values do | `transcript-guard-comment.txt` |

## What the projector actually does

`OCCTDrawingCreate` builds `gp_Ax2 projAxis(gp_Pnt(0, 0, 0), viewDir)` unconditionally, and
`HLRAlgo_Projector::Project` (`HLRAlgo_Projector.cxx`) divides by `R = 1 - Z/focus` with `Z` the
point's coordinate in that frame. So the eye is at `focus * viewDir` **from the world origin**, the
picture plane passes through the origin, and magnification is `focus / (focus - Z)`, which is
`focus` over the eye-to-point distance: an ordinary pinhole.

`Z >= focus` puts the point at or behind the pinhole, where no projection onto a plane in front of
it exists. OCCT does not refuse it, it divides anyway.

## probe.mm: the three wrong-answer regimes

Fixture is a 10-unit cube spanning x `[20, 30]` viewed down +Z. The x offset is the point: a
mirrored projection of a **centred** box has the same bounding-box width as a correct one, so only
an off-centre fixture makes the sign visible.

| shape z | focus | projected x | verdict |
|---|---|---|---|
| `[0, 10]` | 50 | `[20.000, 37.500]` | correct |
| `[1000, 1010]` | 50 | `[-1.579, -1.042]` | mirrored through the origin, 19x under-scaled |
| `[0, 10]` | 5.5 | `[-24.444, 20.000]` | eye plane cuts the shape, one half mirrored against the other |
| `[0, 10]` | 10 | `[-1.126e17, 20.000]` | eye exactly on a face, `R` is 0 |
| `[0, 10]` | 10.0001 | `[20.000, 3000030.000]` | correct, and extreme |
| `[1000, 1010]` | 2000 | `[40.000, 60.606]` | correct |

All three bad rows return a real compound with a plausible edge count.

The last block of the probe is the translation-invariance measurement that decided against adding a
caller-controlled eye position: the same cube with the eye 40 units from its near face has
foreshortening ratio 1.25 whether it sits at z `[0, 10]` (half-width 6.25) or z `[1000, 1010]`
(131.25). The anchor costs a uniform scale factor and bends nothing.

## guard_probe.mm: where the boundary lands

The guard bounds the shape's reach along the view direction by the axis-aligned bounding box's
support function, which is an upper bound rather than the exact figure. Measured on a box whose top
face is at z = 10:

| focus | guard | what OCCT returns |
|---|---|---|
| 9.9999 | REJECT | `x [-1999980, 20]`, garbled |
| 10 | REJECT | `x [-1.126e17, 20]` |
| 10.0001 | accept | `x [20, 3000030]`, correct |
| 11 | accept | `x [20, 330]`, correct |

The boundary sits exactly on the garbled/correct transition. The probe also checks a shape far
behind the picture plane (accepted, correctly shrunken and unmirrored), a rotated box, and a sphere,
where the bounding box captures a curved bulge the vertices alone would miss.

## guard_comment_probe.mm: re-measuring the old comment

The `focus > 0` guard's comment cited "focus 0/1e-12/5/15 all return an empty VCompound" on a
100x50x30 box viewed down +Z. Re-measured, **all four claims are true**. The problem was the
inference, not the data: 5 and 15 are positive and pass that test, so they were never evidence for
it. That box is centred, spanning z `[-15, 15]`, so focus 5 and 15 put the eye inside it or on its
face. Those two rows were measuring the straddling case, which the `focus > 0` test never rejected
and the reach guard now does.

This probe exists because the first attempt at correcting that comment replaced a true statement
with a false one (that focus 0 and 1e-12 return a mirrored projection). They return an empty
compound, exactly as originally written.
