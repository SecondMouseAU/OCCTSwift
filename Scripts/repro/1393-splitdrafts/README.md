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
3. `GeomFill_Pipe::Init` puts that section through `GeomFill_UniformSection`, whose constructor
   calls `GeomConvert::CurveToBSplineCurve`, and that function throws
   `Standard_DomainError("No such curve")` for an **untrimmed** line.

So every call that gets past step 1 throws at step 3, whatever the caller does. #818's second
finding, "a hand-built edge throws No such curve", was the same throw seen from a different angle:
the missing pcurve was never the cause.

## Correction: the missing `Geom_Line` case is not the bug

This file first said `CurveToBSplineCurve`'s type chain "has no `Geom_Line` case" and that adding
one was the fix. Re-reading the function shows that is wrong on both halves.

`CurveToBSplineCurve` has two branches, not one chain. The `Geom_TrimmedCurve` branch **does**
handle `Geom_Line`, at `GeomConvert.cxx:190`, and always has: a trimmed line becomes a degree-1
two-pole B-spline, exactly. Only the untrimmed branch lacks a line case, and its refusal is
deliberate and documented, `GeomConvert.hxx` above the declaration says "Raises DomainError if the
curve C is infinite". `Geom_Line` is infinite, so there is no parameter range to convert over and
nothing correct to add there. Confirmed directly: `GeomConvert::CurveToBSplineCurve` on
`Geom_TrimmedCurve(line, -50, 50)` returns degree 1 with poles at the two trim points.

The defect is in `LocOpe_SplitDrafts`, which hands `GeomFill_Pipe` two infinite lines, the pipe
path (`new Geom_Line(NormalFg)`) as well as the section, and does it a second time further down
`Perform()` on a wire edge's basis curve. `Scripts/patches/0034` trims each to the shape's own
extent, which is the caller's job because only the caller knows the extent.

## Verification of the fix

Override-link, no full kernel rebuild:

```
clang++ -std=c++17 -w -O0 -g -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -c Libraries/occt-src/src/ModelingAlgorithms/TKFeat/LocOpe/LocOpe_SplitDrafts.cxx \
  -o /tmp/splitdrafts.o
clang++ -std=c++17 -ObjC++ -w -O0 -g -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  /tmp/splitdrafts.o Scripts/repro/1393-splitdrafts/probe.mm \
  -L"Libraries/OCCT.xcframework/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ -o /tmp/probe && /tmp/probe
```

Against the pristine translation unit (`git show HEAD:<path>`), all four cases print
`THREW No such curve`. Against the patched one:

```
extract +X, 10 deg     IsDone=1  faces=7 (box has 6)
extract -X, 10 deg     IsDone=1  faces=7 (box has 6)
extract +Z, 10 deg     IsDone=1  faces=7 (box has 6)
extract +X,  5 deg     IsDone=1  faces=7 (box has 6)
```

The result is geometrically right, not merely non-throwing: exactly one face is tilted
`(0.174, 0, 0.985)`, which is 10.000 degrees off vertical, and the volume goes 1000 to 1022.04,
against the 22.04 the drafted wedge adds (`0.5 * 5 * 5*tan(10 deg) * 10`).

`upstream/LocOpe_SplitDrafts_Test.cxx` is the GTest form of the same check. It has no upstream
home: OCCT master deleted `LocOpe_SplitDrafts` in
[OCCT#1442](https://github.com/Open-Cascade-SAS/OCCT/pull/1442) on 2026-08-07 as dead code, having
no caller anywhere in the tree, not even a DRAW command. That is also the most likely reason a
defect this total reached 8.0.1 unnoticed.

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

- **Fix**: `Scripts/patches/0034`, carried, **not pinned**. `Shape.splitDrafts` therefore still
  returns `nil` for every consumer of the released package, and drafts the face against a kernel
  built from `Scripts/patches/`.
- **Test**: `Tests/OCCTModelingTests/Issue1393SplitDraftsTests.swift` holds one test per kernel,
  gated on `OCCTSWIFT_LOCAL`. The pinned side asserts the refusal (what `ci.yml` sees); the
  `kernel-integration.yml` side asserts the drafted result. Both proven to fail with their
  subject broken.
- **Upstream**: nothing to send. OCCT#1442 removed the class from master, so the patch retires by
  deletion at the next kernel bump past that tag, taking `Shape.splitDrafts` with it.
- **Not done**: no bridge-side guard. Refusing the call up front would be refusing the whole
  operation, and the `nil` it already returns is the same answer with the kernel's own reason
  behind it.
