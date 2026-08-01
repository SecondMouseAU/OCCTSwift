# OCCTSwift#568 ground truth: what a builder does with a batch it was never told was short

One standalone probe, run against the pinned `OCCT.xcframework` (8.0.0p1 + our carried patches). It
establishes what the four OCCT builders behind the surviving skip-an-out-of-range-index sites report
when the index array they were handed only partly resolved. That is the whole basis for the #568
decision: the issue asked whether the fillet family's answer (#520) carries over, and the answer
turns on whether a caller can tell a partial result from a complete one.

No fixture files: a 20mm box for the 3D cases, a 40x30 rectangular face for the 2D ones.

## Compile and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/568-index-skip-idiom/occt_568_partial_batch.mm \
  -o /tmp/occt_568_partial_batch

for c in chamfer-full chamfer-partial chamfer-none \
         draft-full draft-partial draft-none \
         thick-full thick-partial \
         fillet2d-full fillet2d-partial fillet2d-none \
         chamfer2d-full chamfer2d-partial chamfer2d-none; do
  /tmp/occt_568_partial_batch "$c"; echo "  exit=$?"
done
```

Each case runs in its own process: a builder handed an empty batch is exactly the shape that
SIGSEGV'd in #520, so a crash in one case must not take the rest of the measurement with it. None of
them crashes here, but that was not known before running it.

## What it measures

| bridge site | builder | index |
|---|---|---|
| `OCCTShapeHistoryFromChamferEdges` | `BRepFilletAPI_MakeChamfer` | edge |
| `OCCTShapeDraft` | `BRepOffsetAPI_DraftAngle` | face |
| `OCCTShapeShellWithOpenFaces` | `BRepOffsetAPI_MakeThickSolid` | face |
| `OCCTFace2DFillet` | `BRepFilletAPI_MakeFillet2d` | vertex |
| `OCCTFace2DChamfer` | `BRepFilletAPI_MakeFillet2d` | edge, two per entry |

## Result: the partial batch is an ordinary success

| case | `IsDone` | result | measurement |
|---|---|---|---|
| `chamfer-full` (3 of 3 edges) | 1 | valid | volume 7885.333333, 19 edges |
| `chamfer-partial` (2 of 3) | 1 | **valid** | volume 7922.666667, 17 edges |
| `chamfer-none` (0 of 3) | n/a | threw | `There are no suitable edges for chamfer or fillet` |
| `draft-full` (4 of 4 faces) | 1 | valid | volume 6681.349269 |
| `draft-partial` (2 of 4) | 1 | **valid** | volume 7299.820338 |
| `draft-none` (0 of 4) | **1** | **valid** | volume **8000.000000**, the input, undrafted |
| `thick-full` (2 of 2 open faces) | 1 | valid | volume 2880.000000 |
| `thick-partial` (1 of 2) | 1 | **valid** | volume 3392.000000 |
| `fillet2d-full` (4 of 4 vertices) | 1 | valid | area 1178.539816, 8 edges |
| `fillet2d-partial` (2 of 4) | 1 | **valid** | area 1189.269908, 6 edges |
| `fillet2d-none` (0 of 4) | 0 | n/a | |
| `chamfer2d-full` (2 of 2 pairs) | 1 | valid | area 1184.000000, 6 edges |
| `chamfer2d-partial` (1 of 2) | 1 | **valid** | area 1192.000000, 5 edges |
| `chamfer2d-none` (0 of 2) | 0 | n/a | |

Every partial row is `IsDone`, non-null and `BRepCheck_Analyzer`-valid. Nothing in the result says
the request was cut down; the only difference from the complete row is geometry the caller has no
reason to re-measure. That is the #439/#442/#443 defect class (a request honoured in part,
presented as honoured in full), and the answer #520 gave the fillet family carries over unchanged.

Two findings the issue did not anticipate:

- **`BRepOffsetAPI_DraftAngle` is the severe one.** It is the only builder here that reports success
  for an *empty* batch, and what it returns is the input shape. So `Shape.drafted(faces:)` naming
  only faces the shape does not have (the ordinary result of passing `Face` values taken from a
  different shape) succeeded and drafted nothing. `OCCTShapeDraft` was not on the issue's list of
  four sites at all; it spells the skip as an `if (idx >= 0 && idx < map.Extent()) { … }` wrap
  rather than a `continue`, so a census grepping for the `continue` spelling missed it.
- **The other builders' empty-batch behaviour is why only the mixed batch escaped.** `MakeChamfer`
  throws, `MakeFillet2d` fails `IsDone`, and `OCCTShapeShellWithOpenFaces` has its own empty-list
  check. A wholly unresolvable request already returned `nil` from those four; it was the request
  mixing real indices with unresolvable ones that came back as a plausible wrong answer.

## Also established: `OCCTShapeShellWithOpenFaces`'s empty check is not enough on its own

`thick-partial` is the case that check cannot see. One real open face plus one foreign one leaves a
non-empty list, so the shell is built with half the openings asked for and reported as done
(3392.000000 against 2880.000000). Since the resolver now refuses a count below 1 and appends for
every index it resolves, the empty list became unreachable and the check is gone with it.

## Relationship to the rest of the sweep

- #520 settled the same question for the five `BRepFilletAPI_MakeFillet` edge-list entry points
  (`Scripts/repro/520-fillet-edge-index-contracts/`).
- #541 settled it for `OCCTShapeOffsetPerFace`, which #568 listed as still open but which had
  already been fixed (`Scripts/repro/541-face-index-contract/`).
- #497 settled it for the defeaturing family.

All of them now resolve their indices through `occtUseSubShapesByIndex` /
`occtMappedSubShapeAt` (`Sources/OCCTBridge/src/OCCTBridge_Internal.h`), over the enumeration #502
made canonical, so the contract is stated once rather than agreed to by coincidence.
