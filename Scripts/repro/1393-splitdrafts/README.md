# #1393: why `LocOpe_SplitDrafts` has no passing test, measured

`Shape.splitDrafts` was wrapped and documented with no test anywhere in the tree. #818 recorded two
failure modes it had hit and asked for a construction that reaches `IsDone() == true`. There is
none on this kernel, and the reason is in `GeomConvert`, not in the caller.

## The chain

1. `LocOpe_SplitDrafts::Perform` only accepts a **planar** face: its file-local `NewPlane()` helper
   intersects the neutral plane with the face's own plane and requires a real line, so the neutral
   plane must differ from the face's plane (this is #818's first finding, and it is correct).
2. Past that, `Perform` builds `GeomInt_IntSS` between the two drafted planes and pipes along it:
   `thePipe.Init(theLinePipe, i2s.Line(1))`. **The intersection of two planes is always a
   `Geom_Line`.**
3. `GeomFill_Pipe::Perform` converts its section curve through
   `GeomConvert::CurveToBSplineCurve`, whose type chain handles circle, ellipse, hyperbola,
   parabola, Bezier, B-spline and offset curves, and whose final `else` is
   `throw Standard_DomainError("No such curve")`. **A line is not in the chain.**

So every call that gets past step 1 throws at step 3, whatever the caller does. #818's second
finding, "a hand-built edge throws No such curve", was the same throw seen from a different angle:
the missing pcurve was never the cause.

## Reproducers

`probe.mm` is the caller-side attempt: a box, its top face, and a splitting edge built **on the
face** from a `Geom2d_Line` plus the face surface with `BRepLib::BuildCurves3d`, which is the
construction #818 had not tried. Four extraction directions and angles, all four throw
`No such curve`.

```
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1393-splitdrafts/probe.mm -o /tmp/occt_1393 && /tmp/occt_1393
```

`probe_geomconvert.mm` is the kernel-side isolation, three lines of it:

```
GeomConvert(Geom_Line) THREW: No such curve
IntSS done=1 nbLines=1
line 1 type: Geom_Line
libc++abi: terminating due to uncaught exception of type Standard_DomainError: No such curve
```

The last line matters on its own: the same throw, raised from inside `GeomFill_Pipe::Perform`
rather than from `GeomConvert` directly, **escaped a `catch (Standard_Failure const&)` and aborted
the process**. Through the bridge it is catchable (the Swift call returns `nil`, which is what the
regression test asserts), so this is a difference in where the throw crosses, not in whether it
happens.

## Disposition

- **Test**: `Tests/OCCTModelingTests/Issue1393SplitDraftsTests.swift` asserts the refusal, and says
  in its own comment that a non-nil result means a repin fixed the kernel and the test should then
  become a behavioural one. Proven to fail by making the bridge's `catch (...)` return the input
  shape instead of `nullptr`.
- **Upstream**: `GeomConvert::CurveToBSplineCurve` has no `Geom_Line` case, though a line is a
  degree-1 B-spline with two poles and is trivially convertible. That is the fix worth sending, and
  it makes `LocOpe_SplitDrafts` work rather than just stop throwing. Queued with the other upstream
  submissions.
- **Not done**: no bridge-side guard. Refusing the call up front would be refusing the whole
  operation, and the `nil` it already returns is the same answer with the kernel's own reason
  behind it.
