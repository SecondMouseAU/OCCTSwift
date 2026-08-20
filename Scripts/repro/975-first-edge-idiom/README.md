# #975: the open-coded "first edge of a shape" idiom against `occtEdgeAt(shape, 0)`

Four bridge entry points open-coded the same block to turn an `OCCTShapeRef` that may or may not
be a bare edge into a `TopoDS_Edge`, seven copies of it in total across two files:

| Site | Copies |
|---|---|
| `OCCTBridge_Modeling.mm` `OCCTWireMakeWireFromEdges` | 1 |
| `OCCTBridge_Modeling.mm` `OCCTChFi2dFilletAlgo` | 2 |
| `OCCTBridge_Modeling.mm` `OCCTChFi2dAnaFillet` | 2 |
| `OCCTBridge_Topology.mm` `OCCTBRepExtremaExtCCEdges` | 2 |

`OCCTBridge_Internal.h` already answers the same question as `occtEdgeAt(shape, 0)`, and
`OCCTBRepExtremaExtCC` forty lines above one of those copies, in the same file, was converted to it
by #613. The two spellings are not obviously the same answer: the idiom takes the first hit of a
raw `TopExp_Explorer` walk (plus a special case for a shape that is itself an edge), while
`occtEdgeAt` reads index 0 of the deduplicated `TopExp::MapShapes` map, and #541 measured those two
enumerations naming *different* faces from index 10 onwards on a shape with a shared sub-shape.

`occt_975_first_edge.mm` transcribes both spellings unchanged and runs them over eleven fixtures:
a bare edge, a reversed bare edge, a wire and a reversed wire, a face, a solid whose explorer walk
yields 24 occurrences over 12 distinct edges, a compound holding the same edge twice, both
orderings of a compound of an edge and a wire, an empty compound, and a vertex.

Result (`probe-output.txt`, pinned kernel): **0 divergences**. Same edge by `IsSame`, and the same
orientation, on every fixture, including both the null answers.

Deduplication only ever removes a *later* duplicate, so index 0 is always the first occurrence, and
`TopExp::MapShapes` on a shape that is itself an edge contains that edge, which is what makes the
idiom's bare-edge special case redundant rather than merely usually redundant.

## Build

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/975-first-edge-idiom/occt_975_first_edge.mm -o /tmp/occt_975
/tmp/occt_975
```

Exit code is the divergence count clamped to 0/1.
