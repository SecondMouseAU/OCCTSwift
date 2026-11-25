# OCCTSwift#3524 ground truth: `BRepFilletAPI_MakeFillet` radius setters after a build or a simulation

`occt_3524_setradius_after_build.mm` runs every `(fixture, case, builder state)` triple in its own
forked child, so a SIGSEGV is a cell in the table and not the end of the probe. `probe-output.txt` is
its full output on the pinned kernel (OCCT V8_0_2 plus the carried patches, `macos-arm64`). `SEGV` is
SIGSEGV or SIGBUS. Every index here is VALID: contour 1 (and 2 where the state has two), edge 1.

## Compile and run

```bash
XC=Libraries/OCCT.xcframework      # or .build/artifacts/<package>/OCCT/OCCT.xcframework
clang++ -std=c++17 -ObjC++ -w -I"$XC/macos-arm64/Headers" -L"$XC/macos-arm64" -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/3524/occt_3524_setradius_after_build.mm -o /tmp/occt_3524
/tmp/occt_3524 > Scripts/repro/3524/probe-output.txt
```

## Why it faults

`ChFiDS_FilSpine::SetRadius(const gp_XY& UandR, const int IinC)` (`ChFiDS_FilSpine.cxx:143-215`)
inserts the `(abscissa, radius)` pair and then, `if (splitdone)`, replays the radius law:

```cpp
NCollection_List<occ::handle<ChFiDS_ElSpine>>::Iterator It(elspines);
NCollection_List<occ::handle<Law_Function>>::Iterator   Itl(laws);
occ::handle<ChFiDS_ElSpine>                             Els = It.Value();   // empty list
```

with no test that `elspines` holds anything. Two things decide it:

- `splitdone` is set by `ChFiDS_Spine::SplitDone(true)` at the end of
  `ChFi3d_Builder::PerformSetOfKPart` (`ChFi3d_Builder_2.cxx:3351`), which `Build()` runs on every
  stripe and `Simulate(IC)` on one. `ChFiDS_Spine::Reset()` clears it, and `ChFi3d_Builder::Reset()`
  (so `BRepFilletAPI_MakeFillet::Reset`) runs that on every stripe.
- `elspines` is empty when an analytic blend (plane and plane, plane and cylinder, ...) covered the
  whole spine. A spine whose blend is not analytic has elementary spines, and the replay is safe.

Four public entry points end in that function:

| entry point | route |
|---|---|
| `SetRadius(R, IC, vertex)` | `FilSpine::SetRadius(R, V)` then `SetRadius(UandR, 0)` |
| `SetRadius(R1, R2, IC, IinC)` | `FilSpine::SetRadius(UandR, IinC)`, twice |
| `Add(R, E)` for an edge already in a contour | `Contains(E, IinC)`, then `SetRadius(R, IC, IinC)` (`BRepFilletAPI_MakeFillet.cxx:67-91`) |
| `Add(R1, R2, E)` for an edge already in a contour | the same, with two radii |

`SetRadius(R, IC, edge)` goes through `FilSpine::SetRadius(R, E)`, which sets `splitdone = false`
first, and never reaches the replay. The issue named the first two; the `Add` pair is the same fault.

## Measured

Faulting cells, valid index, `box` and `cyl` fixtures (the `spline` fixture, a prism with a
BSpline-edged face, never faults):

| state | `IsDone()` | `SetRadius(R, IC, vertex)`, `SetRadius(R1, R2, IC, 1)`, `Add(R, E)`, `Add(R1, R2, E)` |
|---|---|---|
| edge added, nothing run | false | ok |
| `Simulate(1)` | **false** | **SEGV** |
| `Simulate(1)`, `Reset()` | false | ok |
| `Build()` completed | true | **SEGV** |
| `Build()` completed, `Reset()` | false | ok |
| `Build()` completed, then `SetRadius(R, 1, edge)` | true | ok (the edge form cleared `splitdone`) |
| declined (R 20) | false | ok (the sequence is set and empty) |
| two contours, `Build()` completed | true | **SEGV**, contours 1 and 2 |
| two contours, only `Simulate(1)` | false | **SEGV** on contour 1, ok on contour 2 |
| two contours, the second declined (R 20) | **false** | **SEGV** on contour 1, ok on contour 2 |

So `IsDone()` is not the predicate. It is false after a `Simulate` and after a build that completed
one contour and declined another, and both fault. `NbComputedSurfaces(IC)` is above 0 for exactly the
contours that fault in these states, and 0 for the ones that do not (it is the null-tested read of the
stripe's surface data, the predicate #3519 uses for `NbSurf`).

## Which callers OCCT has

None sets a radius after a build. `BRepTest_FilletCommands.cxx:176-198`, `DNaming_FilletDriver.cxx:129-158`,
`QABugs_17.cxx:515-580` and `ViewerTest_FilletCommands.cxx:103-125` add edges with their radii and call
`Build()` once. `BRepFilletAPI_MakeFillet.hxx` says how to change a built fillet: `Reset()` "allows
modifications to be made to the contours and fillet parameters in order to rebuild the shape". So the
refusal in the bridge is the contract and not a restriction on top of it.
