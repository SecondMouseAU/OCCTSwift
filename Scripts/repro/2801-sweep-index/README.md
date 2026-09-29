# #2801 sweep: two compiled-out index guards, both reached from a public Swift API

`probe.mm` + `run.sh`; `transcript.txt` is the run against the **pinned** `v4.0.0-kernel.2` asset
(`OCCT.xcframework.zip` checksum `18b181cc27778520fa2912ac2abb38038800b70e48d2fe1cf7fedcc61414d1c3`).
A developer checkout's `Libraries/OCCT.xcframework` is often a locally built kernel, so `run.sh`
takes `OCCT_XCFRAMEWORK`; point it at the downloaded asset.

## 1. `BRepBuilderAPI_Sewing::DeletedFace` faults on every index, including 1

`BRepBuilderAPI_Sewing.cxx:2441`:

```cpp
const TopoDS_Face& BRepBuilderAPI_Sewing::DeletedFace(const int index) const
{
  Standard_OutOfRange_Raise_if(index < 0 || index > NbDeletedFaces(), "...");
  return TopoDS::Face(myLittleFace(index));
}
```

The guard is out-of-line, so it is absent from the binary. `myLittleFace` is an
`NCollection_IndexedMap`, whose `FindKey(size_t)` carries its own `Standard_OutOfRange_Raise_if`,
inline, expanded **inside this `.cxx`** and therefore compiled out at that depth too. Nothing checks
the index at any level.

`Sources/OCCTBridge/src/OCCTBridge_Modeling_HealingSewing.mm`'s `OCCTSewingDeletedFace` adds no
check, so `SewingBuilder.deletedFace(at:)` reaches it directly. Measured: **exit 139 for index 0, 1,
1000 and -1** on a sewing that deleted no face, which is the normal outcome for a well-formed input.
`nbDeletedFaces` correctly reports 0, so a caller who iterates `1...nbDeletedFaces` is safe and a
caller who asks for face 1 is not.

Two further notes. The guard permits `index == 0`, which `FindKey` explicitly rejects, so index 0 is
a defect in OCCT even with the checks compiled in. And the sibling `OCCTSewingIsMultipleEdge`,
forty lines above in the same file, **does** bound-check against `NbMultipleEdges()`; the asymmetry
inside one file is the clearest evidence that the missing check was an oversight rather than a
decision.

## 2. `Intf_Tool::BeginParam` / `EndParam` index a raw `double[6]`

`Intf_Tool.cxx:1641`:

```cpp
double Intf_Tool::BeginParam(const int SegmentNum) const
{
  Standard_OutOfRange_Raise_if(SegmentNum < 1 || SegmentNum > nbSeg, "Intf_Tool::BeginParam");
  return beginOnCurve[SegmentNum - 1];      // double beginOnCurve[6];
}
```

A raw C array, so there is no container check underneath to survive at any depth. `OCCTIntfToolBeginParam`
and `OCCTIntfToolEndParam` pass the caller's index straight through, and `IntfTool.beginParam(segment:)`
documents the index as 1-based while exposing no count: the bridge never wraps
`Intf_Tool::NbSegments()`, so a Swift caller has no way to learn the valid range other than the
return value of `clipLineToBox`.

Measured, after a clip that produced `NbSegments() == 1`:

| index | result |
|---|---|
| 1 | 10, correct |
| 6 | 0.0, inside the array but past `nbSeg` |
| 7 | **11**, which is `endOnCurve[0]`: the *end* parameter of segment 1 returned as the *begin* parameter of segment 7 |
| 0 | 4.24399e-314 |
| 100000000 | -5.38862e-110 |
| 1000000000 | SIGBUS |
| -1000000000, INT_MIN+1 | SIGSEGV |

So the same call is a fabricated measurement for a small out-of-range index and a hard fault for a
large one, which is the worse pair: the first is silent.

## Related

- #2801, the mechanism, and `okf/policies/occt-validation-is-compiled-out.md`.
- #2840 and #636 / carried patch `0024`, the same "bound against the wrong thing" shape in `Extrema`.
- #345, why the fault is uncatchable in-process.
