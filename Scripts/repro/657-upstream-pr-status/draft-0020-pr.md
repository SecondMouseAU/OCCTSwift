# Draft upstream PR for patch `0020` (BRepFeat_MakeCylindricalHole part selection)

**Status: drafted, not sent.** This task's hard constraint forbids opening, editing or commenting
on anything in `Open-Cascade-SAS/OCCT`. Everything below is text a human can paste into a new PR
against that repository's `master` branch in one sitting.

Per `okf/policies/upstream-occt-style.md` and the precedent set by `0018`/[OCCT#1417](https://github.com/Open-Cascade-SAS/OCCT/pull/1417),
`0019`/[OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418) and
`0021`/[OCCT#1420](https://github.com/Open-Cascade-SAS/OCCT/pull/1420): **no companion issue, go
straight to the PR.** The diff itself is already `Scripts/patches/0020-BRepFeat_MakeCylindricalHole-select-tool-parts-532.patch`,
already `clang-format`-clean against OCCT's own root `.clang-format` (verified, see this
directory's `README.md`), and already applies to current upstream `master` with zero rejected
hunks.

Branch to open the PR from: apply `Scripts/patches/0020-*.patch` to a clean checkout of
`Open-Cascade-SAS/OCCT` `master` (`git apply -p1`) and push that as the PR branch. The patch file's
own commit message (its `From:`/`Subject:`/body preamble) is already written to double as this PR's
description; the text below is that same content reformatted as a PR body with headings, matching
how `0019`'s and `0021`'s merged PR descriptions are structured.

---

## Title

```
Modeling Algorithms - BRepFeat_MakeCylindricalHole selects parts of the cut result, not parts of the tool
```

## Body

`BRepFeat_MakeCylindricalHole`'s four modes that choose which piece of the drilling tool to keep,
`PerformThruNext`, `PerformUntilEnd`, the ranged `Perform(Radius, PFrom, PTo)` and `PerformBlind`,
all drive `BRepFeat_Builder` with the wrong operation:

```cpp
SetOperation(Fuse);        // -> BOPAlgo_CUT
BOPAlgo_BOP::Perform();    // myShape := object CUT tool
PartsOfTool(parts);        // explores myShape for solids
... KeepPart(chosen) ...
```

`BRepFeat_Builder::PartsOfTool()` collects the solids of `myShape`, which is only the tool split by
the object after the `BOPAlgo_COMMON` pass. After a `BOPAlgo_CUT`, `myShape` is the finished
workpiece. So the selection loops compare barycentres of the cut result itself and then register
those pieces as "kept parts of the tool." `PerformResult()` takes the kept-parts path with a keep
set containing no tool part at all, and returns the object with the cylinder's faces imprinted on
it and no material removed, reporting `BRepFeat_NoError` throughout.

The other two users of the same builder already do this correctly. `BRepFeat_Form`
(`BRepFeat_Form.cxx:806`) and `BRepFeat_RibSlot` (`BRepFeat_RibSlot.cxx:224`) both call the
two-argument `SetOperation(myFuse, bFlag)` with `bFlag` true before `Perform()`, so
`BOPAlgo_COMMON` runs and `PartsOfTool()` means what its name says. `PerformResult()` re-derives
`myOperation` from `myFuse`, so the operation finally built is the cut either way.
`BRepFeat_MakeCylindricalHole` calls the one-argument overload at all five sites.

## Fix

The two-argument call at the four part-selecting sites. `Perform(Radius)`, the infinite-cylinder
through-all, selects no parts and never calls `PartsOfTool()`; it stays on the one-argument
overload, which is why it was the one mode that already drilled a stack correctly and why the
defect reads as "multi-body" rather than "part selection."

## Reproducer

The defect is invisible whenever the cut result happens to have one solid, the single-plate case
every existing test uses. It appears as soon as it has two: a drill axis crossing two bodies of a
compound, or, with no compound involved, a single bar the bore severs in half.

Two 50x50x20 plates stacked on the drill axis (plate A at axis parameters 5..25, plate B at
45..65), drilled at `r = 5` from `(0, 0, 15)` along `-Z`. One plate's bore removes `1570.7963`:

```cpp
TopoDS_Shape plates = /* compound of the two boxes */;
TopoDS_Shape tool   = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0, 0, 60), -gp::DZ()), 5.0, 60.0);
BRepFeat_MakeCylindricalHole mkHole;
mkHole.Init(plates, tool);
mkHole.PerformUntilEnd();
// before: BRepFeat_NoError, 0 volume removed
// after:  BRepFeat_NoError, 3141.5927 removed (two 20mm bores)
```

| call | status | before | after |
|---|---|---|---|
| `Perform(R)` | `NoError` | 3141.5927 | 3141.5927 (unaffected) |
| `PerformUntilEnd` | `NoError` | 0.0000 | 3141.5927 |
| `PerformThruNext` | `NoError` | 1570.7963 | 1570.7963 |
| `PerformBlind(20)` | `NoError` | 0.0000 | 1178.0972 |
| `Perform(R, 0, 70)` | `NoError` | 0.0000 | 3141.5927 |
| `Perform(R, 0, 30)` | `NoError` | 1570.7963 | 1570.7963 |
| `Perform(R, 30, 70)` | `NoError` | 1570.7963 | 1570.7963 |

`PerformBlind(20)`'s length is measured from the axis origin `(0, 0, 15)`, which sits 5mm above
plate A's entry face at axis parameter 5, not from that face. A blind depth of 20 therefore reaches
axis parameter 20, boring only 15mm of the plate's 20mm thickness: `1178.0972`, matching
`pi * r^2 * 15`. That is the mode's own contract, not a defect this patch touches or a
discrepancy against the other rows.

And on a single 8mm-wide bar an `r = 5` bore severs, where "parts" was two pieces of one workpiece
rather than two bodies:

| call | status | before | after |
|---|---|---|---|
| `PerformUntilEnd` | `NoError` | 0.0000 | 1407.2952 |
| `PerformThruNext` | `NoError` | 0.0000 | 1407.2952 |
| `Perform(R, 0, 30)` | `NoError` | 0.0000 | 1407.2952 |

A single plate (one solid before and after the cut) is byte-identical before and after this patch:
`nbparts` is 1, and the selection branch never ran either way.

## Behavior change beyond the bug

A radius so large the bore swallows the whole workpiece (`r = 100` on a 50mm plate): under the old
`BOPAlgo_CUT` path this emptied `myShape`, so `nbparts` was 0 and `PerformUntilEnd`/`PerformThruNext`
returned `BRepFeat_InvalidPlacement`. Under `BOPAlgo_COMMON` the tool meets the whole workpiece,
`nbparts` is 1, and both modes now return the same empty result `Perform(Radius)` and a plain
`BRepAlgoAPI_Cut` against the same cylinder already returned. `nbparts == 0` now means what the
"the tool meets nothing" guard reads as.

## Note: a related, separate defect in the same heuristic, not touched by this PR

`PerformThruNext`'s closest-interval fallback (`BRepFeat_MakeCylindricalHole.cxx:217-242`, used
when no candidate part's barycentre lies in `[First, Last]`) has a misplaced brace: the
`// parbar > Last` branch is nested inside `if (parbar < First)` as its `else`, so the "beyond
`Last`" case is unreachable as written. `PerformBlind`'s equivalent fallback
(`BRepFeat_MakeCylindricalHole.cxx:602-616`) has no such structure and compares
`std::abs(First - parbar)` uniformly. No geometry in the reproducer above reaches this fallback (it
only runs when the barycentre test above finds nothing in range), so this is reported for
visibility rather than fixed here; happy to open a separate PR once there's a case to measure it
against.

## Validation

`Scripts/repro/532-cylindrical-hole-part-selection/` in the downstream OCCTSwift wrapper (issue
#532 there) measures every mode across six geometries, before and after: the two tables above, plus
a three-plate compound (`PerformUntilEnd` 0.0000 -> 4712.3890) and two geometries whose *inputs* to
the selection loop change (one solid to two real tool parts) while the *answer* does not, which is
the non-regression evidence that matters (a channel and a hollow box, both one solid with multiple
axis crossings). Full downstream test suite clean against a production rebuild of the patched
kernel.
