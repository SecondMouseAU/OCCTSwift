# OCCTSwift#705 reproducer, `ChFi2d_Builder::AddChamfer` null-edge SIGSEGV on a repeated pair

Standalone, deterministic kernel-level reproducer for the uncatchable SIGSEGV in
`Shape.chamfer2D(edgePairs:distances:)` found by Cluster B's fillet/chamfer edge-set census (#665,
`Scripts/repro/cluster-b-fillet-edge-contract/`) and tracked as #705. This directory is the
kernel-level root cause and the carried patch's own evidence, separate from the bridge-side fix
(`OCCTFace2DChamfer`, `OCCTBridge_Modeling.mm`, shipped first per this repo's established
bridge-mitigation-then-kernel-patch pattern, e.g. #298/#341/#344/#349).

## Root cause

`ChFi2d_Builder::AddChamfer(const TopoDS_Edge& E1, const TopoDS_Edge& E2, double D1, double D2)`
(`ChFi2d_Builder_0.cxx`) calls `ChFi2d::FindConnectedEdges(newFace, commonVertex, EE1, EE2)` to look
up the two edges connected to the pair's shared vertex, then dereferences the two output edges
(`EE1.IsSame(E2)`, and both are passed into `ComputeChamfer` two lines later) without checking the
returned status first:

```cpp
TopoDS_Edge EE1, EE2;
status = ChFi2d::FindConnectedEdges(newFace, commonVertex, EE1, EE2);
if (EE1.IsSame(E2))   // no status check first
```

`ChFi2d::FindConnectedEdges` (`ChFi2d.cxx`) returns `ChFi2d_ConnexionError` on **every** failure
path, which is what the fix keys on. It does **not** leave both edges null on every one of them, and
the distinction matters for anyone reasoning about a different failure than this repro's:

| failure | `E1` | `E2` |
|---|---|---|
| vertex absent from the face's vertex-to-edge map (this repro) | unassigned | unassigned |
| vertex present, zero incident edges | unassigned | unassigned |
| exactly one incident edge | **assigned** | unassigned |
| three or more incident edges | **assigned** | **assigned** |

So a guard written against nullness would miss two of the four. The status is uniform across all
four, so that is what the patch checks.

Calling `AddChamfer(E1, E2, D1, D2)` a second time with the *same* pair triggers exactly this: the
first call's own `BuildNewWire` rebuilds the face's wire, replacing the pair's shared vertex with
new ones where the chamfer edge meets the two trimmed edges. The second call's `CommonVertex(E1, E2,
commonVertex)` still finds the *original* vertex (it only looks at `E1`/`E2` themselves, unchanged
references), but that vertex is no longer part of the rebuilt face, so `FindConnectedEdges` fails
and the two null edges it leaves behind reach `ComputeChamfer` unchecked.

`ChFi2d_Builder::AddChamfer(const TopoDS_Edge& E, const TopoDS_Vertex& V, double D, double Ang)`,
the sibling overload calling the identical `FindConnectedEdges`, already checks the status
correctly:

```cpp
status = ChFi2d::FindConnectedEdges(newFace, V, adjEdge1, adjEdge2);
if (status == ChFi2d_ConnexionError)
{
  return aChamfer;
}
```

Confirmed via a debug (`-O0`) single-TU override-link (`ChFi2d_Builder_0.cxx` compiled standalone
and linked *before* `libOCCT-macos.a`, so the linker resolves this TU's symbols from the override,
not the stock archive member) plus the probe's own print statements: the crash happens inside
`ComputeChamfer`, called with both `EE1`/`EE2` null.

**Reachable from OCCT's own tooling, not just this bridge.** OCCT's DRAW `chfi2d` command
(`BRepTest_Fillet2DCommands.cxx`) loops over edge-name arguments from the command line and calls
this same two-edge `AddChamfer` overload once per pair, so `chfi2d result face e1 e2 CD 1 1 e1 e2 CD
1 1` (naming the same two edges twice in one invocation) reaches the identical crash.

## Fix

`Scripts/patches/0022-ChFi2d_Builder-AddChamfer-connexion-error-check-705.patch`: adds the same
status check immediately after `FindConnectedEdges`, returning `chamfer`, the default-constructed
null edge this function already returns on its other refusal paths (`ChFi2d_Builder_0.cxx` lines
83, 89, 95), rather than a new value. Four lines, matching the sibling overload's own idiom line for
line.

## Reproducer

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  Scripts/repro/705-chamfer2d-duplicate-pair/occt_705_chamfer_dup.mm -o /tmp/occt_705_stock \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++
/tmp/occt_705_stock
```

