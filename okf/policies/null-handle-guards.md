---
type: policy
title: Null handle and null shape guards in the bridge
description: A bridge function that takes an OCCT handle or a TopoDS_Shape guards the handle, not just the pointer, wherever the OCCT entry point dereferences it. The guard is required only where measured to be needed, returns the function's existing refusal, and the gate that enforces it has known blind spots that a new shape must teach it in the same PR.
tags: [policy, bridge, occt, crashes, gates, agents]
timestamp: 2026-09-07
---

# Null handle and null shape guards in the bridge

`python3 Scripts/check-null-handle-guards.py` enforces everything below, exits 1 on an unguarded
site, and its `--self-test` proves both failure modes (an unguarded site reported, a guarded one
not). CI runs both in `gate-scripts`, a required check on `main`, so an unguarded site blocks the
merge. Until #625 they were run by nothing at all, and the instruction described a gate that
existed only as prose.

## Geometry handles (#478, #556, #618)

If a bridge function takes an `OCCTCurve3DRef` / `OCCTCurve2DRef` / `OCCTSurfaceRef`, guard the
handle as well as the pointer:

```objc
if (!x || x->curve.IsNull()) return <the fallback the catch below uses>;
```

Checking only the pointer says nothing about the handle, and 36 of the 57 OCCT entry points this
bridge passes such a handle into dereference it unconditionally, an uncatchable signal that
`catch (...)` cannot absorb.

**The guard is required only where the OCCT call actually needs it.** `GeomLib_Tool::Parameter`
returns false; `GeomAdaptor_Surface` and `Approx_SameParameter` raise a catchable
`Standard_Failure` the surrounding `catch (...)` already turns into the same fallback. Measure
against `Scripts/repro/556-null-handle-guard-sweep` before adding one; a guard on a call that copes
is noise, and the script's `ALLOWED` table records each such site with its measured reason.

The handle does not have to be spelled `x->curve` to reach OCCT. This bridge also reaches it
through a `reinterpret_cast`/`static_cast`/C-style cast, a pointer alias, a handle alias, and a
shared bridge helper. The checker handles those four, which are the four the tree uses (#618); a
hand audit that greps for `->curve` handles none of them.

## `TopoDS_Shape` (#1026, #1035)

If the function takes an `OCCTShapeRef`/`OCCTWireRef`/`OCCTEdgeRef`/`OCCTFaceRef`, the pointer test
is again not enough, because `Shape.nullified` is a public property returning a wrapper around a
null `TopoDS_Shape`. The rule is narrower than the handle one. A null `TopoDS_Shape` is safe to
copy, compare, cast with `TopoDS::Edge` and walk with `TopExp` (PR #1027 measured 345 cast sites
and found none defective), and unsafe on two things:

1. **The ten members that dereference `myTShape` with no null test of their own**: `ShapeType()`,
   the eight flag accessors (`Free`, `Locked`, `Modified`, `Checked`, `Orientable`, `Closed`,
   `Infinite`, `Convex`, getter and setter alike) and `EmptyCopy()`. `NbChildren()` is the one OCCT
   guards itself. The guard is `if (!occtShapeIsPresent(x)) return <fallback>;` or, where a type
   test follows, `if (!occtShapeIsType(x, TopAbs_T)) return <fallback>;`, both `inline` in
   `OCCTBridge_Internal.h`.
2. **An OCCT entry point that dereferences the shape for you** (#1035).
   `Scripts/repro/1035-unwrap-guard/repro_1035.mm` measured 61 of them and 17 crash uncatchably,
   including all of `BRep_Tool::Curve`/`Surface`/`Tolerance`/`CurveOnSurface`, the
   `BRepAdaptor_Curve` constructors and `ShapeFix_Shape::Perform`, while `TopExp`, the four
   `BRepAlgoAPI` booleans, `BRepBndLib::Add`, `BRepMesh_IncrementalMesh` and 36 more cope. **The
   cast is not the end of the chain**: `TopoDS::Edge` is written `theShape.IsNull() ? false : ...`,
   so it passes a null through and the crash lands one frame further out, which is why a census of
   cast sites came back clean while the operations built on them still died. The gate's
   `SHAPE_DEREF_RECEIVERS`/`SHAPE_DEREF_QUALIFIED`/`SHAPE_DEREF_CTORS` are that measured list, and
   it walks outward through the `TopoDS::` casts to reach them; an entry is a probe from that
   sweep, never a guess. The sweep covers 61 of roughly 200 distinct entry points, so the tail is
   real.

The same script enforces both as a third walk with its own `SHAPE_ALLOWED` table; its fixtures are
the `S*` ones.

## What the guard returns

**The refusal the function already gives a wrong-typed input, never a value that reads as a
measurement** (#726). All forty-two of #1026's sites and all seventy-two of #1035's had one, so
none needed inventing. `Shape.isEmptyShape` is what a caller uses to tell a null shape from a real
negative.

## The checker's blind spots

Four alias shapes is a fact about this tree, not a closed set. The checker is still blind to
`(*cast).field`, a reference-to-wrapper alias, an `IsNull()` whose result is discarded or does not
dominate the use, a negated guard, `extern "C"` on the definition line (which hides the whole
function from its parser), and a helper that guards only some paths; and it would wrongly report
`Handle(Geom_Curve) w(wrapper->curve);` constructor-init syntax. None appears today. If you write
one, teach the checker the shape in the same PR. An `ALLOWED` entry is keyed `(file, function)`
with no argument index and no re-validation, so it exempts every argument of that function and
every later change to it.

**It cannot catch a structural guard on a `TDF_Label`** (#1022/#1030), measured rather than
assumed: all three walks key on a parameter's declared type, `OCCTDocumentRef` is in neither
`WRAPPERS` nor `SHAPE_WRAPPERS`, and every guard path it recognises bottoms out in a literal
`IsNull()`. A guard of that shape is reviewed by hand.
