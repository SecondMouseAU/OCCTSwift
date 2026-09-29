# #2875: the Bezier pole ceiling, measured at both boundaries

`Geom2d_BezierCurve` and `Geom_BezierCurve` state their pole ceiling three times and state it
differently each time. This directory holds the probe that measured all three against the pinned
kernel, and the transcript it produced.

Run it with `Scripts/repro/2875/run.sh`. It compiles `probe.mm` against the xcframework SwiftPM
resolved into `.build/artifacts`, which is the asset `Package.swift` pins, and runs each case in
its own process, because one of them aborts.

## The three statements, all with `BSplCLib::MaxDegree() == 25`

| site | predicate as written | ceiling it imposes |
|---|---|---|
| `Geom2d_BezierCurve.cxx:78`, `:93` and `Geom_BezierCurve.cxx:93`, `:109` (constructors) | `nbpoles < 2 \|\| nbpoles > MaxDegree() + 1` | **26 poles** |
| `Geom2d_BezierCurve.hxx:137`, `Geom_BezierCurve.hxx:134` (the header comment on `InsertPoleAfter`) | "Raised if the **resulting** number of poles is greater than MaxDegree + 1" | **26 poles** |
| `Geom2d_BezierCurve.cxx:199` and `Geom_BezierCurve.cxx:214` (`InsertPoleAfter` itself) | `nbpoles >= MaxDegree()` | **25 poles** |

`Increase()` is a fourth statement and it agrees with the constructors: `Deg > MaxDegree()` at
`Geom2d_BezierCurve.cxx:144` and `Geom_BezierCurve.cxx:148` permits degree 25, which is 26 poles.

So `InsertPoleAfter` is the only site out of step, it is out of step with its own header comment,
and it is out of step in the safe direction: it refuses one insertion the rest of the class treats
as legal. Both classes carry the identical predicate, so **the 3D twin has the same defect**.

The bound the other three sites agree on is the one that is structurally required.
`Geom2d_BezierCurve::Multiplicities()` and `::KnotSequence()` return a reference into a function
static sized `std::array<..., BSplCLib::MaxDegree() + 1>`, indexed `[myPoles.Length() - 1]`
(`Geom2d_BezierCurve.cxx:769` and `:794`). 26 poles is the last in-bounds index; 27 is not.

## What the probe measured, 2026-09-30, against `v4.0.0-kernel.3`

```
case 0: BSplCLib::MaxDegree() == Geom_BezierCurve::MaxDegree()
        == Geom2d_BezierCurve::MaxDegree() == 25

case 1: constructors, both classes
        2, 25 and 26 poles all build; 27 poles throws Standard_ConstructionError

case 2: 3D InsertPoleAfter, whose guard is a literal throw and so is live
        24 poles -> accepted, 25 poles
        25 poles -> THREW Standard_ConstructionError
        26 poles -> THREW Standard_ConstructionError

case 3: 2D InsertPoleAfter at 25 poles, whose guard is the macro and so is gone
        accepted, 26 poles, Multiplicities() == [26, 26], KnotSequence().Length() == 52,
        Value(0.5) == (13.500002, 1.000000)
        the curve is sound; the 3D twin refuses this exact operation

case 4: 2D InsertPoleAfter at 26 poles
        accepted, 27 poles, then Multiplicities() reads THE_MULTS[26] out of a 26-entry
        std::array and the process aborts: "uncaught exception of type Standard_OutOfRange:
        NCollection_Array1::Value", exit 134

case 5: Increase()
        3D Increase(25) accepted (26 poles), Increase(26) THREW
        2D Increase(25) accepted (26 poles), Increase(26) accepted, 27 poles, degree 26

case 6: the 2D side, one insertion at a time from 2 poles, reaches 27 and never throws
```

Case 3 is the finding: the kernel that has no check builds the 26-pole curve correctly, which is
the evidence that 26 is the right ceiling and `nbpoles >= MaxDegree()` is one too strict.

Case 4 is the reason the strict predicate is not simply relaxed in the bridge. Nothing in the 2D
kernel stops the count at all, so the bridge's guard is what keeps a Swift caller off the
out-of-bounds read, and it was added by #2870 for #2859. Case 5's 2D row is the same mechanism at
`Increase()`, and #2859 guarded it in the same PR.

## Why nothing was changed

Relaxing `OCCTCurve2DBezierInsertPoleAfter` to the documented ceiling would let 2D accept an
operation the 3D kernel throws on, so `Curve2D` and `Curve3D` would stop agreeing. The kernel's 3D
throw is a literal one and cannot be guarded away from the bridge. So the only way to keep the two
Swift surfaces the same is to keep the strict bound on both, which is what they have.

The kernel change is a one-character upstream fix, `>=` against `MaxDegree() + 1` at both sites,
and it is not carried: there is no crash and no fabricated measurement behind it, only a refusal,
and a carried patch that *relaxes* a kernel check buys nothing a caller can use while diverging the
pin. Held for the OCCT 8.0.2 survey under the same hold as patch `0043`.

`Tests/OCCTGeom2dTests/Issue2875BezierPoleCeilingTests.swift` pins every number above through the
Swift API, so a kernel bump that moves either boundary fails a test rather than passing quietly.