Against the pinned `v2.0.0-kernel.1` (`V8_0_1` + the eleven carried patches before this one):

```
edge count: 4
about to call AddChamfer the FIRST time on edges (0,1)
first call returned, IsNull=0, status=5
about to call AddChamfer the SECOND time on the SAME pair (0,1)
Segmentation fault: 11
```

raw exit code 139, deterministic, every run.

### Verifying the patch

Override-link `ChFi2d_Builder_0.cxx` with the patch applied, compiled standalone with the same
`-DNo_Exception` the production kernel is built with, and link it *before* `-lOCCT-macos`:

```bash
clang++ -c -std=gnu++17 -O0 -g -w -DNDEBUG -DNo_Exception -DOCC_CONVERT_SIGNALS \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  ChFi2d_Builder_0_patched.cxx -o ChFi2d_Builder_0_patched.o
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  Scripts/repro/705-chamfer2d-duplicate-pair/occt_705_chamfer_dup.mm ChFi2d_Builder_0_patched.o \
  -o /tmp/occt_705_patched \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++
/tmp/occt_705_patched
```

```
edge count: 4
about to call AddChamfer the FIRST time on edges (0,1)
first call returned, IsNull=0, status=5
about to call AddChamfer the SECOND time on the SAME pair (0,1)
second call returned, IsNull=1, status=7
PROBE: completed without crashing
```

exit 0. `status=5` is `ChFi2d_IsDone` (the first call succeeds normally), `status=7` is
`ChFi2d_ConnexionError` (the second call now reports the same refusal the sibling overload already
gives for an unconnected vertex, instead of crashing). The first call's own result is byte-identical
before and after the patch: same `IsNull`, same `status`.

`clang-format --dry-run --Werror` on the patched file reports only pre-existing, unrelated
violations elsewhere in the file (`Geom2dInt_GInter` construction, shifted by 4 lines, same count
and content before and after this patch); the four added lines are clean.

## Reachable from this wrapper

`Shape.chamfer2D(edgePairs:distances:)` (`Sources/OCCTSwift/Shape+Geom2d.swift`, bridge
`OCCTFace2DChamfer` in `Sources/OCCTBridge/src/OCCTBridge_Modeling.mm`) is the one Swift entry point
that reaches `BRepFilletAPI_MakeFillet2d::AddChamfer(edge, edge, ...)` with caller-controlled edge
pairs. The bridge now guards the duplicate-pair case itself (shipped ahead of this kernel patch,
same PR1-then-PR2 pattern as #298/#341/#344/#349), so this defect is not reachable through the
current bridge; this reproducer isolates the kernel-level mechanism the guard exists to protect
against, and is what the guard becomes redundant against once this patch ships in a release.

`fillet2D(vertexIndices:radii:)`, the sibling entry point on the same `BRepFilletAPI_MakeFillet2d`
builder, does not reach this code path at all: a duplicated vertex index calls `AddFillet` twice,
which fails at `Build()`/`IsDone()` rather than through `FindConnectedEdges`.

## Upstream

Filed as [Open-Cascade-SAS/OCCT#1431](https://github.com/Open-Cascade-SAS/OCCT/issues/1431) (repro)
/ [OCCT#1432](https://github.com/Open-Cascade-SAS/OCCT/pull/1432) (fix, this patch).
