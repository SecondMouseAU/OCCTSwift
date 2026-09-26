# #2765/#2769: reading `ShapeUpgrade_ShapeDivide::Perform()` the way OCCT reads it

**#2769 superseded the conclusion #2765 drew here.** `Perform()` is not a success flag, which is
what #2765 established and what the first half of this page shows. It does not follow that the
return value should be ignored, which is what #2765's PR did and what #2769 corrected: OCCT's own
callers read `Perform()` together with `Status(ShapeExtend_FAIL)`, and that pair is the rule the
bridge now follows. The `siblings.mm` section below carries the rule, the evidence for it and the
failure path it makes expressible.

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

## `siblings.mm`: the sweep, and the rule #2769 settled

**Rewritten for #2769.** #2765 asked whether a false `Perform()` was reachable and whether
`Result()` was usable when it was. The answer was yes to both, and the conclusion drawn from it,
that the return value should simply be ignored, was half of OCCT's own answer.

OCCT reads `Perform()` and `Status(ShapeExtend_FAIL)` **together**, never either alone.
`ShapeProcess_OperLibrary.cxx` is the production shape-processing library that STEP and IGES import
healing runs through, and all five of its `ShapeUpgrade_ShapeDivide`-family call sites (lines 228,
438, 525, 577 and 926 of the pinned copy) are:

```cpp
if (!tool.Perform() && tool.Status(ShapeExtend_FAIL))
{
  return false;                    // the failure path
}
ctx->RecordModification(tool.GetContext(), msg);
ctx->SetResult(tool.Result());     // success, including when Perform() returned false
return true;
```

`SWDRAW_ShapeUpgrade.cxx` agrees from the other side: `tool.Perform();`, then
`TopoDS_Shape res = tool.Result();`, then `Status(...)` reported separately.

So `false` on its own means "nothing was done". `false` with `Status(ShapeExtend_FAIL)`, the
any-of-`FAIL1`..`FAIL8` aggregate from `ShapeExtend_Status.hxx`, is the failure.
`Status(const ShapeExtend_Status)` is declared on `ShapeUpgrade_ShapeDivide` itself, so every
wrapper has it.

`siblings.mm` now records both halves, for all eleven wrappers in
`Sources/OCCTBridge/src/OCCTBridge_Healing_Upgrade.mm` that run one of those `Perform()`
implementations, split by the direction each one got wrong. `was:` is the answer the bridge gave
before #2769, `now:` is OCCT's two-part test.

```
#2765/#2769 sweep: ShapeUpgrade_ShapeDivide-family wrappers with nothing to do
fixtures: box 10x20x30 (6 faces), cylinder r5 h10 (3 faces), sphere r5 (1), torus 10/3 (1), one straight edge (0)

== Group A: gated on Perform() alone, so a no-op input returned nil (#2766)

OCCTShapeDivide (Continuity C0, box)                 A perform=false status-fail=false result-null=false differs=false faces=6    was: nil   now: shape
OCCTShapeSplitByAngle (90 deg, box)                  A perform=false status-fail=false result-null=false differs=false faces=6    was: nil   now: shape
  ... same class, cylinder at 45 deg (control)       A perform=true  status-fail=false result-null=false differs=true  faces=10   was: shape now: shape
OCCTShapeDivideClosedEdges (box)                     A perform=false status-fail=false result-null=false differs=false faces=6    was: nil   now: shape
OCCTShapeUpgradeDivideClosed (box)                   A perform=false status-fail=false result-null=false differs=false faces=6    was: nil   now: shape
  ... same class, cylinder (control)                 A perform=true  status-fail=false result-null=false differs=true  faces=4    was: shape now: shape
OCCTShapeDivideByNumber (nbU=nbV=1, box)             A perform=false status-fail=false result-null=false differs=false faces=6    was: nil   now: shape
OCCTShapeDivideByNumber (nbU=2, one edge)            A perform=false status-fail=false result-null=false differs=false faces=0    was: nil   now: shape
OCCTShapeDivideByParts (nbParts=1, box)              A perform=false status-fail=false result-null=false differs=false faces=6    was: nil   now: shape

== Group B: ignored Perform() entirely, so a FAIL came back as a result (#2769)

OCCTShapeDivideByArea (maxArea=1e6, box)             B perform=false status-fail=false result-null=false differs=false faces=6    was: shape now: shape
OCCTShapeConvertToBezier (already-Bezier edge)       B perform=false status-fail=false result-null=false differs=false faces=0    was: shape now: shape
OCCTShapeUpgradeConvertCurves3dToBezier (all modes off, box) B perform=false status-fail=false result-null=false differs=false faces=6    was: shape now: shape
OCCTShapeUpgradeConvertSurfaceToBezier (all modes off, box) B perform=false status-fail=false result-null=false differs=false faces=6    was: shape now: shape

== Hunting a genuine Status(ShapeExtend_FAIL), which is the outcome group B lost

null shape (FAIL1, unreachable through the bridge)   A perform=false status-fail=true  result-null=true  differs=false faces=-1   was: nil   now: nil
SplitByAngle -30 deg, cylinder                       A perform=false status-fail=false result-null=false differs=false faces=3    was: nil   now: shape
SplitByAngle 720 deg, sphere                         A perform=true  status-fail=false result-null=false differs=true  faces=1    was: shape now: shape
SplitByAngle 1 deg, torus                            A perform=true  status-fail=false result-null=false differs=true  faces=360  was: shape now: shape
Divide C3 on sphere, tolerance 0                     A perform=false status-fail=false result-null=false differs=false faces=1    was: nil   now: shape
Divide C3 on sphere, tolerance -1                    A perform=false status-fail=false result-null=false differs=false faces=1    was: nil   now: shape
Divide C3 on sphere, tolerance 1e+12                 A perform=false status-fail=false result-null=false differs=false faces=1    was: nil   now: shape
DivideClosed on cylinder, nbSplitPoints 0            A perform=true  status-fail=false result-null=false differs=true  faces=4    was: shape now: shape
DivideClosed on cylinder, nbSplitPoints -5           A perform=true  status-fail=false result-null=false differs=true  faces=4    was: shape now: shape
DivideClosed on cylinder, nbSplitPoints 64           A perform=true  status-fail=false result-null=false differs=true  faces=67   was: shape now: shape
DivideByArea on cylinder, maxArea 10                 B perform=true  status-fail=false result-null=false differs=true  faces=84   was: shape now: shape
DivideByArea on cylinder, maxArea 1                  B perform=true  status-fail=false result-null=false differs=true  faces=820  was: shape now: shape
```

