# #1026: a null `TopoDS_Shape` reaching an accessor that dereferences `myTShape`

`Shape.nullified` returns a `Shape` wrapping a null `TopoDS_Shape` by construction
(`OCCTShapeNullified` copies the shape, calls `TopoDS_Shape::Nullify()` on the copy and wraps the
result). **Forty-two** bridge functions then read something off a caller-supplied shape that OCCT
dereferences without a null test, so `box.nullified!.shapeType` was public API to public API with a
SIGSEGV in between.

The issue was filed with **fifteen**, from a census that was blind in three separate ways. The
count and the correction are in
[`../1008-topods-cast-guard/shapetype_census.py`](../1008-topods-cast-guard/shapetype_census.py)'s
own docstring, and the short version is:

| | functions | how it was found |
|---|---|---|
| the census as filed | 15 | `'IsNull()' not in body` |
| the same criterion, guard tied to the ARGUMENT | 22 | seven were silenced by an `IsNull()` on `pcurve`, `wire`, `face`, `result` or `sh` |
| plus local-copy and reference aliases, invisible entirely | 29 | four `OCCTBridge_AIS.mm` dimension functions, `OCCTShapeUpgrade`, two array-element sites |
| plus the eight flag accessors, not just `ShapeType()` | 39 | `TopoDS_Shape.hxx` has eighteen more unguarded `myTShape->` dereferences |
| plus three the gate cannot see, found by probing | 42 | the kernel dereferences the shape for them |

## The mechanism, measured rather than inferred

`TopoDS_Shape::ShapeType()` is

```cpp
TopAbs_ShapeEnum ShapeType() const { return myTShape->ShapeType(); }   // TopoDS_Shape.hxx:140
```

and in 8.0.1 `TopoDS_TShape::ShapeType()` is **not a virtual call**:

```cpp
TopAbs_ShapeEnum ShapeType() const                                     // TopoDS_TShape.hxx:144
{
  return static_cast<TopAbs_ShapeEnum>(myState & Bits_ShapeType_Mask);
}
```

It is a plain read of the packed state word, which sits at offset `0x38` in `TopoDS_TShape`
(`Standard_Transient`'s vptr and refcount, then `NCollection_List<TopoDS_Shape> myShapes`, then
`uint16_t myState`). So the fault is a load from `0x38`, not a vtable dispatch through address 0,
and the kernel's own signal handler prints exactly that:

```
PROBE isValidSolid: about to read
*** Abort *** an exception was raised, but no catch was found.
	... The exception is: SIGSEGV 'segmentation violation' detected. Address 38.
```

The printed address is the corroboration: it is derived from the header's field layout, and it
matches, which is what distinguishes this reading from a plausible one.

An OS signal is not something `catch (...)` can absorb, so the `try`/`catch` most of these
functions carry made no difference.

## `ShapeType()` is not the whole class

The issue's census keyed on `ShapeType()`. `TopoDS_Shape.hxx` has eighteen more
unguarded `myTShape->` dereferences: the eight flag accessors (`Free`, `Locked`, `Modified`,
`Checked`, `Orientable`, `Closed`, `Infinite`, `Convex`), each with a getter and a setter, plus
`EmptyCopy()`. `NbChildren()` is the one accessor OCCT guards itself
(`myTShape.IsNull() ? 0 : myTShape->NbChildren()`).

Nine bridge sites read or write those flags, all in `OCCTBridge_Topology.mm`, and all nine were
measured crashing on the same input, one test process each:

| Swift property | before | after |
|---|---|---|
| `isFree` | signal 11 | `false` |
| `isModified` | signal 11 | `false` |
| `isChecked` | signal 11 | `false` |
| `isOrientable` | signal 11 | `false` |
| `isInfinite` | signal 11 | `false` |
| `isConvex` | signal 11 | `false` |
| `isLocked` | signal 11 | `false` |
| `setLocked(true)` | signal 11 | no-op |
| `isClosedShape` | signal 11 | `false` |

`false` is a refusal here rather than the value a real shape would have given anyway: measured on
the pinned kernel, a box answers `isFree` and `isModified` true, its shell answers `isOrientable`
and `isClosedShape` true, and one of its faces answers `isChecked` true. `isInfinite` and `isConvex`
are false on every sub-shape of a box, so those two have no positive control in the test suite, and
the suite says so.

