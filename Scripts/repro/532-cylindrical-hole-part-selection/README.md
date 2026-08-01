# OCCTSwift#532 ground truth: `BRepFeat_MakeCylindricalHole` selects parts of the cut result, not parts of the tool

`PerformUntilEnd` and the ranged `Perform(Radius, PFrom, PTo)` report `BRepFeat_NoError` while
removing **no material at all** when the drill axis crosses more than one body. Found while measuring
both hole-drilling families for [#496](https://github.com/SecondMouseAU/OCCTSwift/issues/496)
([`Scripts/repro/496-drill-hole-contracts/`](../496-drill-hole-contracts)), documented and pinned
there rather than fixed.

This probe root-causes it. The trigger is not "more than one body" and the blast radius is not two
modes: **four** of the five modes are affected, and a single solid reproduces it.

## Compile and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/532-cylindrical-hole-part-selection/occt_532_part_selection.mm \
  -o /tmp/occt_532_part_selection
/tmp/occt_532_part_selection
```

No fixture files: every case is built from primitives. To measure the *stock* kernel against a
patched one, compile `BRepFeat_MakeCylindricalHole.cxx` as its own TU and link it **before** the
archive (the flags need `-DNo_Exception`, matching the Release kernel — see
[#487](https://github.com/SecondMouseAU/OCCTSwift/issues/487)):

```bash
clang++ -std=c++17 -w -c -DNo_Exception -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  Libraries/occt-src/src/ModelingAlgorithms/TKFeat/BRepFeat/BRepFeat_MakeCylindricalHole.cxx \
  -o /tmp/mch.o
# ...then add /tmp/mch.o to the link line above, ahead of -lOCCT-macos.
```

## The defect

Every mode that chooses which piece of the drilling tool to keep does this:

```cpp
SetOperation(Fuse);        // -> BOPAlgo_CUT
BOPAlgo_BOP::Perform();    // myShape := object CUT tool
PartsOfTool(parts);        // explores myShape for SOLIDs
... KeepPart(chosen) ...
```

`BRepFeat_Builder::PartsOfTool()` (`BRepFeat_Builder.cxx:107`) collects the solids of `myShape` —
which holds the tool split by the object only after the **COMMON** pass. After a CUT, `myShape` is
the finished workpiece. So the selection loops compare barycentres of *bored plates* and then
register those plates as "kept parts of the tool". `PerformResult()` sees a non-empty `myShapes` and
takes the kept-parts path with a keep set that contains no tool part at all, so nothing is subtracted
and the caller gets the input back with the cylinder's faces imprinted on it.

The probe prints the list the selection loop actually sees. On the two-plate stack, before the fix:

```
  PerformUntilEnd          NoError   nbparts=2 removed=    -0.0000  faces 12->20  solids 2->4
      part 0: vol= 48429.2037  baryParam=  15.0000  faces=7      <- a bored plate (50000 - 1570.7963)
      part 1: vol= 48429.2037  baryParam=  55.0000  faces=7      <- the other bored plate
```

and after:

```
  PerformUntilEnd          NoError   nbparts=2 removed=  3141.5927  faces 12->14  solids 2->2
      part 0: vol=  1570.7963  baryParam=  15.0000  faces=3      <- the bore in plate A
      part 1: vol=  1570.7963  baryParam=  55.0000  faces=3      <- the bore in plate B
```

`Perform(Radius)` — the infinite-cylinder through-all — selects no parts, never calls
`PartsOfTool()`, and was never affected. That is why it is the one mode that already drilled a stack
correctly, and the reason the defect reads as "multi-body" rather than "part selection".

### The kernel's other two users get this right

`BRepFeat_Form` (`BRepFeat_Form.cxx:806`) and `BRepFeat_RibSlot` (`BRepFeat_RibSlot.cxx:224`) drive
the same builder and both call the **two-argument** overload,
`SetOperation(myFuse, bFlag)` with `bFlag` true, before `Perform()` — which selects
`BOPAlgo_COMMON` instead of `BOPAlgo_CUT` and makes `PartsOfTool()` mean what its name says.
`PerformResult()` re-derives `myOperation` from `myFuse`, so the operation finally built is the CUT
either way. `BRepFeat_MakeCylindricalHole` calls the one-argument overload at all five sites.

The fix is that two-argument call at the four part-selecting sites, carried as
[`Scripts/patches/0020-BRepFeat_MakeCylindricalHole-select-tool-parts-532.patch`](../../patches/0020-BRepFeat_MakeCylindricalHole-select-tool-parts-532.patch).

## Measured

Stock is `OCCT 8.0.0p1` + this project's carried patches. Drill `r = 5` from `(0, 0, 15)` along `-Z`
unless noted. One 20mm bore removes `1570.7963`. "boolean" is `BRepPrimAPI_MakeCylinder` +
`BRepAlgoAPI_Cut`, the recipe behind `Shape.drilled`.

### Compound of two 50×50×20 plates (A at axis 5…25, B at 45…65) — boolean removes 3141.5927

| call | status | before | after |
|---|---|---|---|
| `Perform(R)` | `NoError` | 3141.5927 | 3141.5927 |
| `PerformUntilEnd` | `NoError` | **0.0000** | 3141.5927 |
| `PerformThruNext` | `NoError` | 1570.7963 | 1570.7963 |
| `PerformBlind(20)` | `NoError` | **0.0000** | 1178.0972 |
| `Perform(R, 0, 70)` | `NoError` | **0.0000** | 3141.5927 |
| `Perform(R, 0, 30)` | `NoError` | 1570.7963 | 1570.7963 |
| `Perform(R, 30, 70)` | `NoError` | 1570.7963 | 1570.7963 |
| `Perform(R, 26, 44)` | `InvalidPlacement` | — | — |

`PerformBlind` is affected too; #532 named only `PerformUntilEnd` and the ranged `Perform` because
those were the two extents #496 had newly wrapped.

### Compound of three plates (5…25, 45…65, 85…105) — boolean removes 4712.3890

| call | status | before | after |
|---|---|---|---|
| `PerformUntilEnd` | `NoError` | **0.0000** | 4712.3890 |
| `PerformBlind(20)` | `NoError` | **0.0000** | 1178.0972 |
| `Perform(R, 0, 110)` | `NoError` | **0.0000** | 4712.3890 |
| `Perform(R, 0, 70)` | `NoError` | **0.0000** | 3141.5927 (plates A and B — the pair the window names) |

### ONE solid an `r = 5` bore severs (an 8mm-wide bar) — boolean removes 1407.2952

The trigger is "the CUT result has two solids", and a single body reaches it. No compound involved:

| call | status | before | after |
|---|---|---|---|
| `PerformUntilEnd` | `NoError` | **0.0000** | 1407.2952 |
| `PerformThruNext` | `NoError` | **0.0000** | 1407.2952 |
| `Perform(R, 0, 30)` | `NoError` | **0.0000** | 1407.2952 |

### Unaffected geometries (the selection machinery now runs, and agrees)

A single 50×50×20 plate is byte-identical before and after — the CUT result is one solid, so
`nbparts` is 1 and the branch never ran. Two cases where the branch's *inputs* change but its answer
does not, which is the non-regression evidence that matters:

| stock | call | before | after | `nbparts` before → after |
|---|---|---|---|---|
| channel, one solid, two spans on the axis | `PerformUntilEnd` | 3141.5927 | 3141.5927 | 1 → 2 |
| hollow box, one solid, four crossings (origin z = 30) | `PerformUntilEnd` | 785.3982 | 785.3982 | 1 → 2 |

Both previously took the `nbparts == 1` shortcut by accident and now select two real tool parts,
keeping both, for the same result.

### One behaviour change beyond the bug

A radius so large the bore swallows the whole workpiece (`r = 100` on a 50mm plate):

| call | before | after |
|---|---|---|
| `Perform(R)` | empty result | empty result |
| boolean | empty result | empty result |
| `PerformUntilEnd` / `PerformThruNext` | `InvalidPlacement` | empty result |

Under CUT, "the tool ate everything" emptied `myShape`, so `nbparts` was 0 and the
`if (nbparts == 0)` guard reported `InvalidPlacement`. Under COMMON the tool meets the whole
workpiece, `nbparts` is 1, and the two modes return the same empty result `Perform(Radius)` and a
plain boolean cut already returned. `nbparts == 0` now means what the guard reads as — the tool meets
nothing. All five extents and the boolean drill now agree on this request; #496's tests were updated
to the converged answer rather than the old accident.

## A second defect in the same heuristic, not fixed here

`PerformThruNext`'s closest-interval fallback (`BRepFeat_MakeCylindricalHole.cxx:217-242`) has a
misplaced brace: the `// parbar > Last` branch is nested *inside* `if (parbar < First)`, as the
`else` of the distance comparison, so the "beyond `Last`" case is unreachable as written.
`PerformBlind`'s equivalent fallback (`:602-616`) has no such structure — it compares
`std::abs(First - parbar)` uniformly. The fallback only runs when no tool part's barycentre lies in
`[First, Last]`, which none of the geometries here produce, so this is reported rather than fixed:
changing it without a case that reaches it would be a guess.
