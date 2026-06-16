---
title: Naming Conventions
nav_order: 10
---

# Naming Conventions: OCCT vs OCCTSwift

OCCTSwift translates OCCT's C++ API into idiomatic Swift. This document explains the naming conventions and how they map to the underlying OCCT classes.

## Class Hierarchy → Flat Swift Types

OCCT organizes classes by toolkit and module prefix:

| OCCT Class | OCCTSwift Type |
|---|---|
| `BRepPrimAPI_MakeBox` | `Shape.box()` |
| `BRepAlgoAPI_Fuse` | `Shape.union(with:)` |
| `BRepFilletAPI_MakeFillet` | `Shape.filleted(radius:)` |
| `BRepOffsetAPI_MakeThickSolid` | `Shape.shelled(thickness:)` |
| `GeomAPI_Interpolate` | `Curve3D.interpolated(through:)` |
| `BRepBuilderAPI_MakeWire` | `Wire(...)` |
| `Geom_BSplineCurve` | `Curve3D` |
| `Geom_BSplineSurface` | `Surface` |
| `Poly_Triangulation` | `Mesh` |

The `API_Make*` builder pattern is replaced by static factory methods on the result type. The toolkit prefix (`BRepPrimAPI_`, `GeomAPI_`, etc.) is dropped entirely.

## Constructors → Static Factories

OCCT uses constructors with `IsDone()` guards:

```cpp
BRepPrimAPI_MakeBox builder(10, 20, 30);
if (builder.IsDone()) {
    TopoDS_Shape s = builder.Shape();
}
```

OCCTSwift returns optionals — `nil` replaces the `IsDone()` check:

```swift
let box = Shape.box(width: 10, height: 20, depth: 30)  // Shape?
```

## Verb Tense — Past Participle for Transformations

OCCT uses imperative verbs (`Build()`, `Perform()`, `Transform()`). OCCTSwift follows Swift API Design Guidelines — methods that return a new value use the **-ed/-ing** suffix:

| OCCT | OCCTSwift |
|---|---|
| `BRepFilletAPI_MakeFillet` | `shape.filleted(radius:)` |
| `BRepFilletAPI_MakeChamfer` | `shape.chamfered(distance:)` |
| `BRepBuilderAPI_Transform` (translate) | `shape.translated(by:)` |
| `BRepBuilderAPI_Transform` (rotate) | `shape.rotated(axis:angle:)` |
| `BRepBuilderAPI_Transform` (scale) | `shape.scaled(by:)` |
| `BRepBuilderAPI_Transform` (mirror) | `shape.mirrored(planeNormal:)` |
| `ShapeFix_Shape` | `shape.healed()` |
| `BRepBuilderAPI_Copy` | `shape.deepCopy()` |

## Named Parameters

OCCT passes positional arguments:

```cpp
BRepPrimAPI_MakeCylinder(5.0, 10.0);
BRepPrimAPI_MakeCone(5.0, 2.0, 10.0);
```

OCCTSwift uses Swift labeled arguments throughout:

```swift
Shape.cylinder(radius: 5, height: 10)
Shape.cone(bottomRadius: 5, topRadius: 2, height: 10)
```

## Boolean Operations

OCCT has one class per operation:

```
BRepAlgoAPI_Fuse     → shape.union(with:)
BRepAlgoAPI_Common   → shape.intersection(with:)
BRepAlgoAPI_Cut      → shape.subtracting(_:)
BRepAlgoAPI_Section  → shape.section(with:)
```

## Enums — No Prefix Repetition

OCCT repeats the namespace in every enum value:

```cpp
TopAbs_SOLID, TopAbs_FACE, TopAbs_EDGE, TopAbs_VERTEX
GeomAbs_C0, GeomAbs_C1, GeomAbs_G1
```

OCCTSwift uses Swift-style dot-syntax with lowercase cases:

```swift
ShapeType.solid, .face, .edge, .vertex
GeometricContinuity.c0, .c1, .g1
```

## Properties vs Query Methods

OCCT uses methods for all queries, even trivial ones:

