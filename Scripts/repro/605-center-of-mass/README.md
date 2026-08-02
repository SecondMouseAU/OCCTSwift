# #605 — `centerOfMass` returned the bounding-box centre

Ground truth for [#605](https://github.com/SecondMouseAU/OCCTSwift/issues/605). `BRepGProp` only,
no bridge and no Swift, so the answers here are OCCT's rather than ours.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/605-center-of-mass/repro_605.mm -o /tmp/repro_605
/tmp/repro_605
```

Recorded output is in `ground-truth-output.txt`.

## What it establishes

A box 10x20x30 whose min corner sits at the origin, moved to (100,200,300), so its true volume
centroid is (105, 210, 315) and a wrong answer of "the origin" is unmistakable. Note this is
`BRepPrimAPI_MakeBox`, which puts the min corner at the origin; OCCTSwift's `Shape.box` centres the
box instead, which is why the Swift regression tests expect (100, 200, 300).

| shape | `VolumeProperties`<br>`OnlyClosed=false` | `VolumeProperties`<br>`OnlyClosed=true` | `SurfaceProperties` | `LinearProperties` |
|---|---|---|---|---|
| closed solid | 6000 @ (105,210,315) | 6000 @ (105,210,315) | 2200 @ same | 480 @ same |
| closed shell, no solid | 6000 @ (105,210,315) | 6000 @ (105,210,315) | 2200 @ same | 480 @ same |
| **open shell (5 of 6 faces)** | **4800 @ (105,210,312.375)** | **0 @ (0,0,0)** | 2000 @ (105,210,313.5) | 420 |
| face | 0 | 0 | 600 @ (100,210,315) | 100 |
| edge | 0 | 0 | 0 | 30 |
| vertex | 0 | 0 | 0 | 0 |

**1. An open shell has no volume, and OCCT says so only if asked.** With the default
`OnlyClosed = false` the divergence integral returns 4800 over a surface that encloses nothing, with
a centroid 2.6 units adrift. Neither number means anything. `OnlyClosed = true` refuses instead
(`BRepGProp.cxx:576`):

```cpp
if (BRep_Tool::IsClosed(Sh)) { volumeProperties(Sh, Props, ...); }
```

OCCT's header says the same in prose: "S must be exempt of any free boundary. Note that these
conditions of coherence are not checked by this algorithm, and results will be false if they are not
respected."

`BRep_Tool::IsClosed` computes closedness per shell (every non-degenerate edge shared an even number
of times) rather than reading a cached flag, so a sewn-but-unflagged closed shell still counts. A
closed shell that was never wrapped in a solid counts too: the key is closedness, not
`ShapeType() == SOLID`.

**2. A zero-mass centre of mass is not (0,0,0).** `VolumeProperties` seeds the framework with the
shape's *location* origin:

```cpp
gp_Pnt P(0, 0, 0);
P.Transform(S.Location());
Props = GProp_GProps(P);
```

Measured on a face of the moved box, then moved again by the same vector:

```
face      : mass=0.000000  COM=(100.0000, 200.0000, 300.0000)
moved face: mass=0.000000  COM=(200.0000, 400.0000, 600.0000)
```

So no consumer can defend itself with `if com == .zero`, and no fix can detect "GProp gave up" that
way. `Mass()` is the only sound test.

**3. OCCT never dispatches on dimension.** Checked across the tree:

- Draw has three separate commands, `lprops` / `sprops` / `vprops`; the caller names the measure, and
  `vprops` takes an explicit `c` flag for `OnlyClosed`.
- XDE's `XCAFDoc_Centroid` writer (`XDEDRAW_Props.cxx`), the closest thing OCCT has to "the centre of
  mass of this shape", always calls `VolumeProperties(shape, G, eps, /*OnlyClosed*/ true)`.
- `ShapeFix_FixSmallSolid` hard-wires two named helpers, `ShapeArea` and `ShapeVolume`.

Nothing picks a measure from `ShapeType()`. So the fix exposes one measure per entry point and
returns nil outside its domain, rather than silently switching measures underneath the caller.

**4. A mixed compound has no single answer**, which is the other reason not to dispatch. For a solid
at the origin plus a loose edge out at x=1000, `VolumeProperties` reports the solid alone
(5, 10, 15) and `LinearProperties` reports (9.13, 9.96, 14.94). Each measure is self-consistent; a
dispatcher choosing between them would not be.

## Not an OCCT bug

Every behaviour above is documented and intended. The defect was ours: a bounding-box centroid
substituted for a `BRepGProp` call. Nothing was filed upstream.
