# OCCTSwift#496 ground truth: the boolean drill and `BRepFeat_MakeCylindricalHole` are not the same operation

One standalone probe, run against the pinned `OCCT.xcframework` (8.0.0p1 + our carried patches), that
measures both of OCCTSwift's hole-drilling families side by side on the same requests.

#496 read `OCCTShapeDrillHole` (`BRepPrimAPI_MakeCylinder` + `BRepAlgoAPI_Cut`, with a
bounding-box-diagonal length for through holes) as a cruder reimplementation of
`BRepFeat_MakeCylindricalHole`, and proposed folding the first into the second. This probe is what
that proposal was tested against. It does not survive: **six of thirteen probed requests change
answer** under a delegation, in the direction of losing work that currently succeeds.

No fixture files: every case is built from primitives.

## Compile and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/496-drill-hole-contracts/occt_496_drill_contracts.mm -o /tmp/occt_496_drill_contracts
/tmp/occt_496_drill_contracts
```

`booleanDrill` in the probe is a faithful replica of `OCCTShapeDrillHole`'s body; `featDrill` mirrors
the `OCCTBRepFeatCylindricalHole*` bodies, deliberately *without* a zero-direction guard, so the raw
kernel behaviour is what gets measured.

## The thirteen requests

Stock is a 50 × 50 × 20 plate centred on the origin unless noted, drilled at r = 5 from (0, 0, 15)
along −Z. A full bore removes 1570.7963.

| # | request | boolean | `Perform` | `PerformUntilEnd` | `PerformThruNext` |
|---|---|---|---|---|---|
| A | through-hole, entry above the top face | 48429.20 | 48429.20 | 48429.20 | 48429.20 |
| B | blind, depth 11 from z = 11 | 49214.60 | 48429.20 | 48429.20 | 48429.20 |
| C | +X through a bar (#272 regression) | 165453.54 | 165453.54 | 165453.54 | 165453.54 |
| D | axis misses the shape entirely | unchanged | `InvalidPlacement` | `InvalidPlacement` | `InvalidPlacement` |
| E | blind depth 100 into 20mm of stock | 48429.20 | 48429.20 | 48429.20 | 48429.20 |
| F | entry point **inside** the solid | 49214.60 | 48429.20 | 48429.20 | 48429.20 |
| G | radius 100, wider than the stock | empty | empty | `InvalidPlacement` | `InvalidPlacement` |
| H | compound of two stacked solids | 96858.41 | 96858.41 | **100000.00** | 98429.20 |
| I | input is a **shell** | 49476.40 | 49476.40 | `InvalidPlacement` | `InvalidPlacement` |
| J | input is a single **face** | ok | `InvalidPlacement` | `InvalidPlacement` | `InvalidPlacement` |
| K | oblique axis through a sphere | 110094.79 | 110094.79 | 110094.79 | 110094.79 |
| L | entry exactly on the surface | 48429.20 | 48429.20 | 48429.20 | 48429.20 |
| M | axis tangent to a corner edge | 7858.63 | 7858.63 | 7858.63 | 7858.63 |

`PerformBlind` is run wherever a depth is given: it matches the boolean path exactly in B
(49214.60), and reports `HoleTooLong` in E.

### What the divergences are

1. **`Perform` is an infinite cylinder, both ways along the axis.** The axis origin anchors the
   axis; it is not where the hole starts. Case F is the proof: drilling "down" from the plate's own
   midplane, the boolean path removes the 10mm below the origin and `Perform` removes all 20.
2. **`PerformUntilEnd` is not forward-only either.** Its documentation says "every hole located
   after the origin of the given axis", but the implementation
   (`BRepFeat_MakeCylindricalHole.cxx:256`) uses `LocalizeAfter(0.)` only to pick the *starting*
   intersection and then resets backwards to the entry face, so case F removes all 20mm too. It
   bounds the hole by the stock's own first and last faces.
3. **`PerformBlind` refuses a depth that leaves the stock.** Case E: the boolean path treats an
   over-long depth as a harmless overshoot and drills through; `PerformBlind` reports
   `BRepFeat_HoleTooLong` and produces nothing. "Pass a depth comfortably past the far face" is a
   normal way to drill through without computing the thickness, and it would stop working.
4. **The feature drill wants a solid.** Cases I and J: a shell or a face is `InvalidPlacement` for
   every mode but `Perform`.
5. **Case H is an outright wrong answer.** On a compound of two stacked solids, `PerformUntilEnd`
   reports `BRepFeat_NoError`, leaves the volume at 100000.0000, *no material removed*, and adds 8
   faces, having imprinted the cylinder without cutting. See below.

## The ranged `Perform(Radius, PFrom, PTo)`

Not previously wrapped, and its parameters do not mean what the name suggests. Against a single
plate, **every** window produces the identical full bore, including windows entirely before or
entirely after the stock:

| window | removed |
|---|---|
| [0, 100] | 1570.7963 |
| [5, 15] | 1570.7963 |
| [15, 25] | 1570.7963 |
| [0, 5] | 1570.7963 |
| [25, 100] | 1570.7963 |

Against a stack of two plates (A at axis parameters 5…25, B at 45…65) the actual contract shows:

| window | removed | reading |
|---|---|---|
| [0, 30] | 1570.7963 | plate A only |
| [30, 70] | 1570.7963 | plate B only |
| [10, 20] | 1570.7963 | all of plate A, a window strictly *inside* a body still drills through it |
| [26, 44] | `InvalidPlacement` | the gap names no face pair |
| [0, 70] | **0.0000** | spans both bodies: `NoError`, nothing removed |

So the window **selects which entry/exit face pair bounds the hole**; it does not trim the cut. That
makes it the only spelling that can pick *which* body in a stack to drill, which is why it is worth
wrapping, but the docs have to say so.

## The multi-body defect (cases H and [0, 70])

`PerformUntilEnd` (`:315`) and the ranged `Perform` (`:421`) both end in an `nbparts >= 2` branch
that keeps exactly **one** part of the cutting tool. When the axis crosses more than one body, the
part it keeps can be one that intersects nothing, and the operation then reports `BRepFeat_NoError`
while removing no material, the input with the cylinder's faces imprinted on it. A silent wrong
answer, not a failure.

Neither `Perform` nor the boolean drill has that branch, and both cut every body on the axis.

This is upstream behaviour, out of scope for #496's deduplication and filed as #532. It is documented on
`CylindricalHoleExtent.untilEnd` / `.range`, and pinned by
`Issue496CylindricalHoleTests.multiBodyExtentsRemoveNothing` so a kernel bump that changes it is
noticed.

## The radius precondition

The pinned xcframework is a Release build, so OCCT's own `*_Raise_if` preconditions are compiled out
by `No_Exception` (#487) and nothing below the bridge rejects a degenerate radius.

| radius | boolean | every `BRepFeat` mode |
|---|---|---|
| 0 | returns a shape | `NoError`, volume 50000.0000, 6 faces, **no material removed** |
| 1e-14 | returns a shape | `NoError`, volume 50000.0000, 6 faces, **no material removed** |
| −5 | throws | throws |

A drill that reports success and hands back the undrilled input is the worst of the three possible
answers. `OCCTShapeDrillHole` guarded `radius <= 0`, which caught the zero but not the sub-tolerance
case; the feature family guarded nothing at all. Both now share `occtValidDrillRadius`, which
requires the radius to exceed `Precision::Confusion`.

## Zero direction

| | measured |
|---|---|
| boolean | rejected by its own `dirLen < 1e-10` guard |
| feature | `gp_Dir()` throws "input vector has zero norm", swallowed by the function's own `catch (...)` |

The same answer, reached by an accident. Both now share `occtValidDrillDirection`.
