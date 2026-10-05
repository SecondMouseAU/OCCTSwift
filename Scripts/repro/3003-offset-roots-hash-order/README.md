# #3003: an arc-join offset comes back in an order set by allocation addresses

`BRepOffsetAPI_MakeOffsetShape` and `BRepOffsetAPI_MakeThickSolid` with `GeomAbs_Arc` return the
same solid with its faces in a different order from one process to the next, and from one build to
the next inside a process. `BRepGProp::VolumeProperties` sums over the faces in the order the shape
holds them, so the last digits of the volume move with it. That is the 4e-16 to 9e-16 drift on three
lines of two #766 probes that #2965 allowed for with a `tolerance` key.

**It is none of the three causes the issue and the brief named.** Nothing runs in parallel, nothing
is shared between threads, nothing is read uninitialised. It is a fourth: a traversal in the order
of a hash of pointer values.

## What was measured

All of it against the pinned `v4.0.0-kernel.4` asset, macOS slice, `libOCCT-macos.a` sha256
`aa8fca8dececc454f3c012b6637487dc634947a0067a87dbee72917af130ad92`, 157,581,864 bytes (the asset
whose zip hashes to `4ebd78b6...`, `Package.swift`'s checksum), by `run.sh`. The first measurement was
made on `v4.0.0-kernel.3` and every finding below held there too: the battery and its comparison
came out identical, the per-row counts moved within their run-to-run spread.

**The six lines of the two #766 probes, 60 fresh processes** (`transcript-lines-asset.txt`).
"Dumps" is the number of distinct hashes of the bit-exact `BinTools` dump of the result, which
moves when the sub-shapes come back in another order even if the volume does not.

| line | distinct volumes | distinct dumps | relative spread |
|---|---|---|---|
| `offsetArc` (box 10, +1, `GeomAbs_Arc`) | 7 | 60 | 8.0e-16 |
| `offsetInward` (-1) | 1 | 55 | 0 |
| `offsetIntersection` (+1, `GeomAbs_Intersection`) | 1 | 1 | 0 |
| `offsetCylinder` (+1) | 1 | 24 | 0 |
| `shellOwnFaces` (20-cube, thickness 2, top open) | 3 | 60 | 4.0e-16 |
| `shellNoOpenFace` (nothing open) | 6 | 60 | 6.7e-16 |

Two things in that table correct the issue. The drift is not confined to "these shapes": four of
the six results come back reordered on nearly every run, and the two whose volume stays put
(`offsetInward`, `offsetCylinder`) simply have faces symmetric enough to sum exactly in any order.
And `offsetIntersection` is reproducible to the bit because it does not pass through
`BuildOffsetByArc`. A re-run of the census finds a slightly different count on each row (6, 7 and 8
volumes were seen for `offsetArc`); the spread, not the count, is the measurement.

**The faces are the same faces.** For `offsetArc`, the sorted multiset of (surface type,
orientation, per-face volume contribution as `%a`) is identical across processes while the ordered
list is different in every one: six planes, twelve cylinder quarters and eight sphere octants, in a
new order each time.

**It is not parallel** (`transcript-threads-asset.txt`). The process has **one thread** after the
operations, and `BOPAlgo_Options::GetParallelMode()`, the only global switch, is `false`. Every
`BOPAlgo_*` object `BRepOffset_MakeOffset_1.cxx` builds copies that flag when it is constructed
(`BOPAlgo_Options.cxx:52`, `:64`), and
`grep -rn 'RunParallel\|OSD_Parallel\|BOPAlgo_Options\|ParallelMode' src/ModelingAlgorithms/TKOffset`
finds one hit, `BRepOffsetAPI_MakeEvolved.cxx:50`, which this does not reach. The bridge never sets
a parallel mode for it either: `OCCTShapeFuseMulti` runs at the serial default (its comment records
that `SetRunParallel(true)` was removed, not that `false` is set), and the only two explicit
`SetRunParallel(false)` calls in `Sources/OCCTBridge` are on `BOPAlgo_ArgumentAnalyzer` in the
self-intersection checks. **So there is nothing to turn off, and the bridge should not touch it**:
the parallelism the brief asks about does not exist for this operation, so no switch can change a
result, and the one global switch is already at the value that would be written.

**It is the allocator** (`transcript-perturb.txt`). 32 builds of `offsetArc` in one process, repeated in 20 processes; one process is a draw and the range is the measurement:

| heap held before each build | distinct face orders in 32 builds, per process |
|---|---|
| a different amount each time | **11 to 32** (median 32) |
| untouched | 11 to 32 (median 32) |
| a different amount each time, patched | **1** in all 20 |
| untouched, patched | **1** in all 20 |

and `transcript-order-asset.txt`: an `NCollection_DataMap<TopoDS_Shape, int, TopTools_ShapeMapHasher>`
holding the same 26 faces iterates them in a different order in **20 of 20 processes**.

## The cause

`TopoDS_Shape.hxx:332-341`: `std::hash<TopoDS_Shape>` is `opencascade::hash(theShape.TShape().get())`,
the **address** of the `TShape`, mixed with the location's hash when there is one.

`BRepOffset_MakeOffset::BuildOffsetByArc` (`BRepOffset_MakeOffset.cxx`, V8_0_1):

- line 1911 declares `NCollection_DataMap<TopoDS_Shape, BRepOffset_Offset, TopTools_ShapeMapHasher> MapSF`
  and fills it with an offset per face (`MakeOffsetFaces`), per convex edge (a tube) and per vertex
  (a sphere);
- line 2092 walks it with an `Iterator`, and each entry becomes a root of `myInitOffsetFace` and of
  `myImageOffset` (`myImageOffset.SetRoot(OF)`);
- `MakeShells` (line 3691) hands `myImageOffset.Roots()` to `BRepTools_Quilt::Add` in that order, and
  `BRepTools_Quilt::Shells()` keeps the faces in the order they were added (`myBounds` is an
  `NCollection_IndexedDataMap`, so it iterates in insertion order).

So the order of the faces of the result is the iteration order of a map hashed on addresses. The
file has four other iterations of a hash container. Three (`ToContext`'s `Created`,
`SetFacesWithOffset`'s `myFacePlanfaceMap`, `CheckInputData`'s `myFaceOffset`) act on each entry
independently or only look for one; `UpdateFaceOffset`'s `CopiedMap` can decide which of two
conflicting per-face offsets a tangent group takes, and none of the measured requests sets a
per-face offset. They were read, not tested, and the patched census is what says nothing else moved
the order for these requests.

The causal test is the override-link below, not the reading: the unmodified file recompiled with the
kernel's own flags reproduces the spread (`transcript-lines-control.txt`: 7, 1, 1, 1, 3, 5 volumes),
and the same file with only that loop changed removes it.

## The fix: `Scripts/patches/0053-BRepOffset_MakeOffset-arc-join-roots-in-binding-order-3003.patch`

`BuildOffsetByArc` records the order the entries are bound in (the faces in the order
`MakeOffsetFaces` binds them, `BRepLib::SortFaces` over `myFaceComp` then the faces
`BRepOffset_Analyse` added; then the tubes; then the spheres) in an `NCollection_IndexedMap`, and
walks that, looking each one up in `MapSF`, which `ToContext` may have unbound. About 35 changed
lines in one function, no signature change.

`NCollection_OrderedDataMap`, which 8.0.0 added for exactly this and whose upgrade note recommends it
"in new code", would be the idiomatic spelling and is not used here because `MapSF`'s type is the
parameter type of `BRepOffset_Inter3d::ConnexIntByInt` and `ContextIntByInt`, so swapping it
changes the signatures in another header and translation unit as well as `BRepOffset_MakeOffset`'s
own (three methods and three file statics); `BiTgte_Blend` holds a member of the same type for its
own use. The patch keeps the type.

| | asset | control (unmodified, recompiled) | patched |
|---|---|---|---|
| six lines, 60 processes | 7, 1, 1, 1, 3, 6 volumes; 60, 55, 1, 24, 60, 60 dumps | 7, 1, 1, 1, 3, 5; 60, 58, 1, 26, 60, 60 | **1, 1, 1, 1, 1, 1; 1, 1, 1, 1, 1, 1** |
| 72-request battery, 20 processes | 29 requests moved: 26 only in order, 3 in outcome | | **0 moved** |
| 32 builds in one process, heap perturbed, 20 processes | 11 to 32 face orders | | **1** in every process |

`transcript-lines-patched.txt`, `transcript-battery-asset.txt`, `transcript-battery-patched.txt`,
`transcript-perturb.txt`.

The GTest the patch adds to `BRepOffset_MakeOffset_Test.cxx`
(`ArcJoin_FaceOrderDoesNotDependOnAddresses`: 32 builds of a freshly made box, since one box offset repeatedly does not show the defect, with a different amount of heap held before
each, compares every face's centre and the volume's bits against build 0) was run against the
override-linked unmodified file and against the patched one:

| | result |
|---|---|
| unmodified file | **fails**, 15 of 15 runs; 812 failed expectations in one run, the first from build 1 |
| patched file | passes, 15 of 15 runs (462 ms) |
| the other 19 tests in the file | pass on both |

### Prove-the-test-fails, for `census.py`'s `--self-test`

Nine mutants, each breaking one rule of the script (volumes counted as one, dumps counted as one,
spread zeroed, dump and outcome compared as one, an outcome difference never reported, a ragged
input accepted, the dump suffix kept in `compare`, a case present in one build only never reported,
and `compare` reading `b[k]` on a `defaultdict` before computing the missing list). All nine fail
the self-test and the unmodified script passes. The last is not invented: the self-test caught it in
the first version of `compare`, where the read inserted the very key the list exists to report.

## What the fix does not do, and a second defect it exposes

**For an input whose success depends on the order the roots arrive in, the patched kernel gives the
same answer every time, and that answer may be the failing one.** The one found is the fuse of two
boxes (`BRepAlgoAPI_Fuse`, which keeps coplanar faces split, 14 faces):

- unmodified, arc-join `offset(+1)` returns a solid in **11 of 20** processes (7 and 8 of 20 in two
  earlier censuses) and, in the rest, reports `IsDone() == true` with a **null shape**
  (`transcript-battery-asset.txt`);
- patched, in binding order, the order chosen here, it fails in 20 of 20
  (`transcript-battery-patched.txt`).

The same input changing outcome with nothing but the heap different shows it is a property of the
intersection stage that follows, and it is its own defect. A scratch experiment (an override that
permutes the root order, not committed) found about 42% of random orders succeed and the reverse of
binding order succeeds, so a different fixed order would favour this input; no order was tuned to it. It is not addressed here and it should be reported as one. Of the 72 requests in the
battery, **69 return an identical outcome unpatched and patched** (`transcript-battery-compare.txt`);
the 3 that differ are this input at +1, +0.3 and as a thick solid with nothing open.

**The same input exposes a bridge defect.** `OCCTShapeOffsetByJoin` is
`if (!offsetter.IsDone()) return nullptr; return new OCCTShape(offsetter.Shape());`, so a null result
that OCCT reports as done reaches Swift as a non-nil `Shape` that `isNull`. Measured through the
public API on this input (`Shape.offset(by: 1.0, joinType: .arc)`, one `.xctest` process each):
40 of 40 calls returned a solid in one process and 40 of 40 returned a wrapper around a null shape
in the next. That makes a null shape reachable without `Shape.nullified`, which #1034 is about.

## Upstream, checked 2026-10-03

- `gh pr list --repo Open-Cascade-SAS/OCCT --search "author:dpasukhi offset"` (30 results) and
  searches over open and closed issues and PRs for deterministic, non-deterministic, reproducible,
  iteration order, hash order, `MakeThickSolid`, `BuildOffsetByArc` and `MapSF`: **no report and no
  PR** about the order of an offset's faces. The nearest hits are our own thread-safety research
  (OCCT#1179) and an unrelated `BRepAlgoAPI_Common` report (OCCT#1496).
- `IR` is 57 commits past `V8_0_1` (last 2026-09-05) and `master` 42 (last 2026-08-24). The offset
  builder on `IR` still has the same `DataMap` `MapSF` (lines 1313, 1880) and the same walk (line
  2061). dpasukhi's mutable-state series did touch this path and did not change that:
  OCCT#1509 replaced `BRepAlgo_Image::Image`'s function-static `NCollection_List` (which
  `BRepOffset_Inter3d` and `MakeOffset` reach) with `FirstImage`, OCCT#1519 deleted 119 lines of
  debug statics from `BRepOffset_MakeOffset.cxx`, and neither touched the iteration.
- 69 PRs are open (2026-10-03); none touches `BRepOffset_MakeOffset.cxx`, `BRepAlgo_Image` or
  `BRepTools_Quilt`.
- `NCollection_OrderedMap` and `NCollection_OrderedDataMap` are new in 8.0.0 (`dox/upgrade/upgrade.md`:
  "insertion-order-preserving maps with O(1) lookup, append, and removal"), and the only library
  user is `ShapeUpgrade_ShellSewing` (`OrderedMap`).

**Held, not filed**, per the standing decision. The draft is the message of the patch itself and the
body of the PR that carries it.

## What this means for the two #766 probes

`766-modeling-evidence-fix/reproduce.json` and `766-modeling-issue568-index-skip/reproduce-evidence-fix.json`
keep their `tolerance` declarations: the pinned asset does not carry `0053`, so those three lines
still drift against it and removing the allowance now would make `check-766-probe-reproduction.py`
red about one run in three again. Their `reason` text now names this cause. **They come out, and the
three transcripts are recaptured, at the repin that pins `0053`**, and the patched value is
`1698.436569847848` for `offsetArc`, not the transcript's `...475`: the patched build picks one
value out of the distribution, deterministically.

## Reproduce

```bash
# the kernel as shipped, then the unmodified file recompiled with the kernel's own flags, then patched
Scripts/repro/3003-offset-roots-hash-order/run.sh --variant asset
Scripts/repro/3003-offset-roots-hash-order/run.sh --variant control --occt-src Libraries/occt-src
Scripts/repro/3003-offset-roots-hash-order/run.sh --variant patched --occt-src Libraries/occt-src
# the 72-request battery, the allocator experiment, the hash order, the thread count
Scripts/repro/3003-offset-roots-hash-order/run.sh --what battery --runs 20
Scripts/repro/3003-offset-roots-hash-order/run.sh --what perturb
Scripts/repro/3003-offset-roots-hash-order/run.sh --what order --runs 20
Scripts/repro/3003-offset-roots-hash-order/run.sh --what threads
python3 Scripts/repro/3003-offset-roots-hash-order/census.py --self-test
```

`run.sh` finds the pinned asset under `.build/artifacts` after a `swift build`, prints which kernel it
read, builds in a temporary directory, and never writes to the repository. `--occt-src` is only read:
the file is copied and the patch applied to the copy.

## Limits

macOS arm64 and the pinned asset only; the hash is the address, so another allocator or another
platform will order differently, which is the defect. The battery is 72 requests on nine shapes,
not the offset population. The address dependence is shown by the heap-perturbation experiment and by
the DataMap order on fixed shapes, and made causal by the override-link; the addresses themselves
were never pinned and varied by hand. A test of the patched kernel against the Swift suites is in
the PR description, not here.
