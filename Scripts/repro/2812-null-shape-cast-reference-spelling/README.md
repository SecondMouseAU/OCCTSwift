# #2812: the reference spelling of #1513's split-statement cast, and the four functions behind it

Two questions, one probe. The lead was `OCCTIntToolsEdgeEdge`, which has no null-shape guard where
its sibling `OCCTIntToolsEdgeFace` has one. The answer to that one is **not a defect**. The answer
to the question it provoked, whether `check-null-handle-guards.py` could have seen it, is a gate
blind spot with four real functions behind it.

## Build

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2812-null-shape-cast-reference-spelling/probe_nullshape_deref.mm -o /tmp/occt_2812
/tmp/occt_2812
```

In a worktree with no `Libraries/OCCT.xcframework`, SwiftPM's resolved copy of the pinned
`v4.0.0-kernel.2` asset is under `.build/artifacts/<worktree>/OCCT/OCCT.xcframework/macos-arm64`,
which is what these numbers were measured against. Each case runs in a forked child, so an
uncatchable fault is reported with its signal rather than ending the run; the child wraps the body
in the same single `catch (...)` the bridge functions do, so "CAUGHT" means the bridge's own catch
would have absorbed it. Exit code is the number of uncatchable cases clamped to 0/1.

## What the probe says

```
A1 TopoDS::Edge(null TopoDS_Shape)                         cast ok, IsNull=1
A2 TopoDS::Edge(a FACE)                                    CAUGHT Standard_TypeMismatch
A3 TopoDS::Edge(a SOLID box)                               CAUGHT Standard_TypeMismatch

B1 IntTools_EdgeEdge ctor only, both edges null            ok
B2 ctor + Perform, both edges null                         ok, IsDone=0
B3 ctor + Perform, edge1 null, edge2 real                  ok, IsDone=0
B4 ctor + Perform, edge1 real, edge2 null                  ok, IsDone=0
B5 the whole bridge body, both nulls, through the cast      ok, not done
B6 the whole bridge body, edge1 a FACE                     CAUGHT Standard_TypeMismatch
B7 two real overlapping edges (the control)                ok, IsDone=1, 1 common part

C1 IntTools_EdgeFace, null edge and null face, as the
   bridge writes it (SetEdge/SetFace/BRep_Tool::Range)     UNCATCHABLE: signal 11
C2 IntTools_EdgeFace::Perform alone, no BRep_Tool::Range   UNCATCHABLE: signal 11

