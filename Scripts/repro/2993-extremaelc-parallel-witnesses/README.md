# 2993: `Extrema_ExtElC`'s parallel branch has a real distance and no witness points

Measured against the pinned `v4.0.0-kernel.3` asset on 2026-10-02.
`probe-transcript.txt` is the run; `probe-transcript-fault.txt` is the same probe with any
argument, which adds one deliberately fatal call and exits 139.

## Build and run

```bash
XC=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
clang++ -std=c++17 -ObjC++ -w -I"$XC/Headers" -L"$XC" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2993-extremaelc-parallel-witnesses/probe.mm -o /tmp/occt_probe
/tmp/occt_probe            # the transcript
/tmp/occt_probe --fault    # ...plus the Extrema_ExtElCS fault, exit 139
```

## What it measures

**1. Every `Extrema_ExtElC` parallel branch returns a default-constructed point pair.**
Line/circle on the circle's axis, two parallel lines and two concentric circles all report
`IsParallel() == 1`, `NbExt() == 1` and a correct `SquareDistance(1)` (25, 9 and 4). `Points(1)`
on each hands back `p1 = p2 = (0, 0, 0)` with `u1 = u2 = 0`, which is `Extrema_POnCurv`'s own
default: the constructors set `mySqDist[0]` and `myNbExt = 1` and never touch `myPoint`
(`Extrema_ExtElC.cxx:341-344`, `:595-597`, `:729-732`). `Points()` does not refuse it, because its
bound is `N > NbExt()` and `NbExt()` counts distances (`:1158-1167`).

For the `ExtremaElCLinCircTests.lineOnCircleAxisReturnsRadius` fixture the reported `point2` is the
circle's **centre**, a point 5 from every point of the circle, beside a correct distance of 5.

**2. OCCT's own production caller keeps the distance and reports no point pair.**
`Extrema_ExtCC::PrepareResults(const Extrema_ExtElC&, ...)` (`Extrema_ExtCC.cxx:845-852`) branches
on `IsParallel()` before anything else and calls `PrepareParallelResult(..., AlgExt.SquareDistance())`,
which appends the square distance to `mySqDist` and, where the trimming leaves no representative
pair, appends nothing to `mypoints`. The `Points()` loop is in the `else` arm, so the kernel's own
consumer never reads a point from the parallel branch. Measured end to end: `Extrema_ExtCC` on the
same line and circle answers `IsParallel = 1`, `NbExt = 1`, `SquareDistance(1) = 25`, and
`Points(1)` raises. (That raise is carried patch `0024`'s doing; vanilla reads past the end of an
empty sequence instead, which is #636. Either way there is no point there to read.)

**3. `Extrema_ExtElCS::Points` on its parallel branch is an uncatchable SIGSEGV.**
Found while probing, not part of #2993. `Extrema_ExtElCS.cxx:62-68` (line/plane), `:177-183`
(line/cylinder) and `:384-390` allocate `mySqDist` alone and leave `myPoint1` / `myPoint2` as null
handles while `myNbExt = 1`, and `Points()` (`:788-797`) bounds on `NbExt()` and dereferences them.
`--fault` dies at exit 139 with no `Standard_Failure`. It is the shape carried patches `0024`
(`Extrema_ExtCC`) and `0044` (`Extrema_ExtSS` / `Extrema_ExtCS`) fix in two other classes, and this
is a third. No bridge function reaches it: `OCCTExtremaElCSLinPlane` returns on `IsParallel()`
before the loop, and `OCCTExtremaElCSLinCylinder` refuses an axis-parallel line outright. Held for
the OCCT 8.0.2 survey rather than patched now.
