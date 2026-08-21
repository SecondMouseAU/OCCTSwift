# OCCTSwift#536 probe, are `BRepAlgoAPI_Defeaturing` and `BOPAlgo_RemoveFeatures` one operation?

Ground truth for collapsing the bridge's two shape-addressed "remove these faces" wrappers onto one,
against the pinned OCCT 8.0.0p1 kernel.

`Shape.defeature(faces:)` reached `OCCTShapeDefeature` → `BRepAlgoAPI_Defeaturing`, and
`Shape.removeFeatures(faces:)` reached `OCCTBOPAlgoRemoveFeatures` → `BOPAlgo_RemoveFeatures`. Same
argument types, same return type, different names, no cross-reference between them. Reading
`BRepAlgoAPI_Defeaturing.cxx` says they should be the same operation, its `Build()` is a forwarder
to a `BOPAlgo_RemoveFeatures` member, but the question a deprecation has to answer is not "do they
agree on a box", it is "is there **any** input on which they can differ".

They cannot. Every case agrees, BREP byte for byte, including the ones where the algorithm refuses.

No fixture files needed: every case builds its geometry from a primitive.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/536-defeature-removefeatures-unify/occt_536_defeature_vs_removefeatures.mm \
  -o /tmp/occt_536
/tmp/occt_536
```

Exit status is 1 if any case diverges.

## What it does

Each path is driven exactly the way its bridge wrapper drove it, down to the completion test, the
`BRepAlgoAPI` wrapper checked `IsDone()`, the `BOPAlgo` one checked `HasErrors()`, and the results
are compared as full BREP serialisations rather than as volumes, so a difference in
parameterisation that leaves the volume alone still counts.

Three places a difference could hide are measured, not assumed:

1. **The option defaults each path inherits.** `Build()` forwards a history flag and a parallel flag;
   if the two classes defaulted them differently, every unconfigured call would already be two
   different operations.
2. **Ordinary removals**, across features of different kinds: a fillet (every face of the fixture in
   turn, so the refusals are covered too), a through hole, a boss, and two holes removed at once.
3. **The requests that are not ordinary**, where two independently maintained wrappers are likeliest
   to have drifted: no faces at all, a face belonging to a different shape, a mixed request, an
   input that is not a solid, the same face requested twice.

## Result

```
option defaults (nothing set on either):
  history filling : defeaturing=1 removeFeatures=1  same
  parallel mode   : defeaturing=0 removeFeatures=0  same

ordinary removals:
  20mm box, remove fillet face               defeature[done=1 shape=1 vol=8000.000000000 faces= 6]  removeFeatures[ok=1 shape=1 vol=8000.000000000 faces= 6]  IDENTICAL BREP
  20mm box, remove face 1 of 7               defeature[done=1 shape=1 vol=7982.831853072 faces= 7]  removeFeatures[ok=1 shape=1 vol=7982.831853072 faces= 7]  IDENTICAL BREP
  20mm box, remove face 2 of 7               defeature[done=1 shape=1 vol=7982.831853072 faces= 7]  removeFeatures[ok=1 shape=1 vol=7982.831853072 faces= 7]  IDENTICAL BREP
  20mm box, remove face 3 of 7               defeature[done=1 shape=1 vol=8000.000000000 faces= 6]  removeFeatures[ok=1 shape=1 vol=8000.000000000 faces= 6]  IDENTICAL BREP
  20mm box, remove face 4 of 7               defeature[done=1 shape=1 vol=7982.831853072 faces= 7]  removeFeatures[ok=1 shape=1 vol=7982.831853072 faces= 7]  IDENTICAL BREP
  20mm box, remove face 5 of 7               defeature[done=1 shape=1 vol=7982.831853072 faces= 7]  removeFeatures[ok=1 shape=1 vol=7982.831853072 faces= 7]  IDENTICAL BREP
  20mm box, remove face 6 of 7               defeature[done=1 shape=1 vol=7982.831853072 faces= 7]  removeFeatures[ok=1 shape=1 vol=7982.831853072 faces= 7]  IDENTICAL BREP
  20mm box, remove face 7 of 7               defeature[done=1 shape=1 vol=7982.831853072 faces= 7]  removeFeatures[ok=1 shape=1 vol=7982.831853072 faces= 7]  IDENTICAL BREP
  box with through hole, remove hole         defeature[done=1 shape=1 vol=8000.000000000 faces= 6]  removeFeatures[ok=1 shape=1 vol=8000.000000000 faces= 6]  IDENTICAL BREP
  box with boss, remove boss faces           defeature[done=1 shape=1 vol=8301.592894745 faces= 8]  removeFeatures[ok=1 shape=1 vol=8301.592894745 faces= 8]  IDENTICAL BREP
  two holes, both removed at once            defeature[done=1 shape=1 vol=27000.000000000 faces= 6]  removeFeatures[ok=1 shape=1 vol=27000.000000000 faces= 6]  IDENTICAL BREP