D1 BRep_Tool::Curve(null edge, f, l)                       UNCATCHABLE: signal 11
D2 BRep_Tool::CurveOnSurface(null edge, null face, f, l)   UNCATCHABLE: signal 11
D3 BRep_Tool::Degenerated(null edge)                       UNCATCHABLE: signal 11
D4 BRep_Tool::Range(null edge, null face, f, l)            UNCATCHABLE: signal 11
D5 BRep_Tool::Surface(null face)                           UNCATCHABLE: signal 11
D6 BRep_Tool::Tolerance(null edge)                         UNCATCHABLE: signal 11
```

## The lead: `OCCTIntToolsEdgeEdge` needs no guard

`IntTools_EdgeEdge` tolerates a null `TopoDS_Edge` end to end. Its constructor stores the edges
(B1), and `Perform()` answers `IsDone() == false` rather than faulting (B2 through B4), so the
bridge's `if (!ee.IsDone())` branch returns the `false` it already returns for any input it cannot
intersect (B5). A wrong-typed shape never gets that far: `TopoDS::Edge` raises a catchable
`Standard_TypeMismatch` that the function's own `catch (...)` turns into the same refusal (A2, A3,
B6). Adding a guard there would be the noise `okf/policies/null-handle-guards.md` warns against,
and `check-null-handle-guards.py` is right not to report it.

The sibling is the asymmetric one, and its guard is load-bearing twice over.
`IntTools_EdgeFace::Perform()` faults on a null edge on its own (C2), and the
`BRep_Tool::Range(e, first, last)` call that #1631 added to repair `myRange`'s `(0, 0)` default
faults on it too (D1's family). So `OCCTIntToolsEdgeFace` has a guard because it needs one and
`OCCTIntToolsEdgeEdge` does not because it does not. Same file, adjacent functions, opposite and
correct answers.

## The blind spot: the reference declaration

#1513 taught the shape walk the split-statement cast, `SHAPE_CAST_DECL`, whose regex opens

```python
r'\bTopoDS_\w+\s+(\w+)\s*=\s*TopoDS::(?:...)\s*\(\s*(\w+)...->\s*(\w+)\s*\)\s*;'
```

`\bTopoDS_\w+\s+` demands whitespace immediately after the type name, so it matches the value
declaration and not the reference one, where a `&` sits there instead. Counted over
`Sources/OCCTBridge/src/*.mm`:

```bash
# value form, matched:                  109
grep -rEc "TopoDS_[A-Za-z]+ +[A-Za-z_0-9]+ *= *TopoDS::[A-Za-z]+ *\( *[A-Za-z_0-9]+ *-> *[a-z]+ *\) *;" \
  Sources/OCCTBridge/src/*.mm | awk -F: '{n+=$2} END {print n}'
# reference form, NOT matched:           53
grep -rEc "TopoDS_[A-Za-z]+ *& *[A-Za-z_0-9]+ *= *TopoDS::[A-Za-z]+ *\( *[A-Za-z_0-9]+ *-> *[a-z]+ *\) *;" \
  Sources/OCCTBridge/src/*.mm | awk -F: '{n+=$2} END {print n}'
```

Widening the quantifier to `\s*&?\s+` takes the gate from "All bridge functions guard the shape as
well as the wrapper pointer" to seven parameter sites in four functions:

| function | parameters | reaches | refusal it already gave |
|---|---|---|---|
| `OCCTBRepToolsEvalAndUpdateTol` | `edge`, `face` | `BRep_Tool::Curve`, `CurveOnSurface`, `Surface`, `Tolerance` | `0.0` |
| `OCCTBRepToolCurveOnSurface` | `edge`, `face` | `BRep_Tool::CurveOnSurface` | `nullptr` |
| `OCCTBRepToolDegenerated` | `edge` | `BRep_Tool::Degenerated` | `false` |
| `OCCTBRepToolRangeOnFace` | `edge`, `face` | `BRep_Tool::Range` | `false` |

Every one of those consumers was already in the gate's own `SHAPE_DEREF_QUALIFIED` table, measured
by `Scripts/repro/1035-unwrap-guard`. This was not the open tail of unmeasured OCCT entry points
that `null-handle-guards.md` warns is real; it was the walk failing to hand a shape to a table that
already knew the answer.

All four are public Swift statics taking `Shape`, so `Shape.nullified` reaches them in one line:

```swift
_ = Shape.isDegenerated(edge: box.nullified!)                       // signal 11, before the fix
_ = Shape.curveOnSurface(edge: box.nullified!, face: aFace)         // signal 11
_ = Shape.rangeOnFace(edge: box.nullified!, face: aFace)            // signal 11
_ = Shape.evalAndUpdateTolerance(edge: box.nullified!, face: aFace) // signal 11
```

`Tests/OCCTTopologyTests/Issue2812CastReferenceSpellingGuardTests.swift` holds the regression, with
a control beside each refusal: an unconditional refusal passes every "returns nil" assertion, so
the real answers have to be asserted too. Proved in both directions. With the four guards reverted
to their pointer-only test the suite does not fail, it dies: `exited with unexpected signal code 11`
before any expectation is recorded. With the guards replaced by an unconditional refusal, four of
the five tests fail on their controls. Fixtures `SS`/`ST` are the same round trip inside the gate's
own `--self-test`: reverting the regex takes it to `53/54` with `SS` reported as `NOT REPORTED`
while the tree still reads clean.

## What is still blind, measured rather than assumed

Assignment to a variable declared on an earlier line, which `SHAPE_CAST_DECL` cannot match because
the type is not on the statement:

```bash
grep -rEn "^ *[A-Za-z_0-9]+ *= *TopoDS::[A-Za-z]+ *\( *[A-Za-z_0-9]+ *-> *[a-z]+ *\) *;" \
  Sources/OCCTBridge/src/*.mm
```

Six sites in three files (`OCCTBridge_Healing_Misc.mm`, `OCCTBridge_Modeling_SolidPrimitives.mm`,
`OCCTBridge_Modeling_Features.mm`). Making the type prefix optional reports those six and finds
nothing new, so they are recorded in the module docstring rather than matched: a type-less pattern
also matches an out-parameter store such as `*outEdge = TopoDS::Edge(x->shape);` and would start
tracking a name the function does not own.
