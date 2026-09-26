# #2765: `ShapeUpgrade_ShapeDivide::Perform()` is not a success flag

`OCCTShapeConvertToBezier` gated on `if (!converter.Perform()) return nullptr;`. That reads
`Perform()` as "did this succeed". It is not: it is "did anything change".

From the pinned `Libraries/occt-src`
(`src/ModelingAlgorithms/TKShHealing/ShapeUpgrade/ShapeUpgrade_ShapeDivide.cxx`), per
`okf/policies/context-first.md`, `ShapeUpgrade_ShapeDivide::Perform()` ends:

```cpp
  myResult = myContext->Apply(myShape, TopAbs_SHAPE);
  return !myResult.IsSame(myShape);
```

and its `TopAbs_COMPOUND` branch ends:

```cpp
    if (Status(ShapeExtend_DONE))
    {
      myResult = myContext->Apply(C, TopAbs_SHAPE);
      myContext->Replace(myShape, myResult);
      return true;
    }
    myResult = myShape;
    return false;
```

Either way `false` leaves `myResult` holding the input shape. The only genuine-failure `false` is
the `myShape.IsNull()` guard at the top of the function, which every wrapper in
`Sources/OCCTBridge/src/OCCTBridge_Healing_Upgrade.mm` already covers with its own null check
before constructing the tool. `ShapeUpgrade_ShapeConvertToBezier::Perform()` forwards the base
class's value unchanged (`ShapeUpgrade_ShapeConvertToBezier.cxx`, `res = ...::Perform(...)` then
`return res;`).

Two probes. Both run against the kernel `Package.swift` pins, resolved by SwiftPM, not a local
build.

## Compile

```bash
XCF=.build/artifacts/<checkout>/OCCT/OCCT.xcframework
clang++ -std=c++17 -ObjC++ -w \
  -I"$XCF/macos-arm64/Headers" -L"$XCF/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2765-convert-to-bezier-perform/probe.mm -o /tmp/probe2765
/tmp/probe2765
```

Same line for `siblings.mm`. With `Libraries/OCCT.xcframework` present, point `XCF` at that
instead.

## `probe.mm`: is the defect reachable?

Runs `OCCTShapeConvertToBezier`'s exact mode set and prints `Perform()`, `Result().IsNull()` and
whether `Result()` differs from the input.

```
box input : faces=6 non-bezier-surf=6 non-bezier-curv=24
box, 1st conversion             perform=true  result-null=false differs=true  -> bridge today: shape
box, 2nd conversion             perform=true  result-null=false differs=true  -> bridge today: shape
box, 3rd conversion             perform=true  result-null=false differs=true  -> bridge today: shape
cylinder, 1st conversion        perform=true  result-null=false differs=true  -> bridge today: shape
cylinder, 2nd conversion        perform=true  result-null=false differs=true  -> bridge today: shape
sphere, 1st conversion          perform=true  result-null=false differs=true  -> bridge today: shape
sphere, 2nd conversion          perform=true  result-null=false differs=true  -> bridge today: shape
single vertex                   perform=false result-null=false differs=false -> bridge today: nil
free line edge, 1st conversion  perform=true  result-null=false differs=true  -> bridge today: shape
free line edge, 2nd conversion  perform=false result-null=false differs=false -> bridge today: nil
```

Yes, reachable, and reachable from Swift. Re-converting a *solid* keeps returning `true`, because
each pass rebuilds edges and the result is never `IsSame` as its input, so the round trip the
issue proposed does not by itself reach the defect on a box, a cylinder or a sphere. What does
reach it is a shape with no face and nothing left to convert:

- a single-edge shape whose curve is already a Bezier, which is exactly what one conversion of a
  line edge produces. In Swift: `Shape.fromEdge(box.edges().first { $0.curveType == .line }!)`,
  then `convertedToBezier` twice. The second call returned `nil` before the fix, which
  `Tests/OCCTCurveTests/Issue2765ConvertToBezierTests.swift` asserts against.
- a single vertex.

## `siblings.mm`: the sweep

Every other `ShapeUpgrade_ShapeDivide` subclass wrapped in the same file, run with that wrapper's
own configuration against an input that gives it nothing to split. No subclass declares
`Perform()` at all (only `ShapeUpgrade_ShapeDivide` and `ShapeUpgrade_ShapeConvertToBezier` do, by
`grep` over the pinned headers), so all of them inherit the same semantics.

```
OCCTShapeDivide (Continuity C0, box)              perform=false result-null=false differs=false -> bridge today: nil
OCCTShapeSplitByAngle (90 deg, box)               perform=false result-null=false differs=false -> bridge today: nil
OCCTShapeDivideClosedEdges (box)                  perform=false result-null=false differs=false -> bridge today: nil
OCCTShapeUpgradeDivideClosed (box)                perform=false result-null=false differs=false -> bridge today: nil
OCCTShapeUpgradeDivideClosed (cylinder, control)  perform=true  result-null=false differs=true  -> bridge today: shape
OCCTShapeDivideByNumber (nbU=nbV=1, box)          perform=false result-null=false differs=false -> bridge today: nil
OCCTShapeDivideByParts (nbParts=1, box)           perform=false result-null=false differs=false -> bridge today: nil
OCCTShapeDivideByArea (maxArea=1e6, box)          perform=false result-null=false differs=false -> bridge today: shape
```

Every one of the seven `if (!...Perform()) return nullptr;` sites is reachable with an ordinary
box, and in every case `Result()` is the valid, unchanged input. The cylinder row is the control:
the same class on an input it can actually split returns `true` and a changed shape, so the
fixtures mean what their names say. `OCCTShapeDivideByArea` is the one wrapper in the file that
already ignores `Perform()`'s return value, with a comment saying why, and it is the shape the
other seven should take.

Those seven are **not** changed in #2765's PR. Each is a separate public Swift entry point with
its own documented contract (`Shape.divided(at:tolerance:)` documents the `nil` as "no divisions
were needed **or** on failure", so callers may be reading it as a signal), and flipping seven
return contracts is a behaviour-change batch that deserves its own review rather than riding along
with a one-line correctness fix. Filed as #2766.