non-ordinary requests:
  no faces requested                         defeature[done=0 ...]  removeFeatures[ok=0 ...]  IDENTICAL BREP
  face from a different shape                defeature[done=0 ...]  removeFeatures[ok=0 ...]  IDENTICAL BREP
  one real face plus one foreign             defeature[done=1 shape=1 vol=8000.000000000 faces= 6]  removeFeatures[ok=1 shape=1 vol=8000.000000000 faces= 6]  IDENTICAL BREP
  input is a face, not a solid               defeature[done=0 ...]  removeFeatures[ok=0 ...]  IDENTICAL BREP
  the same face requested twice              defeature[done=1 shape=1 vol=8000.000000000 faces= 6]  removeFeatures[ok=1 shape=1 vol=8000.000000000 faces= 6]  IDENTICAL BREP

VERDICT: every case agrees, BREP byte for byte -- one operation under two names
```

Note that the two completion tests never disagree either: `Build()` calls `Done()` only after
checking `HasErrors()` on the merged report, so `IsDone()` and `!HasErrors()` answer the same
question one layer apart, exactly as the algorithms do.

## Why

`BRepAlgoAPI_Defeaturing::Build`
(`src/ModelingAlgorithms/TKBO/BRepAlgoAPI/BRepAlgoAPI_Defeaturing.cxx`, 30 lines) is the whole of the
outer class's contribution:

```cpp
myFeatureRemovalTool.SetShape(myInputShape);
myFeatureRemovalTool.AddFacesToRemove(myFacesToRemove);
myFeatureRemovalTool.SetToFillHistory(myFillHistory);
myFeatureRemovalTool.SetRunParallel(myRunParallel);
myFeatureRemovalTool.Perform(theRange);
GetReport()->Merge(myFeatureRemovalTool.GetReport());
if (HasErrors()) return;
Done();
myShape = myFeatureRemovalTool.Shape();
```

`myFeatureRemovalTool` is a `BOPAlgo_RemoveFeatures` member; `Modified`, `Generated`, `IsDeleted`,
`HasModified`, `HasGenerated`, `HasDeleted` and `History` are all one-line delegations to it. Both
forwarded flags default the same way on both classes (`myFillHistory(true)` in each constructor,
`myRunParallel(false)` inherited from `BOPAlgo_Options`), which is what the first section of the
probe checks, so an unconfigured `BRepAlgoAPI_Defeaturing` and an unconfigured
`BOPAlgo_RemoveFeatures` are the same object with the same settings.

There is no defect here and nothing to file: the outer class is doing what an API-level wrapper is
for. The duplication was ours, the bridge wrapped both layers of one algorithm and gave each its
own Swift name.

## What else this measured

Two things about the surviving entry point's contract, neither of them a difference between the two
paths (both behave identically on all of it), and neither previously written down.

**A face that is not part of the input is dropped, not refused.** The header says so
("those that do not belong will be ignored") and the probe confirms it: a request mixing one real
face with one foreign face succeeds, removes the real one, and emits **no warning of any kind**. A
request of nothing but foreign faces fails, because nothing is left to remove. So the shape-addressed
form is more forgiving than the index-addressed `withoutFeatures(faces:)`, which since #497 fails the
whole call on one bad index. Membership is by identity: a face measured off a separately built but
identical fixture is foreign (`done=0`).

**What a "face to remove" is allowed to be.** `AddFaceToRemove` takes a `TopoDS_Shape` and its own
documentation calls it "the shape to extract the faces for removal", so the argument need not be a
face:

```
  the fillet face, as found                done=1 volume=8000.000000000 faces=6
  the same face, orientation reversed      done=1 volume=8000.000000000 faces=6
  a compound containing the fillet face    done=1 volume=8000.000000000 faces=6
  the entire input solid                   done=1 volume=7982.831853072 faces=7   (a no-op success)
  an edge (contains no face)               done=0 volume=0.000000000 faces=0
```

This is why #536 did not go on to give the shape-addressed form the index-addressed form's stricter
membership rule. Enforcing "every requested face must belong to this shape" means first deciding
what to do with the compounds, shells and whole solids the kernel accepts as face carriers, which is
its own design question with its own measurement matrix, not a line of validation. Filed as #578 and
settled there, see `Scripts/repro/578-defeature-face-membership/` for that matrix and the rule
chosen. A face this shape does not have now fails the whole request, whichever way the request
addresses its faces; carriers stay legal, and every face a carrier names must belong.