**A first draft of that control test read `TopoDS_TShape`'s constructor instead of asking the
shape**, and asserted `isOrientable == true` for the box because the constructor sets
`Bit_Free | Bit_Modified | Bit_Orientable`. A solid answers `false`. Measuring it is what corrected
that, and it is the reason the table above is a measurement rather than a derivation.

## An overload nearly measured the wrong function

`Shape` has two `intersectLine` overloads. `intersectLine(origin:direction:)`
(`Shape+Analysis.swift:875`) is a different bridge function and does not crash on a null shape;
`intersectLine(origin:direction:paramRange:)` (`:1189`) is `OCCTIntersectLineFace`, the one in the
census. A probe written with two arguments resolves to the first, came back `got 0`, and would have
been recorded as "this site does not crash". Passing `paramRange:` explicitly reaches the second and
it dies with signal 11 like the rest. Same shape as `measure-dont-assume`'s "adjacent number"
failure: the measurement was real, of the wrong subject.

## The nineteen sites the gate found on its own

`Scripts/check-null-handle-guards.py` grew a third walk for this shape (see its module docstring).
It found the same seven the corrected census finds, and twelve more it cannot: the four
`OCCTBridge_AIS.mm` reference-alias sites, `OCCTShapeUpgrade`, the two array-element sites,
`OCCTWireAnalyze`, and four whose hazard is a flag accessor rather than `ShapeType()`. Nineteen in
all, in five files, none of them in the issue as filed:

```
OCCTBridge_AIS.mm        OCCTDimensionCreateLengthFromEdge, ...CreateLengthFromFaces,
                         ...CreateAngleFromEdges, ...CreateAngleFromFaces      (7 arguments)
OCCTBridge_Curve3D.mm    OCCTApproxCurveOnSurface                              (2)
OCCTBridge_Healing.mm    OCCTShapeUpgrade, OCCTShapeFixFaceConnect             (2)
OCCTBridge_Modeling.mm   OCCTLocOpePipe, OCCTLocOpeSplitShapeByWire,
                         OCCTLocOpeSplitDrafts, OCCTShapeMakeSolidFromShell,
                         OCCTLocOpeSplitByWireOnFace,
                         OCCTBRepFeatSplitShapeWithSides, OCCTLocOpeSplitByWires   (7)
OCCTBridge_Topology.mm   OCCTWireAnalyze                                       (1)
```

Two are worth naming individually.

`OCCTBridge_AIS.mm`'s four reach `ShapeType()` through a `TopoDS_Shape&` reference alias
(`TopoDS_Shape& shape = edge->shape;`), so a grep for `->shape.ShapeType()` does not see them at
all. That is why the walk follows aliases rather than matching the field access.

`OCCTShapeUpgrade` is the case a body-level `'IsNull()' in text` census marks as guarded and is not:

```cpp
TopoDS_Shape sewedShape = sewing.SewedShape();
if (sewedShape.IsNull())
  sewedShape = shape->shape;      // reinstates the caller's null, does not reject it
...
if (sewedShape.ShapeType() != TopAbs_SOLID)   // crash
```

The `IsNull()` is a fallback, not a guard. Ordering is the whole of what separates the two, and it
is why the walk sorts guard and use events by position instead of asking whether an `IsNull()`
appears anywhere.

## A second class the gate cannot see, and what is left after it

Three sites take the same null shape and never touch a hazardous `TopoDS_Shape` member themselves:
they hand it to `PrsDim_RadiusDimension`, `PrsDim_DiameterDimension` and `ShapeFix_Shape`, whose
constructors dereference it inside the kernel. The gate's third walk is not blind to these by
accident, it is out of scope by construction: it reasons about what the BRIDGE does with the shape,
and this is the shape-side equivalent of #556's "the OCCT entry point dereferences it for you",
which for handles took its own measured sweep of 57 entry points.

All three were measured crashing (signal 11) and are fixed here, because both files were already in
this diff. Eleven public operations were probed in total, one process each:

| operation | before | after |
|---|---|---|
| `RadiusDimension(shape:)` | signal 11 | `nil` |
| `DiameterDimension(shape:)` | signal 11 | `nil` |
| `Shape.healed()` | signal 11 | `nil` |
| `Shape.fused(with:tolerance:)` | `nil` | `nil` |
| `Shape.subtracting(_:)` | `nil` | `nil` |
| `Shape.faces()` | `0` | `0` |
| `Shape.checkResult.isValid` | `false` | `false` |
| `Shape.linearProperties()` | `nil` | `nil` |
| `Shape.translated(by:)` | `nil` | `nil` |
| `Shape.mesh(linearDeflection:)` | a mesh | a mesh |
| `Exporter.writeSTEP(shape:to:modelType:)` | throws `exportFailed` | throws `exportFailed` |