Reading it:

- **Group A**, the seven #2766 measured, gated on `Perform()` alone. Every one is reachable with an
  ordinary box, `status-fail` is `false` on every one of those rows, and `Result()` is the valid
  unchanged input, so `was: nil` was a no-op reported as a failure. The `control` rows are the same
  class on an input it can genuinely split: `true`, a changed shape, more faces. They are what
  makes the no-op fixtures mean what their names say.
- **Group B**, the four that ignored the return value, come back `shape` either way on a no-op,
  which is correct. What they lost is the other row: a `perform=false status-fail=true` input would
  have been handed back as a result.

## The genuine-failure input: what was tried, and what it cost

The hunt section exists because the rule newly makes a failure path expressible, and a rule with no
exercised failure path is a claim rather than a measurement. **Against the pinned kernel, no
`Status(ShapeExtend_FAIL)` was reachable through any of the eleven wrappers.** What was tried:

- **`FAIL1`**, the `myShape.IsNull()` guard at the top of `Perform()`, is the one that does fire.
  It is the only `FAIL` these wrappers can reach from a parameter value alone, and it is
  unreachable through the bridge: every one of the eleven rejects a null `OCCTShapeRef` before
  constructing the tool, which is the row `null shape (FAIL1, unreachable through the bridge)`
  records.
- **Parameter extremes**, all of them recorded above and all `status-fail=false`: `splitByAngle` at
  -30, 1 and 720 degrees; `divided(at: .c3)` at tolerance 0, -1 and 1e12; `dividedClosedFaces` at
  0, -5 and 64 split points; `dividedByArea` down to a max area of 1 on a cylinder wall of area
  ~314 (820 faces out).
- **`maxAngle` 0 and `maxArea` 1e-6** are left out on purpose. Both ask the kernel for an unbounded
  number of splits and neither returns; that is a different finding from the one being hunted, and
  it hangs the probe rather than reporting anything.
- **`FAIL2`/`FAIL3`** need the split-face or split-wire tool to fail or throw on a sub-shape, which
  is a property of the input geometry. The cheapest attempt was a compound holding a face
  hand-built with `BRep_Builder` and no surface at all. **It does not set `FAIL`: it SIGSEGVs**
  (exit 139) inside `Perform()`'s `TopAbs_FACE` loop, whose `try`/`catch` catches only
  `Standard_Failure`, so the process dies before any status is written. That case is not kept in
  the probe, because it takes the rest of the transcript with it. The Swift API cannot construct
  such a face, so it is not a guard this bridge needs; it is recorded because it is the reason the
  failure path has no test.

So the failure branch `if (!tool.Perform() && tool.Status(ShapeExtend_FAIL)) return nullptr;` is
**unexercised by any test**. It is OCCT's own branch, taken from OCCT's own callers, and it is
strictly narrower than what stood before it, so it cannot reject anything the old code accepted.
That is the argument for it; it is not a measurement, and it is not presented as one.
