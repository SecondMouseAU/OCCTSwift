# #609 — zero-mass `BRepGProp` results returned as successful answers

Ground truth for [#609](https://github.com/SecondMouseAU/OCCTSwift/issues/609). `BRepGProp` and
`GProp` only, no bridge and no Swift, so the answers here are OCCT's rather than ours. Sibling of
[`605-center-of-mass/`](../605-center-of-mass), which established the two mechanisms; this one
measures what they do to every remaining consumer, and turns up several the issue did not name.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/609-zero-mass/repro_609.mm -o /tmp/repro_609
/tmp/repro_609
```

Recorded output is in `ground-truth-output.txt`.

## What it establishes

A box 10x20x30 whose min corner sits at the origin, moved to (100,200,300), so the true volume
centroid is (105, 210, 315). Note `BRepPrimAPI_MakeBox` puts the min corner at the origin, while
OCCTSwift's `Shape.box` centres the box, which is why the Swift regression tests expect different
coordinates from the table below.

### 1. `OnlyClosed = false` fabricates a volume, and not only for an open shell

| shape | `vol(OnlyClosed=false)` | `vol(OnlyClosed=true)` | verdict |
|---|---|---|---|
| solid | 6000 @ (105,210,315) | 6000 @ (105,210,315) | agree |
| solid, reversed | -6000 | -6000 | agree, and the sign survives `OnlyClosed` |
| closed shell, no solid | 6000 | 6000 | agree, closedness is the key, not `ShapeType()` |
| **open shell (5 of 6 faces)** | **4800 @ (105,210,312.375)** | 0 | fabricated |
| **compound: solid + one loose face** | **6857.14 @ (104.509,210,315)** | 6000 @ (105,210,315) | fabricated |
| compound: solid + loose edge | 6000 | 6000 | agree, an edge contributes nothing either way |
| compound: solid + its reverse | 0 | 0 | a true net zero, see the guard note below |
| cylinder (seam edge) | 1570.796 | 1570.796 | agree, a seam edge is shared twice in one face |
| sphere (degenerate poles) | 1436.755 | 1436.755 | agree, degenerate edges are skipped |
| **unsewn six-face "solid"** | **6000 @ (5,10,15)** | **0** | see 2 |
| the same six faces, sewn | 6000 | 6000 | agree |

The compound row is new here and matters on its own: a loose face in a compound adds 857 to the
reported volume of the solid beside it. `OnlyClosed = true` fixes that too.

Read the `face` row carefully: it is 0 because *this* fixture's first face is the one at x = 0, which
is coplanar with the integration origin and so contributes nothing. A lone face is not generally 0,
which is exactly what the compound row shows, using the same box after it has been moved.

### 2. `IsClosed` is topological sharing, not watertightness

This is the one behaviour change with downstream teeth. `BRepGProp::VolumeProperties(OnlyClosed=true)`
explores shells and admits only those `BRep_Tool::IsClosed` accepts, and that predicate
(`BRep_Tool.cxx:1707`) counts whether every non-degenerate, non-internal edge is shared an even
number of times. Geometric coincidence is not enough:

```
solid                    shell[0] IsClosed=yes  Closed() flag=yes
unsewn 'solid'           shell[0] IsClosed=no   Closed() flag=no
sewn solid               shell[0] IsClosed=yes  Closed() flag=yes
```

Six coincident faces assembled with `BRep_Builder` and wrapped in `BRepBuilderAPI_MakeSolid` report a
correct 6000 today and 0 after the change. Running them through `BRepBuilderAPI_Sewing` first
restores it. Any consumer that builds solids from mesh data without sewing loses its volume, which is
why the fix ships with downstream issues filed first.

`IsClosed` computes rather than reading the cached `Closed()` flag, so a sewn-but-unflagged closed
shell still counts, and a closed shell that was never wrapped in a solid counts too.

### 3. The zero-mass sentinel is the shape's location, and it tracks the shape

```
face (identity loc) : mass=0.0000 com=(0.0000,0.0000,0.0000)
face (moved by loc) : mass=0.0000 com=(100.0000,200.0000,300.0000)
face (moved twice)  : mass=0.0000 com=(200.0000,400.0000,600.0000)
```

`GProp_GProps` seeds itself with `gp_Pnt(0,0,0).Transform(S.Location())`, and `CentreOfMass()` is
`loc + g` with `g` forced to (0,0,0) once `|dim| < 1e-20` (`GProp_GProps.cxx:105`). So the answer is a
plausible point that follows the part around. No consumer can defend itself with `if com == .zero`.

Worth knowing when reading the probe: `BRepBuilderAPI_Transform(shape, trsf, /*copy*/ true)` bakes
the transform into the geometry and leaves the location identity, so it does **not** show this. Only
`TopoDS_Shape::Move`, which is what an assembly instance or a moved import carries, does.

### 4. Everything derived from a zero-mass framework is an artefact

Measured on a face, asked for volume properties:

```
Mass            = 0.000000
MatrixOfInertia = [0 0 0; 0 0 0; 0 0 0]
StaticMoments   = (0, 0, 0)
PrincipalMoments= (0, 0, 0)
GyrationRadii   = (0, 0, 0)
PrincipalAxes   = (0.000,0.000,1.000) (1.000,0.000,0.000) (0.000,1.000,0.000)
HasSymmetryAxis = yes     HasSymmetryPoint = yes
RadiusOfGyration(OZ) = nan   isnan=yes
```

Three of those are worse than a zero:

- **`RadiusOfGyration(A)` is NaN.** `GProp_GProps.cxx:148` is `sqrt(MomentOfInertia(A) / dim)`, with
  no guard at all. `GProp_PrincipalProps::RadiusOfGyration` is guarded (`if (0.0e0 != dim)`), so the
  radii-triple reads 0 while the axis-form reads NaN, from the same framework.
- **The principal axes are unit vectors.** `math_Jacobi` on a zero matrix returns the identity basis,
  so the caller gets three orthonormal directions that describe nothing.
- **The shape claims spherical symmetry.** `HasSymmetryPoint()` is `|i1-i2| <= |i1|*1e-10 && ...`,
  which every zero-moment framework satisfies. Confirmed across shape types:

```
solid                mass=  6000.000 hasSymPoint=no   hasSymAxis=no
face                 mass=     0.000 hasSymPoint=yes  hasSymAxis=yes
edge                 mass=     0.000 hasSymPoint=yes  hasSymAxis=yes
wire                 mass=     0.000 hasSymPoint=yes  hasSymAxis=yes
vertex               mass=     0.000 hasSymPoint=yes  hasSymAxis=yes
```

`OCCTShapeSymmetryAxes` branches on exactly that predicate, so a face, wire, edge or vertex yields
three symmetry axes through the location origin rather than none.

### 5. An open shell's derived quantities are wrong without being zero

```
Mass=4800.0000  HasSymmetryAxis=no HasSymmetryPoint=no  moments=(446045,314045,220000)
RadiusOfGyration(OZ) = 234.884723
```

Nothing here is detectably wrong from the outside. This is the case a `Mass() != 0` test alone does
not catch, and the reason the volume path needs `OnlyClosed = true` as well as a mass check.

### 6. The same integral's *sign* is sound where its magnitude is not

```
solid                  forward=   6000.0000  reversed=  -6000.0000
open shell (5/6)       forward=   4800.0000  reversed=  -4800.0000
```

Reversing a surface negates the flux whether or not the surface is closed. So the `OnlyClosed=false`
integral is worthless as a *measurement* over an open surface and sound as an *orientation signal*
over one.

This is not academic, and it is why `Shape.signedVolume` deliberately keeps the unguarded integral
while `Shape.volume` gets the strict one. `Shape.sweep` normalises an inward-facing pipe through
`orientedForward()` (#170), and a pipe sweep produces an open shell, measured here through the Swift
API:

```
spring: type=Shell solids=0 shells=1 faces=3 volume=nil signed=+
```

Routing `signedVolume` through the strict volume would have made that silently stop normalising, and
the #170 regression test would have kept passing on a different assertion. The full-suite run is what
caught it.

### 7. `GProp_PGProps::AddPoint` throws on a non-positive weight

```
PGProps, no points        : mass=0.0000 com=(0.0000,0.0000,0.0000)
PGProps, weights sum to 0 : THROWS GProp_PGProps::AddPoint: density must be positive
PGProps, zero weight      : THROWS GProp_PGProps::AddPoint: density must be positive
CelGProps, u1==u2         : mass=0.0000 com=(105.0000,200.0000,300.0000)
```

The throw is on the *first* non-positive weight, so it is not a "weights cancelled" condition; a
single zero weight in an otherwise valid set aborts the whole computation. The bridge's `catch (...)`
turns that into mass 0 with a centroid of (0,0,0), which is indistinguishable from a real answer for
a point set centred on the origin.

`GProp_CelGProps` with `u1 == u2` returns mass 0 with a centroid on the curve. That one is **not** a
defect: `CelGProps` computes its centroid analytically rather than accumulating into a framework, so
a valid element measured over an empty range keeps a correct answer, and refusing would discard it.
What *is* a defect is a rejected input: `GProp_LineSegment`'s bridge builds `gp_Dir(gp_Vec(p1, p2))`,
which throws on two coincident endpoints, and the catch turned that into a length of 0 with a centre
of (0,0,0). The distinction was found by a test, not by reading: the first draft of the regression
suite asserted the wrong half of it on the strength of the `u1 == u2` measurement above, and failed.

### 8. The direct `BRepGProp_*` wrappers are milder

```
Vinert(coplanar face) : mass=0.000000 com=(0.0000,0.0000,0.0000)
Sinert(same face)     : mass=100.000000 com=(0.0000,0.0000,0.0000)
```

`BRepGProp_Vinert` integrates the volume between a face and the location point, so a face whose plane
contains that point contributes nothing. The bridge calls `SetLocation(gp_Pnt(0,0,0))` at every one of
these sites, so their zero-mass sentinel really is (0,0,0), unlike the `BRepGProp::` static paths.
Still a missing answer reported as a successful one, but a recognisable one.

## A note on the guard

The guard is `Mass() != 0.0`, matching PR #610, not `> 0` and not a tolerance:

- `> 0` would reject a reversed solid, whose -6000 is the documented job of `Shape.signedVolume`.
- A tolerance would need a scale, and there is no scale-free one. A sliver face with an area of 1e-18
  has a real, if useless, centroid; a zero-mass framework has none at all. The distinction OCCT draws
  is exact zero, and `GProp_GProps::Add` itself uses `|dim| >= 1.e-20` before it will divide.

The one case the guard reads as "no answer" while an answer arguably exists is a compound of a solid
and its own reverse, whose signed volumes cancel to exactly 0. That shape has no meaningful centre of
mass either, so refusing is the right result for the wrong reason.

## Not an OCCT bug

Every behaviour above is documented or plainly intended. OCCT's contract is that the caller checks
`Mass()` and passes `OnlyClosed` when it wants the strict answer; the bridge never did either.
Nothing is filed upstream. The one arguable exception, `GProp_GProps::RadiusOfGyration` dividing by
`dim` with no guard while its `GProp_PrincipalProps` sibling has one, is inconsistent rather than
wrong, and a caller who checked `Mass()` first would never reach it.
