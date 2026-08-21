# OCCTSwift#497 probe, does `BRepAlgoAPI_Defeaturing` honour a fuzzy tolerance?

Ground truth for the one behavioural difference between the bridge's two shape-addressed
defeaturing wrappers, against the pinned OCCT 8.0.0p1 kernel.

#497 found three wrappers of `BRepAlgoAPI_Defeaturing` in `OCCTBridge.h`, and reported that the
duplication was actively harmful because it "hides a working feature (fuzzy tolerance) behind an
overload-resolution trap": `OCCTDefeatureWithTolerance` called `SetFuzzyValue`, `OCCTShapeDefeature`
did not, and Swift's overload resolution sent every `shape.defeature(faces:)` call site to the
second one. The trap half is real and was confirmed against the package itself. This probe asks the
other half: what does the caller lose by landing on the wrapper without the `SetFuzzyValue` call?

Nothing. The fuzzy value is stored and never read.

No fixture files needed: every case builds its geometry from a primitive.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/497-defeaturing-fuzzy-inert/occt_497_defeaturing_fuzzy.mm -o /tmp/occt_497
/tmp/occt_497
```

## What it does

A 10mm box with one 2mm fillet; the fillet face is removed by `BRepAlgoAPI_Defeaturing` at fuzzy
values from `1e-7` to `100`, and the full BREP serialisation of each result is compared against the
first. A serialisation comparison rather than a volume comparison, so that a geometric difference
too small to move the volume still counts as a difference.

A null result means nothing on its own, the tolerances might simply be too small to bite. So the
same magnitudes are also run through `BRepAlgoAPI_Cut`, a BOP that does honour the fuzzy value, as
a control.

## Result

```
input: volume=991.415926536 faces=7
  fuzzy=0        stored=1e-07      volume=1000.000000000 faces=6 brep=IDENTICAL
  fuzzy=1e-07    stored=1e-07      volume=1000.000000000 faces=6 brep=IDENTICAL
  fuzzy=0.01     stored=0.01       volume=1000.000000000 faces=6 brep=IDENTICAL
  fuzzy=1        stored=1          volume=1000.000000000 faces=6 brep=IDENTICAL
  fuzzy=10       stored=10         volume=1000.000000000 faces=6 brep=IDENTICAL
  fuzzy=100      stored=100        volume=1000.000000000 faces=6 brep=IDENTICAL

Defeaturing: fuzzy value made NO difference at any magnitude

control (BRepAlgoAPI_Cut, an honouring BOP):
  fuzzy=0        stored=1e-07      volume=874.336293856 faces=7 brep=IDENTICAL
  fuzzy=1e-07    stored=1e-07      volume=874.336293856 faces=7 brep=IDENTICAL
  fuzzy=0.01     stored=0.01       volume=874.336293856 faces=7 brep=IDENTICAL
  fuzzy=1        stored=1          volume=857.581133037 faces=7 brep=DIFFERENT
  fuzzy=10       stored=10         volume=0.000000000 faces=0 brep=DIFFERENT
  fuzzy=100      stored=100        volume=-20.943951024 faces=2 brep=DIFFERENT

Cut: fuzzy value changed the result (control valid)
```

`FuzzyValue()` echoes back whatever was set, so the value really is reaching the object, it is the
algorithm that never consults it. The control confirms the magnitudes bite: at `fuzzy=10` the same
box cut by the same cylinder collapses to an empty shape.

## Why

`BRepAlgoAPI_Defeaturing::Build`
(`src/ModelingAlgorithms/TKBO/BRepAlgoAPI/BRepAlgoAPI_Defeaturing.cxx`) forwards exactly four things
to the `BOPAlgo_RemoveFeatures` that does the work:

```cpp
myFeatureRemovalTool.SetShape(myInputShape);
myFeatureRemovalTool.AddFacesToRemove(myFacesToRemove);
myFeatureRemovalTool.SetToFillHistory(myFillHistory);
myFeatureRemovalTool.SetRunParallel(myRunParallel);
```

`myFuzzyValue` is not among them, and `BOPAlgo_RemoveFeatures.cxx` contains no reference to a fuzzy
value at all, the general-fuse, trimming and volume-maker sub-algorithms it drives are each given
`SetRunParallel` and nothing else. `SetFuzzyValue` writes a field on the `BOPAlgo_Options` base
class that this algorithm's `Build()` never reads.

This is not an upstream defect: `BRepAlgoAPI_Defeaturing.hxx` documents it, in the class comment
listing the supported options.

> Please note that the other options of the base class are not supported here and will have no
> effect.

So there is nothing to file upstream, and nothing to patch. The wrapper that offered the tolerance
was `OCCTShapeDefeature` under a different name, and was deleted; the Swift overload that took one
is deprecated and forwards.

## What this changed about the fix

#497's framing was that consolidating the wrappers required care because one of them carried a
feature the other lacked. Measured, the two are interchangeable, so the consolidation is unconditional
,  and the finding inverts: the duplication's real cost was not a hidden feature but an advertised
parameter that never worked, kept alive by the copy that had one.
