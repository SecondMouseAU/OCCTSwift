# #1632: `Extrema_ExtElSS` implements plane/plane, and even that computes no points

`ExtremaElSS.planeToSphere` and `sphereToSphere` always returned `[]`, and `planeToPlane`'s
parallel branch returned `point1 == point2 == SIMD3(0, 0, 0)`. Found by #1399's booleans-family
read, re-measured here against the pinned 8.0.1 kernel before deciding what the API should do.

```
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1632-extremaelss-refusal/probe.mm -o /tmp/occt_probe_1632 && /tmp/occt_probe_1632
```

`transcript.txt` holds the output:

```
=== Extrema_ExtElSS on the pinned 8.0.1 kernel
  plane/plane parallel     IsDone=1 IsParallel=1 NbExt=1 SquareDistance(1)=25
  plane/plane crossing     IsDone=1 IsParallel=0 NbExt=0
  plane/sphere             ctor THREW 23Standard_NotImplemented ()
  sphere/sphere            ctor THREW 23Standard_NotImplemented ()
  sphere/cylinder          ctor THREW 23Standard_NotImplemented ()
  sphere/cone              ctor THREW 23Standard_NotImplemented ()
  sphere/torus             ctor THREW 23Standard_NotImplemented ()
```

Five of the six non-plane pairs the class declares are `throw Standard_NotImplemented();` in OCCT
itself, so `planeToSphere` and `sphereToSphere` wrapped kernel entry points that do not exist. The
throw happens inside the constructor the bridge calls, lands in its `catch (...)`, and comes back
as `[]`, which is the same thing this namespace says when a real solve finds no extrema.

Plane/plane is implemented, and reports one extremum only when the planes are parallel. Crossing
planes meet, so their distance is zero all along the intersection line, and the class records no
extremum for that rather than an extremum of zero.

## Why the probe never calls `Points()`

`Perform(gp_Pln, gp_Pln)` sets `myNbExt = 1` in its parallel branch and fills `mySqDist` alone,
leaving `myPOnS1` and `myPOnS2` as null `NCollection_HArray1` handles (the private members are in
`Extrema_ExtElSS.hxx`). `Points(N, P1, P2)` therefore dereferences a null handle, which is an OS
fault, not a catchable exception, and `OCC_CATCH_SIGNALS` is inert in this build
(`okf/references/known-occt-bugs.md`, #345), so it would take the whole process down.

That fault was established once, by the probe #1632 was filed from, run with its `--points` flag.
There is no reason to reproduce it, and a probe that crashes is a probe nobody can run in a loop,
so this one asserts the null-handle fact from the header and stays away from the call. The bridge
does the same.

## What was done about it

`planeToSphere` and `sphereToSphere` are removed, along with the two bridge functions behind them.
`planeToPlane` returns `(isParallel: Bool, squareDistance: Double?)`: the square distance is the
whole of what OCCT computes, and two parallel planes have no unique closest pair to report anyway,
since every point of one paired with its own projection is a minimum.
