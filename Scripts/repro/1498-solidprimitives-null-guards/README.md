# OCCTSwift #1498: five null-handle guards in `OCCTBridge_Modeling_SolidPrimitives.mm`

Five functions checked only the wrapper *pointer* (`if (!shape)`/`if (!profile)`) before handing the
underlying `TopoDS_Shape`/`TopoDS_Wire` into an OCCT constructor that dereferences it
unconditionally, instead of `occtShapeIsPresent(...)` (checks the pointer **and** `IsNull()` on the
geometry it wraps), the pattern this file's own correctly-guarded siblings already use.

| Function | OCCT call |
|---|---|
| `occtShapePeriodicImpl` (shared by `OCCTShapeMakePeriodic`/`OCCTShapeRepeat`) | `BOPAlgo_MakePeriodic::SetShape`/`Perform()` |
| `OCCTShapeMakeDraft` | `BRepOffsetAPI_MakeDraft` ctor/`Perform()` |
| `OCCTShapeCreateRevolution` | `BRepPrimAPI_MakeRevol(profile->wire, axis, angle)` |
| `OCCTShapeCreateRevolutionFull` | `BRepPrimAPI_MakeRevol(shape->shape, axis)` |
| `OCCTShapeCreateRevolutionPartial` | `BRepPrimAPI_MakeRevol(shape->shape, axis, angle)` |

## Fix

Swap the pointer-only check for `occtShapeIsPresent(...)` at all five sites. One line each, no OCCT
kernel patch, no `Package.swift` change.

## Swift-level regression coverage

Four of the five are reachable one-line from Swift via the deprecated `Shape.nullified` property
(`box.nullified!.<op>`), and get real crash-closure tests in
`Tests/OCCTStressTests/StressNullInvalidTests.swift` (`StressNullHandleGuardTests`), following the
same pattern as the existing `#345` tests in that file:

- `makePeriodic` (`occtShapePeriodicImpl`)
- `draft(direction:angle:length:)` (`OCCTShapeMakeDraft`)
- `revolved(axisOrigin:axisDirection:)` (`OCCTShapeCreateRevolutionFull`)
- `revolved(axisOrigin:axisDirection:angle:)` (`OCCTShapeCreateRevolutionPartial`)

Each test was run once against the pre-fix guard (`if (!shape)`) to confirm it crashes the process,
then against the fix to confirm it returns `nil` cleanly, per this project's "prove the test fails"
policy.

## `OCCTShapeCreateRevolution` (the Wire-based fifth site) has no Swift-level repro

`Shape.revolve(profile: Wire, ...)` is the only one of the five whose null-shaped argument is a
`Wire`, not a `Shape`, and there is no public `Wire.nullified` (or equivalent) to construct a
present-but-null `OCCTWireRef` from Swift:

- `Wire(_ shape: Shape)` goes through `OCCTWireFromShape`, which already checks
  `shape->shape.IsNull()` before constructing the wire wrapper, so handing it `shape.nullified!`
  correctly returns `nil` rather than propagating a null-backed `Wire`.
- Every bridge site that constructs an `OCCTWire` wrapper (`new OCCTWire(...)` or
  `new OCCTWire(); w->wire = ...;`) fills `->wire` before returning it; none was found that returns
  a wrapper with a still-null `wire` field on any path reachable from the public Swift surface.

So this site's coverage is a direct C-level ground-truth test instead: `repro_1498.mm` compiles the
**actual** `OCCTBridge_Modeling_SolidPrimitives.mm` translation unit (not a hand-rolled
reimplementation of what it does) together with `OCCTBridge.mm` (for the two externs it calls,
`occtEnsureSignals`/`occtHasSelfIntersectingWire`) and a small driver, then calls
`OCCTShapeCreateRevolution` with a hand-constructed `OCCTWire` wrapper (`&nullWire`, a non-null
pointer whose `->wire` is left at its default, null, `TopoDS_Wire`) -- a state only reachable from
C++ with access to the private `OCCTBridge_Internal.h` struct layout, never from Swift or from any
public bridge consumer.

### Running it

```bash
clang++ -std=c++17 -ObjC++ -w -DOCCT_AVAILABLE=1 -DOCCT_NO_DEPRECATED \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -I"Sources/OCCTBridge/include" -I"Sources/OCCTBridge/src" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Sources/OCCTBridge/src/OCCTBridge.mm \
  Sources/OCCTBridge/src/OCCTBridge_Modeling_SolidPrimitives.mm \
  Scripts/repro/1498-solidprimitives-null-guards/repro_1498.mm \
  -o /tmp/repro_1498
/tmp/repro_1498
```

### Results

Pre-fix (`git show <merge-base>:Sources/OCCTBridge/src/OCCTBridge_Modeling_SolidPrimitives.mm`,
`if (!profile) return nullptr;`):

```
#1498: OCCTShapeCreateRevolution(profile) with a non-null wrapper around a null TopoDS_Wire

*** Abort *** an exception was raised, but no catch was found.
	... The exception is: SIGSEGV 'segmentation violation' detected. Address 38.
  OCCTShapeCreateRevolution(nullWireWrapper, ...)              other abnormal exit
```

Post-fix (`if (!occtShapeIsPresent(profile)) return nullptr;`):

```
#1498: OCCTShapeCreateRevolution(profile) with a non-null wrapper around a null TopoDS_Wire

      result = 0x0 (refused, no crash)
  OCCTShapeCreateRevolution(nullWireWrapper, ...)              returned normally
```

Confirms both halves of "prove the test fails": the pre-fix guard crashes, the fix returns `nil`
cleanly with no other behavior change.
