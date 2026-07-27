# OCCTSwift#430/#432 reproducer — `BRepFill_Filling` untrimmed-pcurve SIGSEGV

Standalone, deterministic reproducers for the uncatchable SIGSEGV that `Shape.fill` hit on its own
default parameters (#430, fixed by PR #435) and that `FillingSurface` still hits through its own
independent bridge path (#432, open).

No fixture files and no kernel patch needed: every case builds its geometry from a primitive.

## Root cause

Two upstream defects compound. Both are live in OCCT 8.0.0p1 and in OCCT master.

**1. `BRepFill_Filling::AddConstraints` drops the range it just fetched.**
`BRepFill_Filling.cxx:334-343`, the face-less / non-C0 branch:

```cpp
BRep_Tool::CurveOnSurface(CurEdge, C2d, Surface, loc, f, l);
...
occ::handle<Geom2dAdaptor_Curve> Curve2d = new Geom2dAdaptor_Curve(C2d);   // f, l discarded
```

`f` and `l` are read and never used. For the usual `Geom2d_Line` pcurve the resulting constraint
spans the line's full infinite parameter range (±2e100) instead of the edge's own. Both sibling
branches in the same function trim correctly: the C0 branch uses `BRepAdaptor_Curve` (`:322`), and
the face-carrying branch uses `BRepAdaptor_Curve2d` (`:361`).

**2. `GeomPlate_BuildPlateSurface::Perform` dereferences its own nulled handle.**
`GeomPlate_BuildPlateSurface.cxx:440` nullifies `myGeomPlateSurface` on entry. The
projection-failure recovery branch at `:537` then passes that still-null handle straight into
`GeomPlate_MakeApprox`:

```cpp
myGeomPlateSurface.Nullify();                                             // :440
...
if (!Ok) {
  GeomPlate_MakeApprox App(myGeomPlateSurface, myTol3d, 1, 3, 15 * myTol3d, -1, GeomAbs_C0, 1.3);
  //                      ^ null on every path that reaches here          // :537
```

Defect 1 manufactures a constraint that cannot be projected. Defect 2 turns that failure into a
process kill rather than a `Standard_Failure`. The signal is raised inside OCCT, so the bridge's
`catch (...)` cannot save it.

Neither defect is reachable through the face-carrying `Add(edge, face, order)` overload.

## Why the crash hid for so long

The same call is a silent `nil` on planar geometry and a SIGSEGV on curved geometry, which is
exactly the split between the two reproducers below. `SurfaceFillingTests` only ever exercised
rectangles and polygons at `.c0`, so neither half showed up.

## Reproducers

Compile any of them with (from the repo root, `-g -O0` so the backtrace resolves):

```bash
clang++ -std=c++17 -w -g -O0 \
  -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -L Libraries/OCCT.xcframework/macos-arm64 \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/430-fill-untrimmed-pcurve/<file>.cpp -o /tmp/<file>
/tmp/<file>
```

### 1. [`occt_430_planar_throw.cpp`](./occt_430_planar_throw.cpp) — the non-fatal face

Face-less `Add(edge, GeomAbs_G1)` on a box face's four planar edges.

```
RESULT: threw Standard_Failure("Geom_RectangularTrimmedSurface::U parameters out of range"), catchable, so a clean nil
Process survived.
```

That message is defect 1 surfacing non-fatally: the ±2e100 span is out of the trimmed surface's
range. The caller sees `nil` and no tangency, with no indication anything went wrong. This is the
geometry the documented `FillingSurface` recipe in `docs/reference/GeometrySolvers.md` uses.

### 2. [`occt_432_curved_sigsegv.cpp`](./occt_432_curved_sigsegv.cpp) — the crash

The same face-less `Add(edge, GeomAbs_G1)`, on the open rim of a truncated sphere (same fixture as
`FillingSupportFaceTests.bowl()`). Exits with signal 11:

```
*** CRASH: SIGSEGV, uncatchable, kills the host process ***
2   Plate_Plate::UVBox + 64
3   GeomPlate_MakeApprox::GeomPlate_MakeApprox + 456
4   GeomPlate_BuildPlateSurface::Perform + 1628
5   BRepFill_Filling::Build + 2384
6   BRepOffsetAPI_MakeFilling::Build + 28
```

The backtrace resolves precisely to defect 2: `Plate_Plate::UVBox` called on the null handle passed
at `GeomPlate_BuildPlateSurface.cxx:537`.

This is the exact call the bridge still makes from `OCCTFillingAddEdge` /
`OCCTFillingAddFreeEdge` (`OCCTBridge_Modeling.mm`), which back
`FillingSurface.add(edge:continuity:)` and `add(freeEdge:continuity:)`. PR #435 removed this call
from `Shape.fill`'s path only, so it remains reachable from public API. That is #432.

### 3. [`occt_430_derived_face_fix.cpp`](./occt_430_derived_face_fix.cpp) — the fix and its equivalence check

The same sphere rim, routed through a support face derived from the edge's own pcurve and added
with `Add(edge, face, order)`. `supportFaceFromPCurve()` is a verbatim port of
`OCCTFillingSupportFaceFromPCurve` from PR #435.

```
RESULT: IsDone=1
        cap z-extent = 7.5112 (a flat disc would be ~0)
        G0Error=1.43184e-05 G1Error=1.0434e-06
Process survived.
```

Two results worth keeping:

- **The cap has real z extent (7.5112).** Tangency is genuinely delivered, not degraded to the flat
  disc a `.c0` fill of the same rim would give. A survival-only check would not have caught a silent
  downgrade.
- **`G0Error=1.43184e-05`, `G1Error=1.0434e-06`** match, digit for digit, what PR #435 measured
  against a kernel-patched build (a one-line `Geom2dAdaptor_Curve(C2d, f, l)` override-linked against
  the real archive). The bridge-side workaround is equivalent to fixing the kernel, not an
  approximation of it.

It also establishes that closing #432 is a call-site swap rather than a redesign: nothing here needs
the kernel patched, and the helper already exists in the tree. It is file-`static` in
`OCCTBridge_Healing.mm`, so sharing it with `OCCTBridge_Modeling.mm` means promoting it to
`OCCTBridge_Internal.h`.

## Status

| Issue | What | State |
|---|---|---|
| #430 | `Shape.fill` SIGSEGV on default `.g1` | fixed bridge-side by PR #435 |
| #431 | `BRepOffsetAPI_MakeFilling` ctor args misbound | fixed in PR #435 |
| #432 | `FillingSurface` reaches the same defect | open, reproducer 2 above |
| #433 | `FillingSurface` `.c1`/`.c2` mismapped | open |
| #434 | The two entry points should converge | open |

The kernel patch for defects 1 and 2, and the upstream filing, are not yet done. Defect 1 is a
one-line fix (`new Geom2dAdaptor_Curve(C2d, f, l)`); defect 2 wants a guard on the `!Ok` branch,
since `myGeomPlateSurface` is null on every path that reaches it.
