# Phase 3: OCCTMeshTests Injection Matrix

**Target**: `Tests/OCCTMeshTests/` (97 tests in 7 files), issue #1985.
**Policy**: [`prove-the-test-fails.md`](../../../policies/prove-the-test-fails.md): inject a defect,
confirm the test fails (red), restore, confirm it passes (green).

## What this file replaces

The previous version of this file and of `kernel-parity/OCCTMeshTests.json` were removed, not
amended. An audit on 2026-09-23 found none of their 20 parity records and 13 matrix rows
genuine: all 14 bridge function names they cited (`OCCTBRepMeshDeflection`,
`OCCTMeshBooleanUnion`, `OCCTPolyMergeNodesTool`, ...) resolve to nothing in
`Sources/OCCTBridge`, every `kernel_output` was a placeholder equal to its `bridge_output`
(`0.0 == 0.0`, `{} == {}`), six records named tests that do not exist, and the matrix's Red/Green
ticks were added by a bot commit (3e0578ca) with no test run behind them.

Every row below was run. Each injection set was applied to `Sources/`, the named tests were run
with `swift test --filter`, and the set was reverted (`git diff Sources/` empty) before the green
run. Kernel values come from the probe under `Scripts/repro/<dir>/`, whose output is committed
beside it as `transcript.txt`.

**Covered so far**: 97 of 97 tests.

## Findings filed from this execution

- #2301: mesh booleans operate on sewn shells, not solids. Union encloses 2000 where the solid
  union is 1500, box minus cylinder removes nothing, box and sphere intersect to an empty mesh.
  The three tests assert the correct volumes under `withKnownIssue`.
- #2337: `Mesh.normals` is `(0, 0, 1)` at every vertex of a meshed shape; `BRepMesh` stores no
  normals and the bridge writes a placeholder.

## `Issue197MeshDeflectionTests.swift` (3 tests)

Probe: `Scripts/repro/766-mesh-issue197/`.

| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Issue #197, mesh deflection is a caller-tunable parameter | binary STL: finer deflection yields a larger file (more triangles) | `OCCTShapeWriteSTLBinary` | R1: pass 1.0 instead of the caller's deflection to OCCTExportSTLWithMode | :42 `fineSize > coarseSize` | ✔ | MATCH |
| Issue #197, mesh deflection is a caller-tunable parameter | default deflection (0.1) still writes a valid STL **(rewritten)** | `OCCTShapeWriteSTLBinary` | R1: pass 1.0 instead of the caller's deflection to OCCTExportSTLWithMode | :60 `size == 84 + 50 * 976` | ✔ | MATCH |
| Issue #197, mesh deflection is a caller-tunable parameter | coherent triangulation builds at the requested deflection **(rewritten)** | `OCCTCoherentTriangulationCreateFromMesh` | R1: BRepMesh_IncrementalMesh(shape, 0.1), ignoring deflection | :73 `coarse.triangleCount == 516` | ✔ | MATCH |

Rewritten because the original could not fail for the defect its title names:

- **default deflection (0.1) still writes a valid STL**: asserted `size > 84`, which any non-empty STL at any deflection passes; now pins 84 + 50 * 976.
- **coherent triangulation builds at the requested deflection**: asserted only `tri != nil`, which a builder ignoring deflection passes; now pins the triangle count at two deflections.

## `Issue211MeshParamTests.swift` (3 tests)

Probe: `Scripts/repro/766-mesh-issue211/`.

| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Issue #211, allowQualityDecrease mesh parameter | default is false | none (`MeshParameters.default`, Swift) | R1: MeshParameters.default.allowQualityDecrease = true (Mesh.swift) | :12 `MeshParameters.default.allowQualityDecrease == false` | ✔ | MATCH |
| Issue #211, allowQualityDecrease mesh parameter | meshing with the flag set produces a valid mesh | `OCCTShapeCreateMeshWithParams` | R2: return nullptr when params.allowQualityDecrease is set | :25 `Bool(false)` (the guard's else branch) | ✔ | MATCH |
| Issue #211, allowQualityDecrease mesh parameter | allows a coarser re-mesh to replace a finer one **(rewritten)** | `OCCTShapeCreateMeshWithParams` | R1: meshParams.AllowQualityDecrease = Standard_False, dropping the flag | :51 `coarseA.triangleCount == 306` | ✔ | MATCH |

Rewritten because the original could not fail for the defect its title names:

- **allows a coarser re-mesh to replace a finer one**: meshed two separate fresh spheres, so the flag played no part and dropping it left the test green; now re-meshes one shape, with a flag-off control.

## `Issue375MeshWindingTests.swift` (2 tests)

Probe: `Scripts/repro/766-mesh-issue375/`.

| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Issue #375, mesh() winding reflects true topological orientation, not a naive transform read | a mirrored valid solid still meshes 100% outward, matching the un-mirrored original | `OCCTShapeCreateMesh` | R1: REVERSED faces no longer swap n2/n3 | :55 `boxOutward == 1.0`, :58 `mirroredOutward == 1.0` | ✔ | MATCH |
| Issue #375, mesh() winding reflects true topological orientation, not a naive transform read | mesh(parameters:) has the same outward-normalization behavior as the deflection overload | `OCCTShapeCreateMeshWithParams` | R1: REVERSED faces no longer swap n2/n3 | :73 `mirroredOutward == 1.0` | ✔ | MATCH |

## `Issue1440Polygon3DParameterGuardTests.swift` (2 tests)

Probe: `Scripts/repro/766-mesh-issue1440/`.

| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Issue #1440: Polygon3D.parameter(at:) null-Handle guard | a no-params polygon's parameter(at:) is safe, not a crash | `OCCTPolyPolygon3DParameter` | R3: HasParameters() guard removed | process killed, signal 11 (SIGSEGV) inside the test | ✔ | MATCH on HasParameters; the 0 fallback is bridge behaviour (the kernel call it guards segfaults) |
| Issue #1440: Polygon3D.parameter(at:) null-Handle guard | a with-parameters polygon still returns its real stored values | `OCCTPolyPolygon3DParameter` | R1: read Parameters()(NbNodes() - index), reversed order | :54 `polygon.parameter(at: i) == expected` (i = 0 and i = 2) | ✔ | MATCH |

## `Issue1566MergeNodesOverflowGuardTests.swift` (5 tests)

Probe: `Scripts/repro/766-mesh-issue1566/`.

| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow | generous buffers: succeeds, reports the true counts, and every count matches the write | `OCCTPolyMergeNodes` | R2: *outTriangleCount never written | :61 `triCount > 0` | ✔ | MATCH |
| Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow | vertex buffer too small: refuses (returns 0), does not touch outTriangleCount | `OCCTPolyMergeNodes` | R1b: verticesOverflow = false (the #1566 refusal removed) | process killed, signal 5, writing 24 nodes into a 1-node buffer | ✔ | MATCH: kernel NbNodes 24 > maxVertices 1, so the refusal is the correct outcome; the refusal itself has no kernel counterpart |
| Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow | index buffer too small: refuses (returns 0), does not touch outTriangleCount | `OCCTPolyMergeNodes` | R2: indicesOverflow = false (the #1566 refusal removed) | :123 `nVerts == 0` | ✔ | MATCH: kernel needs 36 indices > maxIndices 1, so the refusal is the correct outcome; the refusal itself has no kernel counterpart |
| Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow | a null outIndices is not gated on maxIndices, even when maxIndices is 0 | `OCCTPolyMergeNodes` | R4: indicesOverflow no longer gated on outIndices being non-null | :146 `nVerts > 0`, :147 `triCount > 0` | ✔ | MATCH |
| Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow | mergedMeshNodes still succeeds normally for an ordinary box (non-regression) | `OCCTPolyMergeNodes` | R2: *outTriangleCount never written | :157 `merged.triangleCount > 0` | ✔ | MATCH |

## `Issue613MeshIndexContractTests.swift` (9 tests)

Probe: `Scripts/repro/766-mesh-issue613/`.

| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Mesh face indices address faces(), and winding survives a shared wall (#613) | the fixture really does share one face between two solids | `OCCTShapeGetFaceCount, OCCTShapeGetOrientedFaces` | R4: Shape.faceCount reads OCCTShapeGetFaceOccurrenceCount (the pre-#651 explorer count) | :80 `compound.faceCount == 11` | ✔ | MATCH |
| Mesh face indices address faces(), and winding survives a shared wall (#613) | no triangle claims a face index faces() cannot address | `OCCTShapeCreateMesh` | R4: faceIndex stamped from an occurrence counter, not the map index | :111 `compound.face(at: i) != nil` | ✔ | MATCH |
| Mesh face indices address faces(), and winding survives a shared wall (#613) | a triangle's faceIndex names the face that triangle lies on | `OCCTShapeCreateMesh` | R4: faceIndex stamped from an occurrence counter, not the map index | :135 `#require(compound.face(at:))`, :143 `abs(Self.dot(offset, normal)) < 1e-6` | ✔ | MATCH |
| Mesh face indices address faces(), and winding survives a shared wall (#613) | both sides of the shared wall are stamped with the one index that names it | `OCCTShapeCreateMesh` | R4: faceIndex stamped from an occurrence counter, not the map index | :174 `wallIndices.count == 1` | ✔ | MATCH |
| Mesh face indices address faces(), and winding survives a shared wall (#613) | every mesh triangle is wound outward for the solid that owns it (control) | `OCCTShapeCreateMesh` | R4: winding swapped for FORWARD faces instead of REVERSED (global inversion) | :223 `inward == 0` | ✔ | MATCH |
| Mesh face indices address faces(), and winding survives a shared wall (#613) | a plain box still meshes entirely outward | `OCCTShapeCreateMesh` | R4: winding swapped for FORWARD faces instead of REVERSED (global inversion) | :250 `outward == 12`, :251 `inward == 0` | ✔ | MATCH |
| Mesh face indices address faces(), and winding survives a shared wall (#613) | the parameterised mesh entry point holds the same index contract | `OCCTShapeCreateMeshWithParams` | R4: faceIndex stamped from an occurrence counter, not the map index | :267 `compound.face(at: i) != nil`, :286 `wallIndices.count == 1` | ✔ | MATCH |
| Mesh face indices address faces(), and winding survives a shared wall (#613) | merged mesh nodes keep both sides of a shared wall, oppositely wound | `OCCTPolyMergeNodes` | R4: reversed flag passed to AddTriangulation forced false | :316 `minusX > 0`, :317 `plusX == minusX` | ✔ | MATCH |
| Mesh face indices address faces(), and winding survives a shared wall (#613) | merged mesh nodes on a plain box are entirely outward | `OCCTPolyMergeNodes` | R4: reversed flag passed to AddTriangulation forced false | :341 `outward == 12`, :342 `inward == 0` | ✔ | MATCH |

## `OCCTMeshTests.swift` (73 tests)

Probe: `Scripts/repro/766-mesh-core-1/`, `Scripts/repro/766-mesh-core-2/`, `Scripts/repro/766-mesh-core-3/`, `Scripts/repro/766-mesh-core-4/`.

| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Mesh from raw arrays | Round-trip vertices and indices | `OCCTMeshCreateFromArrays` | C1: second and third index of every triangle swapped on the way in | :47 `idxs == Self.tetIndices` | ✔ | N/A: OCCTMeshCreateFromArrays copies and validates caller arrays and calls no OCCT API |
| Mesh from raw arrays | Computed normals when none provided produce unit-length per-vertex normals | `OCCTMeshCreateFromArrays` | C1: accumulated vertex normals never renormalised | :72 `abs(len - 1.0) < 1e-5 || len < 1e-9` (all four vertices) | ✔ | N/A: OCCTMeshCreateFromArrays copies and validates caller arrays and calls no OCCT API |
| Mesh from raw arrays | Provided normals are preserved verbatim | `OCCTMeshCreateFromArrays` | C1: supplied normals ignored | :97, :98, :99 (each vertex) | ✔ | N/A: OCCTMeshCreateFromArrays copies and validates caller arrays and calls no OCCT API |
| Mesh from raw arrays | Empty inputs return nil | `OCCTMeshCreateFromArrays` | C1: validation removed from BOTH layers (Mesh.init guard and OCCTMeshCreateFromArrays); removing either layer alone leaves the other rejecting, by design | :105 `Mesh(vertices: [], indices: []) == nil`, :106, then process abort (signal 6) on :107's null vertex buffer | ✔ | N/A: OCCTMeshCreateFromArrays copies and validates caller arrays and calls no OCCT API |
| Mesh from raw arrays | Index count not divisible by 3 returns nil | `OCCTMeshCreateFromArrays` | C1: validation removed from BOTH layers (Mesh.init guard and OCCTMeshCreateFromArrays); removing either layer alone leaves the other rejecting, by design | :112 `Mesh(vertices:indices: [0, 1]) == nil`, :113 | ✔ | N/A: OCCTMeshCreateFromArrays copies and validates caller arrays and calls no OCCT API |
| Mesh from raw arrays | Out-of-range index returns nil | `OCCTMeshCreateFromArrays` | C1: validation removed from BOTH layers (Mesh.init guard and OCCTMeshCreateFromArrays); removing either layer alone leaves the other rejecting, by design | process abort (signal 6) reading vertex 9 of 4 | ✔ | N/A: OCCTMeshCreateFromArrays copies and validates caller arrays and calls no OCCT API |
| Mesh from raw arrays | Mismatched normals length returns nil | `OCCTMeshCreateFromArrays` | C1: Mesh.init's normals-length check removed (the bridge cannot check it: it takes no normals count) | :125 `Mesh(vertices:normals:indices:) == nil` | ✔ | N/A: OCCTMeshCreateFromArrays copies and validates caller arrays and calls no OCCT API |
| Mesh Tests | Mesh from shape **(rewritten)** | `OCCTShapeCreateMesh` | C2: the first face dropped from the extraction | :160 `mesh.vertexCount == 24`, :161 `triangleCount == 12`, :162 volume | ✔ | MATCH |
| Mesh Tests | Mesh data access **(rewritten)** | `OCCTMeshGetVertices, OCCTMeshGetNormals, OCCTMeshGetIndices` | C3: OCCTMeshGetVertices copies the normals buffer | :187 `offSphere.isEmpty` | ✔ | MATCH |
| Mesh Tests | Enhanced mesh parameters | `OCCTShapeCreateMeshWithParams` | C2: the parameterised entry point returns an empty mesh | :199 `mesh.vertexCount > 0`, :200 | ✔ | MATCH |
| Mesh Tests | Triangles with face info | `OCCTMeshGetTrianglesWithFaces` | C2: every faceIndex reported as -1 | :217 `tri.faceIndex >= 0` (all 12) | ✔ | MATCH |
| Mesh Tests | Mesh to shape conversion | `OCCTMeshToShapeWithTolerance` | C3: the sewn shape dropped (return nullptr on success) | :228 `shape != nil` | ✔ | MATCH |
| Mesh Tests | toShape weldTolerance: default parity, guards, and large-mesh welding | `OCCTMeshToShapeWithTolerance` | C2: BRepBuilderAPI_Sewing built at 1e-6 whatever the caller asks | :266 `weldedEdges < tightEdges` | ✔ | MATCH |
| Mesh Tests | Mesh boolean union | `OCCTMeshUnion` | C2: occtMeshBoolean returns nullptr | :285 `unionMesh != nil` | ✔ | MATCH bridge vs kernel pipeline; both wrong against the solid Boolean (1500), filed as #2301, asserted under withKnownIssue |
| Mesh Tests | Mesh boolean subtraction | `OCCTMeshSubtract` | C2: occtMeshBoolean returns nullptr | :305 `diffMesh != nil` | ✔ | MATCH bridge vs kernel pipeline; nothing is removed against the solid Boolean (858.63), filed as #2301, asserted under withKnownIssue |
| Mesh Tests | Mesh boolean intersection | `OCCTMeshIntersect` | C2: occtMeshBoolean returns nullptr | :323 `intersectMesh != nil` | ✔ | MATCH bridge vs kernel pipeline; result is EMPTY against the solid Boolean (959.23), filed as #2301, asserted under withKnownIssue |
| Presentation Mesh Tests | Box shaded mesh has 12 triangles **(rewritten)** | `OCCTShapeGetShadedMesh` | D1: computed vertex normals never accumulated (left zero) | :354 `len > 0.5` (every vertex) | ✔ | MATCH |
| Presentation Mesh Tests | Cylinder shaded mesh has triangles **(rewritten)** | `OCCTShapeGetShadedMesh` | D1b: the shape's first face skipped in both passes | :363 `mesh.triangleCount == 100`, :364 | ✔ | MATCH |
| Presentation Mesh Tests | Box edge mesh has 12 segments **(rewritten)** | `OCCTShapeGetEdgeMesh` | D1: every edge emitted twice (the per-face explorer duplicate the edge map exists to prevent) | :372 `edges.segmentCount == 12`, :373 | ✔ | MATCH |
| Presentation Mesh Tests | Sphere edge mesh produces valid segments **(rewritten)** | `OCCTShapeGetEdgeMesh` | D1: every edge emitted twice | :382 `edges.segmentCount == 3`, :383 | ✔ | MATCH |
| Drawer Mesh Extraction | Shaded mesh with default drawer produces valid mesh | `OCCTShapeGetShadedMeshWithDrawer` | D4: the drawer entry points return false | :398 `mesh != nil` | ✔ | MATCH |
| Drawer Mesh Extraction | Edge mesh with default drawer produces valid segments | `OCCTShapeGetEdgeMeshWithDrawer` | D4: the drawer entry points return false | :412 `mesh != nil` | ✔ | MATCH |
| Drawer Mesh Extraction | Finer deviation produces more triangles for curved shape | `OCCTShapeGetShadedMeshWithDrawer, OCCTDrawerSetDeviationCoefficient` | D2b: DisplayDrawer.deviationCoefficient's setter drops the value | :435 `fine.triangleCount > coarse.triangleCount` | ✔ | MATCH |
| Drawer Mesh Extraction | Absolute deflection type works **(rewritten)** | `OCCTShapeGetShadedMeshWithDrawer, OCCTDrawerSetTypeOfDeflection` | D2b: DisplayDrawer.deflectionType's setter drops the value | :451 `mesh.triangleCount == 648` | ✔ | MATCH |
| Drawer Mesh Extraction | Relative deflection scales with shape size, matching OCCT's own reference caller (#1418) | `OCCTShapeGetShadedMeshWithDrawer (occtDrawerGetEffectiveDeflection)` | D2b: the raw DeviationCoefficient used as an absolute deflection (the pre-#1418 bug) | :480 `ratio < 10` | ✔ | MATCH |
| Issue1224 Presentation Mesh Overload Parity | shadedMesh(deflection:) and shadedMesh(drawer:) deinterleave identically | `OCCTShapeGetShadedMesh, OCCTShapeGetShadedMeshWithDrawer` | D2: shadedMesh(drawer:) negates the normals after the shared deinterleave (a fix applied to one overload only) | :517 `a.normals == b.normals` | ✔ | MATCH on counts; the equality under test is between two Swift overloads, which has no kernel counterpart |
| Issue1224 Presentation Mesh Overload Parity | edgeMesh(deflection:) and edgeMesh(drawer:) deinterleave identically | `OCCTShapeGetEdgeMesh, OCCTShapeGetEdgeMeshWithDrawer` | D2: edgeMesh(drawer:) reverses the vertex order after the shared deinterleave | :535 `a.vertices == b.vertices` | ✔ | MATCH on counts; the equality under test is between two Swift overloads, which has no kernel counterpart |
| MeshCoordinateSystem Enum | Raw values | `none (Swift enum mirroring RWMesh_CoordinateSystem)` | D1: case yUp = 2 | :549 `MeshCoordinateSystem.yUp.rawValue == 1` | ✔ | MATCH |
| MeshCoordinateSystem Enum | Aliases | `none (Swift enum mirroring RWMesh_CoordinateSystem)` | D1: gltf aliased to .zUp | :555 `MeshCoordinateSystem.gltf == .yUp` | ✔ | MATCH |
| MeshCoordinateSystem Enum | Init from raw value | `none (Swift enum mirroring RWMesh_CoordinateSystem)` | D1: case yUp = 2 | :562 `MeshCoordinateSystem(rawValue: 1) == .yUp` | ✔ | MATCH |
| BRepMesh Deflection | Compute absolute deflection **(rewritten)** | `OCCTComputeAbsoluteDeflection` | D1: relative deflection ignored (0.1 passed) | :578 `abs(absDef - 0.150000001) < 1e-9` | ✔ | MATCH |
| BRepMesh Deflection | Deflection consistency check **(rewritten)** | `OCCTDeflectionIsConsistent` | D1: always returns true | :588 `!Shape.deflectionIsConsistent(current: 0.3, required: 0.2)` | ✔ | MATCH |
| BRepBuilderAPI MakeShapeOnMesh | Build shape from mesh **(rewritten)** | `OCCTShapeFromMesh` | D1: builder result dropped (null on success) | :611 `#require(Shape.fromMesh(...))` | ✔ | MATCH |
| BRepBuilderAPI MakeShapeOnMesh | Mesh with minimal geometry | `OCCTShapeFromMesh` | D1: builder result dropped (null on success) | :627 `shape != nil` | ✔ | MATCH |
| BRepGProp MeshCinert Tests | prepare polygon and compute **(rewritten)** | `OCCTMeshCinertPreparePolygon, OCCTMeshCinertCompute` | E1: PreparePolygon drops the last point | :646 `points.count == 2`, :648 `abs(result.mass - 10) < 1e-9` | ✔ | MATCH |
| BRepGProp MeshProps Tests | surface mesh properties **(rewritten)** | `OCCTMeshPropsCompute` | E1: Surface and Volume swapped in the type mapping | :660 `abs(result.mass - 100) < 1e-9` | ✔ | MATCH |
| BRepGProp MeshProps Tests | volume mesh properties **(rewritten)** | `OCCTMeshPropsCompute` | E1: Surface and Volume swapped in the type mapping | :671 `abs(result.mass - 500.0 / 3.0) < 1e-9` | ✔ | MATCH |
| BRepMesh ShapeTool Tests | max face tolerance **(rewritten)** | `OCCTMeshShapeToolMaxFaceTolerance` | E1: guard inverted, returns the 0 fallback | :683 `abs(face.maxMeshTolerance - 1e-7) < 1e-15` | ✔ | MATCH |
| BRepMesh ShapeTool Tests | box max dimension **(rewritten)** | `OCCTMeshShapeToolBoxMaxDimension` | E1: bounding box enlarged by 1.0 | :691 `abs(maxDim - 10.0000002) < 1e-9` | ✔ | MATCH |
| BRepMesh ShapeTool Tests | UV points on edge **(rewritten)** | `OCCTMeshShapeToolUVPoints` | E1: the two UV points swapped | :703 first point, :704 second point | ✔ | MATCH |
| Poly_Polygon3D | create without parameters **(rewritten)** | `OCCTPolyPolygon3DCreate, OCCTPolyPolygon3DHasParameters` | E1: HasParameters always true | :715 `!poly.hasParameters` | ✔ | MATCH |
| Poly_Polygon3D | create with parameters **(rewritten)** | `OCCTPolyPolygon3DCreateWithParams, OCCTPolyPolygon3DParameter` | E1: CreateWithParams builds the no-parameter polygon | :725 `abs(poly.parameter(at: 1) - 10.0) < 1e-10` | ✔ | MATCH |
| Poly_Polygon3D | deflection **(rewritten)** | `OCCTPolyPolygon3DSetDeflection` | E1: SetDeflection is a no-op | :733 `abs(poly.deflection - 1.0) < 1e-10` | ✔ | MATCH |
| Poly_PolygonOnTriangulation | create without parameters **(rewritten)** | `OCCTPolyPolygonOnTriCreate, OCCTPolyPolygonOnTriHasParameters` | E1: HasParameters always true | :746 `!poly.hasParameters` | ✔ | MATCH |
| Poly_PolygonOnTriangulation | create with parameters **(rewritten)** | `OCCTPolyPolygonOnTriCreateWithParams` | E1: CreateWithParams builds the no-parameter polygon | :756 `abs(poly.parameter(at: 1) - 1.0) < 1e-10` | ✔ | MATCH |
| Poly_PolygonOnTriangulation | deflection **(rewritten)** | `OCCTPolyPolygonOnTriSetDeflection` | E1: SetDeflection is a no-op | :764 `abs(poly.deflection - 0.1) < 1e-10` | ✔ | MATCH |
| Poly_MergeNodesTool | merge mesh nodes from shape **(rewritten)** | `OCCTPolyMergeNodes` | E1: smoothAngle ignored (pi) | :777 `merged.vertexCount == 24` | ✔ | MATCH |
| Poly_CoherentTriangulation | create empty and add nodes | `OCCTCoherentTriangulationSetNode` | E1: SetNode returns index + 1 | :807, :808, :809 | ✔ | MATCH |
| Poly_CoherentTriangulation | add and count triangles | `OCCTCoherentTriangulationAddTriangle` | E2: AddTriangle returns false without adding | :815 `ct.triangleCount == 2` | ✔ | MATCH |
| Poly_CoherentTriangulation | remove triangle | `OCCTCoherentTriangulationRemoveTriangle, OCCTCoherentTriangulationNTriangles` | E1: NTriangles reads the bridge's own add-list, which removal does not shrink | :822 `ct.triangleCount == 1` | ✔ | MATCH |
| Poly_CoherentTriangulation | compute links **(rewritten)** | `OCCTCoherentTriangulationComputeLinks` | E1: ComputeLinks returns 0 without computing | :830 `nLinks == 5`, :831 `ct.linkCount == 5` | ✔ | MATCH |
| Poly_CoherentTriangulation | deflection set/get | `OCCTCoherentTriangulationSetDeflection` | E1: SetDeflection is a no-op | :838 `abs(ct.deflection - 0.5) < 1e-10` | ✔ | MATCH |
| Poly_CoherentTriangulation | convert back to triangulation **(rewritten)** | `OCCTCoherentTriangulationGetResult` | E3: result dropped, reports failure | :848 `#require(ct.getResult())` | ✔ | MATCH |
| Poly_CoherentTriangulation | create from mesh **(rewritten)** | `OCCTCoherentTriangulationCreateFromMesh` | E1: returns null for a meshed shape | :858 `#require(CoherentTriangulation.createFromMesh(box))` | ✔ | MATCH |
| Poly_CoherentTriangulation | node coordinates after result **(rewritten)** | `OCCTCoherentTriangulationNodeCoords` | E1: reads Node(index + 1), one past the node asked for | :873, :874, :875 | ✔ | MATCH |
| Poly_Connect Mesh Adjacency Tests | triangleAdjacency **(rewritten)** | `OCCTMeshTriangleAdjacency` | F1: the first and third neighbour swapped | :893 `adj.0 == 0 && adj.1 == 0 && adj.2 == 2` | ✔ | MATCH |
| Poly_Connect Mesh Adjacency Tests | nodeTriangle **(rewritten)** | `OCCTMeshNodeTriangle` | F1: Triangle(node) + 1 | :900 `triIdx == 1` | ✔ | MATCH |
| Poly_Connect Mesh Adjacency Tests | nodeTriangleCount **(rewritten)** | `OCCTMeshNodeTriangleCount` | F1: the fan count starts at 1 | :907 `count == 1` | ✔ | MATCH |
| v0.115.0 - Triangulation Queries | faceTriangulation **(rewritten)** | `OCCTFaceTriangulationNodeCount (and TriangleCount, Deflection, Node, Triangle)` | F1: NodeCount returns NbTriangles | :919 `face.triangulationNodeCount == 4` | ✔ | MATCH |
| v0.115.0 - Triangulation Queries | triangulationUVNodes **(rewritten)** | `OCCTFaceTriangulationHasUVNodes, OCCTFaceTriangulationUVNode` | F1: HasUVNodes returns false | :941 `face.triangulationHasUVNodes` | ✔ | MATCH |
| v0.160 MeshCache write API | Triangulation create from arrays round-trips **(rewritten)** | `OCCTPolyTriangulationCreate` | F1: the 2nd and 3rd index of each triangle swapped | :961 `t0.0 == 0 && t0.1 == 1 && t0.2 == 2` | ✔ | MATCH |
| v0.160 MeshCache write API | Triangulation rejects malformed inputs | `Triangulation.create (Swift guard) / OCCTPolyTriangulationCreate` | F1: Triangulation.create's index-range guard removed (the bridge does not check range) | :972 `Triangulation.create(nodes:triangles: [0, 1, 99]) == nil` | ✔ | N/A: input validation in the Swift layer; the bridge and kernel accept an out-of-range index |
| v0.160 MeshCache write API | Create triangulation rep and bind it to a face **(rewritten)** | `OCCTBRepGraphMeshCreateTriangulationRep, OCCTBRepGraphMeshAppendCachedTriangulation, OCCTBRepGraphMeshFaceActiveTriangulationRepId` | F1: AppendCachedTriangulation is a no-op | :993 `graph.meshFaceActiveTriangulationRepId(0) != nil` | ✔ | MATCH |
| v0.160 MeshCache write API | Create polygon3D rep and bind it to an edge **(rewritten)** | `OCCTBRepGraphMeshCreatePolygon3DRep, OCCTBRepGraphMeshSetCachedPolygon3D, OCCTBRepGraphMeshEdgePolygon3DRepId` | F2 (alone): SetCachedPolygon3D is a no-op | :1006 `graph.meshEdgePolygon3DRepId(0) != nil` | ✔ | MATCH |
| v0.158 MeshView two-tier mesh storage | Mesh count properties are non-negative on a fresh graph **(rewritten)** | `OCCTBRepGraphNbTriangulations, NbPolygons3D, MeshNbPolygons2D, MeshNbPolygonsOnTri, MeshNbActive*` | F1: BRepGraph.triangulationCount reads the face count | :1018 `graph.triangulationCount == 0` | ✔ | MATCH |
| v0.158 MeshView two-tier mesh storage | Mesh rep id queries return nil when no mesh is present **(rewritten)** | `OCCTBRepGraphMeshFaceActiveTriangulationRepId, OCCTBRepGraphMeshEdgePolygon3DRepId, OCCTBRepGraphMeshCoEdgeHasMesh` | F1: EdgePolygon3DRepId reports presence unconditionally | :1034 `graph.meshEdgePolygon3DRepId(0) == nil` | ✔ | MATCH |
| v0.158 MeshView two-tier mesh storage | Mesh counts after incremental meshing **(rewritten)** | `OCCTBRepGraphFaceHasTriangulation, OCCTBRepGraphMeshFaceActiveTriangulationRepId, OCCTBRepGraphNbTriangulations` | F1: face triangulation presence reads the cache tier only (the #1547 regression) | :1051 `graph.faceHasTriangulation(0) == true`, :1052 | ✔ | MATCH |
| v0.158 MeshView two-tier mesh storage | Mesh edge polygon3D rep id resolves the persistent tier (#1547) **(rewritten)** | `OCCTBRepGraphSetEdgePolygon3DRepId, OCCTBRepGraphEdgeHasPolygon3D` | F1: SetEdgePolygon3DRepId is a no-op | :1065 `graph.edgeHasPolygon3D(0) == true` | ✔ | MATCH |
| Poly Copy & Mutators | Polygon2D copy preserves contents **(rewritten)** | `OCCTPolyPolygon2DCopy` | F1: copy rebuilt from the nodes alone, dropping the deflection | :1088 `abs(copy.deflection - 0.25) < 1e-12` | ✔ | MATCH |
| Poly Copy & Mutators | PolygonOnTriangulation copy preserves nodes **(rewritten)** | `OCCTPolyPolygonOnTriCopy` | F1: the copy's first node overwritten | :1098 `copy.nodeIndex(at: i) == Int(indices[i])` | ✔ | MATCH |
| Poly Copy & Mutators | PolygonOnTriangulation setNodes mutates in place **(rewritten)** | `OCCTPolyPolygonOnTriSetNodes` | F1: size mismatch clamped instead of refused | :1110 `!poly.setNodes([1, 2])` | ✔ | MATCH |
| Poly Copy & Mutators | PolygonOnTriangulation setParameters mutates in place **(rewritten)** | `OCCTPolyPolygonOnTriSetParameters` | F1: size mismatch clamped instead of refused | :1122 `!poly.setParameters([1.0])` | ✔ | MATCH |
| Poly Copy & Mutators | setParameters fails when polygon has no parameters **(rewritten)** | `OCCTPolyPolygonOnTriSetParameters` | F1: the HasParameters() refusal returns true | :1130 `!poly.setParameters([0.0, 1.0, 2.0])` | ✔ | MATCH |

Rewritten because the original could not fail for the defect its title names:

- **Mesh from shape**: read vertexCount and triangleCount and asserted nothing; now pins 24 / 12 and the enclosed volume 150.
- **Mesh data access**: its two length checks are true by construction (all arrays are sized from vertexCount / triangleCount); now checks every index addresses a vertex and every vertex lies on the sphere.
- **Box shaded mesh has 12 triangles**: force-unwrapped inside #expect (a nil result crashed the process instead of failing); now #require.
- **Cylinder shaded mesh has triangles**: force-unwrapped inside #expect (a nil result crashed the process instead of failing) and asserted only `> 0`; now pins 100 / 106.
- **Box edge mesh has 12 segments**: force-unwrapped inside #expect (a nil result crashed the process instead of failing); now #require, and pins 24 vertices.
- **Sphere edge mesh produces valid segments**: force-unwrapped inside #expect (a nil result crashed the process instead of failing) and asserted only `> 0`; now pins 3 / 18.
- **Absolute deflection type works**: meshed a box, which gives 12 triangles at any deflection; now a sphere, where absolute 0.5 (648) and the relative default (1244) differ.
- **Compute absolute deflection**: was `if let absDef { #expect(absDef > 0) }`, which a nil result skipped; now pins the kernel value.
- **Deflection consistency check**: asserted only true cases, so an always-true answer passed; adds 0.3 against 0.2, which the kernel calls inconsistent.
- **Build shape from mesh**: was `if let shape`, so a nil result passed; now #require, and pins 4 faces and 6 edges.
- **prepare polygon and compute**: wrapped its assertions in `if let`, so a nil result skipped them; now #require, and pins 2 points and a mass of 10 (it asserted `> 0`).
- **surface mesh properties**: wrapped its assertions in `if let`, so a nil result skipped them; now #require, and pins the area 100.
- **volume mesh properties**: asserted nothing ("just don't crash"); now pins the face's volume contribution 500/3.
- **max face tolerance**: wrapped its assertions in `if let`, so a nil result skipped them; now #require, and pins 1e-7 (it asserted `> 0`).
- **box max dimension**: asserted `abs(maxDim - 10) < 1.0`, which a 1.0 enlargement passes; now 1e-9 about the kernel value.
- **UV points on edge**: asserted nothing ("just verify no crash"); now pins both UV points.
- **create without parameters**: wrapped its assertions in `if let`, so a nil result skipped them; now #require.
- **create with parameters**: wrapped its assertions in `if let`, so a nil result skipped them; now #require.
- **deflection**: wrapped its assertions in `if let`, so a nil result skipped them; now #require.
- **create without parameters**: wrapped its assertions in `if let`, so a nil result skipped them; now #require.
- **create with parameters**: wrapped its assertions in `if let`, so a nil result skipped them; now #require.
- **deflection**: wrapped its assertions in `if let`, so a nil result skipped them; now #require.
- **merge mesh nodes from shape**: wrapped its assertions in `if let`, so a nil result skipped them; now #require, and pins 24 / 12 (it asserted `> 0`).
- **compute links**: asserted `> 0`; now pins the 5 links two edge-sharing triangles have.
- **convert back to triangulation**: wrapped its assertions in `if let`, so a nil result skipped them; now #require.
- **create from mesh**: wrapped its assertions in `if let`, so a nil result skipped them; now #require, and pins 2 triangles (it asserted `> 0`).
- **node coordinates after result**: wrapped its assertions in `if let`, so a nil result skipped them; now #require.
- **triangleAdjacency**: nested its assertions in `if let` / returned early from a guard, so a nil result passed; now #require, and pins (0, 0, 2) where it asserted every index `>= 0`.
- **nodeTriangle**: nested its assertions in `if let` / returned early from a guard, so a nil result passed; now #require, and pins 1 where it asserted `>= 1`.
- **nodeTriangleCount**: nested its assertions in `if let` / returned early from a guard, so a nil result passed; now #require, and pins 1 where it asserted `>= 1`.
- **faceTriangulation**: nested its assertions in `if let` / returned early from a guard, so a nil result passed; now #require; `mag >= 0` and `n >= 1` could not fail, so node 1 and triangle 1 are pinned, and `defl > 0` (held only by 3e-16 rounding) is now `0 <= defl < 1e-9`.
- **triangulationUVNodes**: asserted nothing (`let _ = uv`), and only if HasUVNodes; now asserts HasUVNodes and pins UV node 1.
- **Triangulation create from arrays round-trips**: node and triangle checks sat in `if let`; now #require.
- **Create triangulation rep and bind it to a face**: nested its assertions in `if let` / returned early from a guard, so a nil result passed; now #require; adds the unbound precondition (nil before binding).
- **Create polygon3D rep and bind it to an edge**: nested its assertions in `if let` / returned early from a guard, so a nil result passed; now #require; adds the unbound precondition (nil before binding).
- **Mesh count properties are non-negative on a fresh graph**: asserted each count `>= 0` and active `<=` total, which no count can fail; now pins each to 0.
- **Mesh rep id queries return nil when no mesh is present**: nested its assertions in `if let` / returned early from a guard, so a nil result passed; now #require.
- **Mesh counts after incremental meshing**: `triangulationCount + polygon3DCount >= 0` could not fail; now pins 6 triangulations and 24 polygons on triangulation.
- **Mesh edge polygon3D rep id resolves the persistent tier (#1547)**: nested its assertions in `if let` / returned early from a guard, so a nil result passed; now #require.
- **Polygon2D copy preserves contents**: returned silently on a nil polygon and compared nodes inside `if let`; now #require.
- **PolygonOnTriangulation copy preserves nodes**: returned silently on nil; now #require, and compares against the input rather than the source polygon.
- **PolygonOnTriangulation setNodes mutates in place**: returned silently on nil; now #require.
- **PolygonOnTriangulation setParameters mutates in place**: returned silently on nil; now #require.
- **setParameters fails when polygon has no parameters**: returned silently on nil; now #require.