**That is a sample, not a sweep**, and the distinction matters: eleven operations out of a public
surface of several thousand entry points says the class is not empty, and says nothing about its
size. Enumerating which OCCT entry points dereference a null `TopoDS_Shape` is the shape-side #556
and belongs to its own issue.

`Shape.mesh` returning a mesh for a null shape is not a crash and is left alone; whether an empty
mesh is the right answer there is a separate question from this one.

**The first run of this probe was a false green.** The script classified a test whose target failed
to COMPILE as passing, because it only looked for `signal code` in the output, so four API-signature
mistakes came back as "ok" alongside two sites that had genuinely just been fixed. The script now
checks for `error: ` as well and prints the value each probe actually returned, which is what makes
the table above readable as a measurement rather than as an absence of one.

## The injection

Every call site keeps the guard this PR writes; only the shared predicate is broken, back to the
pre-fix pointer-only test:

```cpp
inline bool occtShapeIsPresent(OCCTShapeRef shape)
{
  return shape != nullptr;   // INJECTED: pointer only, no shape test
}
```

Each test then runs in its own process, because the failure mode is a crash and one crash in a
shared process hides every test after it.

| test | injected | fixed |
|---|---|---|
| `shapeTypeOfANullifiedShapeIsUnknown` | signal 11 | pass |
| `isValidSolidOfANullifiedShapeIsFalse` | signal 11 | pass |
| `theFiveTypePredicatesAreFalseForANullifiedShape` | signal 11 | pass |
| `shapeTypeStringOfANullifiedShapeReadsNull` | signal 11 | pass |
| `typeNameOfANullifiedShapeIsNil` | signal 11 | pass |
| `intersectLineWithANullifiedShapeFindsNothing` | signal 11 | pass |
| `theFlagAccessorsRefuseANullifiedShape` | signal 11 | pass |
| `theGateFoundSitesRefuseANullifiedShape` | signal 11 | pass |
| `kernelSideDereferencesAreRefused` | signal 11 | pass |
| `theFlagAccessorsStillAnswerForARealShape` | pass | pass |
| `isEmptyShapeSeparatesANullifiedShapeFromARealOne` | pass | pass |
| `edgeAndFaceRefuseANullifiedShape` | pass | pass |
| `everyGuardedQueryStillAnswersForARealShape` | pass | pass |

Nine of thirteen crash. The four that do not are the controls, and they are supposed to be
unaffected: three of them never touch a null shape, and `isEmptyShape` is `TopoDS_Shape::IsNull()`
itself, which is one of the two accessors that has always been safe.

`inject.sh` reproduces the table. It edits `OCCTBridge_Internal.h` in place and restores it, so do
not run it against a tree with uncommitted changes to that file.

## What a guarded call returns, and why none of it is fabricated

Every one of the twenty-four already had a refusal path, for a null POINTER or for a shape of the
wrong type, and a null shape belongs on that same path. Nothing here invents a value.

| function | returns | why that is the absence, not a made-up answer |
|---|---|---|
| `OCCTShapeGetType` | `-1` | `ShapeType.unknown`. A null shape has no type, and `-1` was already the null-pointer answer |
| `OCCTShapeTypeName` | `nullptr` | Swift `nil`, which the property's doc comment already promised for "if the shape is null" |
| `OCCTShapeTypeString` | `"null"` | the function's own existing word for an absent shape, distinct from its `"unknown"` and `"shape"` |
| `OCCTShapeIsSolid` and 4 siblings | `false` | "is this a solid" is answered no for a shape that is not one |
| `OCCTShapeIsValidSolid` | `false` | a null shape is not a valid closed solid |
| the 8 flag getters | `false` | the refusal the null pointer already got; see the control measurements above |
| `OCCTShapeSetLocked` | no-op | there is no state to write |
| `OCCTIntersectLineFace` | `0` | a null shape meets no line |
| the 2 pcurve queries | `false`, out params untouched | already the wrong-type behaviour |
| everything returning `OCCTShapeRef` | `nullptr` | already the failure contract |

The distinction that matters for #726 is that none of these is a *measurement*. `Shape.isEmptyShape`
(`OCCTShapeIsEmpty`, literally `shape->shape.IsNull()`) is what separates "this shape is null" from
"this is a real shape and the answer is no", and it already existed.