```cpp
GProp_GProps props;
BRepGProp::VolumeProperties(shape, props);
double vol = props.Mass();
gp_Pnt com = props.CentreOfMass();
```

OCCTSwift uses computed properties for zero-argument queries:

```swift
shape.volume           // Double?
shape.surfaceArea      // Double?
shape.centerOfMass     // SIMD3<Double>?
shape.bounds           // (min: SIMD3<Double>, max: SIMD3<Double>)
shape.isValid          // Bool
```

## Geometric Types — simd Instead of gp_*

OCCT has its own geometric primitives:

```cpp
gp_Pnt(1.0, 2.0, 3.0)    // point
gp_Vec(0.0, 0.0, 1.0)     // vector
gp_Dir(0.0, 0.0, 1.0)     // unit direction
gp_Pnt2d(1.0, 2.0)        // 2D point
```

OCCTSwift uses Swift's simd types:

```swift
SIMD3<Double>(1, 2, 3)     // points, vectors, directions
SIMD2<Double>(1, 2)         // 2D points
```

## Iterators → Arrays

OCCT uses `Init/More/Next` iterator patterns:

```cpp
TopExp_Explorer ex(shape, TopAbs_FACE);
for (; ex.More(); ex.Next()) {
    TopoDS_Face f = TopoDS::Face(ex.Current());
}
```

OCCTSwift returns Swift arrays:

```swift
shape.subShapes(ofType: .face)   // [Shape]
shape.vertices()                  // [SIMD3<Double>]
shape.edges()                     // [Edge]
```

## Error Handling

OCCT throws C++ exceptions:

```cpp
try {
    BRepPrimAPI_MakeBox builder(0, 0, 0);  // degenerate
    TopoDS_Shape s = builder.Shape();
} catch (StdFail_NotDone&) { ... }
```

OCCTSwift maps errors to:
- **`nil`** — geometry operations that can fail cleanly (boolean ops, fillets, etc.)
- **`throws`** — I/O operations (`Shape.load(from:)`, `Exporter.writeSTEP(shape:to:)`)

## Bridge Layer Naming

The C bridge functions (in `OCCTBridge.h` / `OCCTBridge.mm`) follow their own conventions:

| Pattern | Example |
|---|---|
| Shape creation | `OCCTShapeMakeBox`, `OCCTShapeMakeCylinder` |
| Shape operations | `OCCTShapeFillet`, `OCCTShapeChamfer`, `OCCTShapeUnion` |
| Shape queries | `OCCTShapeVolume`, `OCCTShapeSurfaceArea` |
| Wire operations | `OCCTWireRectangle`, `OCCTWireCircle` |
| Conversions | `OCCTShapeFromWire` (not `OCCTWireToShape`) |
| Memory | `OCCTShapeRelease`, `OCCTWireRelease`, `OCCTMeshRelease` |
| Edge operations | `OCCTEdgeCreate`, `OCCTEdgeStartPoint` |
| Face operations | `OCCTFaceFromWire`, `OCCTFaceArea` |

The bridge prefixes the handle type (`OCCTShape`, `OCCTWire`, `OCCTFace`, `OCCTEdge`, `OCCTMesh`, `OCCTCurve3D`, `OCCTSurface`) followed by the operation name. Every `Create`/`Make` function has a matching `Release` function.

## Summary

| Concept | OCCT | OCCTSwift |
|---|---|---|
| Namespace | Module prefix (`BRepPrimAPI_`) | Swift type (`Shape.`) |
| Construction | `MakeBox(w, h, d)` + `IsDone()` | `Shape.box(width:height:depth:)` → `Shape?` |
| Transformation | `Perform()`, `Build()` | `.filleted()`, `.translated()` |
| Enum values | `TopAbs_SOLID` | `.solid` |
| Points/vectors | `gp_Pnt`, `gp_Vec` | `SIMD3<Double>` |
| Iteration | `Init/More/Next` | `[Shape]` |
| Errors | `StdFail_NotDone` exception | `nil` or `throws` |
| Parameters | Positional | Labeled (`radius:`, `height:`) |
