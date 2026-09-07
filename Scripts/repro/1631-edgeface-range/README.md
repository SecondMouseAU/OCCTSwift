# #1631: `IntTools_EdgeFace` finds nothing without `SetRange`

`Shape.edgeFaceIntersection(with:)` returned an empty array for every input, and reported success
while doing it. Found by #1399's booleans-family read, confirmed here against the pinned kernel.

`IntTools_EdgeFace::myRange` is an `IntTools_Range` whose default is `(0, 0)`, and `Perform()`
hands it straight to `IntTools_BeanFaceIntersector::SetBeanParameters`. Without an explicit
`SetRange` the search interval on the edge is empty, so the intersector has nothing to walk.
`IsDone()` answers `true` either way: absence and "never looked" spelled the same, #726's own
class of defect.

`IntTools_EdgeEdge` repairs the same default inside its own `Prepare()`. `IntTools_EdgeFace` does
not, so this entry point was the only one affected.

```
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1631-edgeface-range/probe.mm -o /tmp/occt_ef && /tmp/occt_ef
```

A 10-unit box and an edge running up its middle, each face tried with and without the call:

```
face 0  no range     done=1  commonParts=0
face 0  with range   done=1  commonParts=0
...
face 4  no range     done=1  commonParts=0
face 4  with range   done=1  commonParts=1
face 5  no range     done=1  commonParts=0
face 5  with range   done=1  commonParts=1
```

Faces 4 and 5 are the two the edge crosses. Without the range every face answers zero; with it,
exactly the two crossed faces answer one.

## Why no test caught it

`IntToolsEdgeFaceTests` existed and passed. It asserted `parts != nil`, which an always-empty
array satisfies. The replacement asserts which faces are hit and where, so the same defect fails it
with `hits.count → 0` instead of passing.
