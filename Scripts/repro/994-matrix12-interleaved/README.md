# #994: one 12-double INTERLEAVED matrix conversion, and the layout it is not

Two files carried their own conversion between a 12-double matrix and a `gp_Trsf`, 4,800 lines
apart:

| Site | Helper | Call sites |
|---|---|---|
| `OCCTBridge_Topology.mm:4134` | `trsfFromMatrix12` | 2 (`OCCTShapeLocated`, `OCCTShapeSetLocation`) |
| `OCCTBridge_Topology.mm:4141` | `matrix12FromTrsf`, the inverse | 1 (`OCCTShapeGetLocation`) |
| `OCCTBridge_BRepGraph.mm:4631` | `locationFromMatrix` | 4 (the two `SetRefLocalLocation` setters, `LinkProductToTopology`, `LinkProducts`) |

Both readers call `gp_Trsf::SetValues(m[0]..m[11])` in order. The BRepGraph one wraps the result in
a `TopLoc_Location`, which is the composite the two Topology call sites also build a line later. So
the shared unit is the pair plus that composite, and reach is two files, which is why the helpers
land in `OCCTBridge_Internal.h` as `inline` rather than staying static in either.

`occt_994_matrix12.mm` transcribes all three unchanged and runs them over five matrices: identity,
a pure translation, a rotation about Z with a translation (so no two of the twelve slots share a
value and a permuted read cannot coincidentally agree), a rotation the kernel itself built about
`(1,1,1)`, and a uniform scale.

Result (`probe-output.txt`, pinned kernel): **0 divergences**. The two readers agree on all twelve
`Value(i,j)` entries bit for bit, and `matrix12FromTrsf(trsfFromMatrix12(m))` returns `m` exactly,
`max|back - m| = 0` on every fixture.

## The layout is in the helper's name for a reason

This bridge carries two 12-double conventions, and #835 separated them on the Swift side into
`TransformMatrix3D` (INTERLEAVED) and `Matrix12Grouped` (GROUPED) after a run of bugs where a bare
`[Double]` could be either:

```
INTERLEAVED   m[0..3] = r00 r01 r02 tx | m[4..7] = r10 r11 r12 ty | m[8..11] = r20 r21 r22 tz
GROUPED       m[0..8] = the nine rotation values                  | m[9..11] = tx ty tz
```

Three bridge sites read GROUPED (`OCCTShapeTransformed`, `OCCTCurve3DParametricTransformation`,
`OCCTDocumentAddComponentMatrix`) by permuting the arguments into the same `SetValues`. They are
deliberately not converged onto these helpers.

The probe measures what happens when the two are confused, because the answer is not "it is
rejected". Both arrays below mean "translate by (5, 6, 7)":

```
  INTERLEAVED array through the INTERLEAVED reader: translation (5, 6, 7)
  GROUPED array through the GROUPED reader:         translation (5, 6, 7)
  GROUPED array through the INTERLEAVED reader:     translation (0, 0, 7)  accepted
```

`gp_Trsf::SetValues` has its own orthonormality precondition, and this kernel is a Release build
where OCCT defines `No_Exception` and every `*_Raise_if` macro expands to nothing, so the
ill-formed rotation is taken as given. A wrong transform comes back looking like a right one.

## The BRepGraph half is not observable from Swift

Worth knowing before writing a Swift test for it: the four `locationFromMatrix` call sites write a
location into the graph that no read-side bridge function exposes. Measured directly, on a box
graph with a product placed by `(5, 6, 7)`:

```
  BRepGraph.shape(nodeKind: .product,    nodeIndex: <child>)  nil
  BRepGraph.shape(nodeKind: .occurrence, nodeIndex: <occ>)    nil
  BRepGraph.shape(nodeKind: .product,    nodeIndex: <parent>) the box, UNPLACED (bbox -5..5)
  BRepGraph.shape(nodeKind: .solid,      nodeIndex: 0)        the box, UNPLACED (bbox -5..5)
```

against `Shape.located(matrix:)` on the same twelve doubles, which moves the box to `0..10`,
`1..11`, `2..12` and reports the identical twelve doubles back through `locationMatrix`. So this
probe, not a Swift test, is the evidence that the BRepGraph conversion matches the Topology one.
`Tests/OCCTTopologyTests/Issue994Matrix12Tests.swift` covers the reachable half.

## Build

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/994-matrix12-interleaved/occt_994_matrix12.mm -o /tmp/occt_994
/tmp/occt_994
```

Exit code is the divergence count clamped to 0/1.
