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

**Covered so far**: 24 of 97 tests.
**Covered so far**: 40 of 97 tests.

## `Issue197MeshDeflectionTests.swift` (3 tests)
## Findings filed from this execution

Probe: `Scripts/repro/766-mesh-issue197/`.
- #2301: mesh booleans operate on sewn shells, not solids. Union encloses 2000 where the solid
  union is 1500, box minus cylinder removes nothing, box and sphere intersect to an empty mesh.
  The three tests assert the correct volumes under `withKnownIssue`.
- #2337: `Mesh.normals` is `(0, 0, 1)` at every vertex of a meshed shape; `BRepMesh` stores no
  normals and the bridge writes a placeholder.

| Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|------|-----------------|-----------|--------------------|-------|--------|
| binary STL: finer deflection yields a larger file (more triangles) | `OCCTShapeWriteSTLBinary` | R1: pass 1.0 instead of the caller's deflection to OCCTExportSTLWithMode | :42 `fineSize > coarseSize` | ✔ | MATCH |
| default deflection (0.1) still writes a valid STL **(rewritten)** | `OCCTShapeWriteSTLBinary` | R1: pass 1.0 instead of the caller's deflection to OCCTExportSTLWithMode | :60 `size == 84 + 50 * 976` | ✔ | MATCH |
| coherent triangulation builds at the requested deflection **(rewritten)** | `OCCTCoherentTriangulationCreateFromMesh` | R1: BRepMesh_IncrementalMesh(shape, 0.1), ignoring deflection | :73 `coarse.triangleCount == 516` | ✔ | MATCH |
## `Issue197MeshDeflectionTests.swift` (3 tests)

Rewritten because the original could not fail for the defect its title names:
Probe: `Scripts/repro/766-mesh-issue197/`.

- **default deflection (0.1) still writes a valid STL**: asserted `size > 84`, which any non-empty STL at any deflection passes; now pins 84 + 50 * 976.
- **coherent triangulation builds at the requested deflection**: asserted only `tri != nil`, which a builder ignoring deflection passes; now pins the triangle count at two deflections.
| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Issue #197, mesh deflection is a caller-tunable parameter | binary STL: finer deflection yields a larger file (more triangles) | `OCCTShapeWriteSTLBinary` | R1: pass 1.0 instead of the caller's deflection to OCCTExportSTLWithMode | :42 `fineSize > coarseSize` | ✔ | MATCH |
| Issue #197, mesh deflection is a caller-tunable parameter | default deflection (0.1) still writes a valid STL **(rewritten)** | `OCCTShapeWriteSTLBinary` | R1: pass 1.0 instead of the caller's deflection to OCCTExportSTLWithMode | :60 `size == 84 + 50 * 976` | ✔ | MATCH |
| Issue #197, mesh deflection is a caller-tunable parameter | coherent triangulation builds at the requested deflection **(rewritten)** | `OCCTCoherentTriangulationCreateFromMesh` | R1: BRepMesh_IncrementalMesh(shape, 0.1), ignoring deflection | :73 `coarse.triangleCount == 516` | ✔ | MATCH |

## `Issue211MeshParamTests.swift` (3 tests)
Rewritten because the original could not fail for the defect its title names:

Probe: `Scripts/repro/766-mesh-issue211/`.
- **default deflection (0.1) still writes a valid STL**: asserted `size > 84`, which any non-empty STL at any deflection passes; now pins 84 + 50 * 976.
- **coherent triangulation builds at the requested deflection**: asserted only `tri != nil`, which a builder ignoring deflection passes; now pins the triangle count at two deflections.

| Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|------|-----------------|-----------|--------------------|-------|--------|
| default is false | none (`MeshParameters.default`, Swift) | R1: MeshParameters.default.allowQualityDecrease = true (Mesh.swift) | :12 `MeshParameters.default.allowQualityDecrease == false` | ✔ | MATCH |
| meshing with the flag set produces a valid mesh | `OCCTShapeCreateMeshWithParams` | R2: return nullptr when params.allowQualityDecrease is set | :25 `Bool(false)` (the guard's else branch) | ✔ | MATCH |
| allows a coarser re-mesh to replace a finer one **(rewritten)** | `OCCTShapeCreateMeshWithParams` | R1: meshParams.AllowQualityDecrease = Standard_False, dropping the flag | :51 `coarseA.triangleCount == 306` | ✔ | MATCH |
## `Issue211MeshParamTests.swift` (3 tests)

Rewritten because the original could not fail for the defect its title names:
Probe: `Scripts/repro/766-mesh-issue211/`.

- **allows a coarser re-mesh to replace a finer one**: meshed two separate fresh spheres, so the flag played no part and dropping it left the test green; now re-meshes one shape, with a flag-off control.
| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Issue #211, allowQualityDecrease mesh parameter | default is false | none (`MeshParameters.default`, Swift) | R1: MeshParameters.default.allowQualityDecrease = true (Mesh.swift) | :12 `MeshParameters.default.allowQualityDecrease == false` | ✔ | MATCH |
| Issue #211, allowQualityDecrease mesh parameter | meshing with the flag set produces a valid mesh | `OCCTShapeCreateMeshWithParams` | R2: return nullptr when params.allowQualityDecrease is set | :25 `Bool(false)` (the guard's else branch) | ✔ | MATCH |
| Issue #211, allowQualityDecrease mesh parameter | allows a coarser re-mesh to replace a finer one **(rewritten)** | `OCCTShapeCreateMeshWithParams` | R1: meshParams.AllowQualityDecrease = Standard_False, dropping the flag | :51 `coarseA.triangleCount == 306` | ✔ | MATCH |

## `Issue375MeshWindingTests.swift` (2 tests)
Rewritten because the original could not fail for the defect its title names:

Probe: `Scripts/repro/766-mesh-issue375/`.
- **allows a coarser re-mesh to replace a finer one**: meshed two separate fresh spheres, so the flag played no part and dropping it left the test green; now re-meshes one shape, with a flag-off control.

| Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|------|-----------------|-----------|--------------------|-------|--------|
| a mirrored valid solid still meshes 100% outward, matching the un-mirrored original | `OCCTShapeCreateMesh` | R1: REVERSED faces no longer swap n2/n3 | :55 `boxOutward == 1.0`, :58 `mirroredOutward == 1.0` | ✔ | MATCH |
| mesh(parameters:) has the same outward-normalization behavior as the deflection overload | `OCCTShapeCreateMeshWithParams` | R1: REVERSED faces no longer swap n2/n3 | :73 `mirroredOutward == 1.0` | ✔ | MATCH |
## `Issue375MeshWindingTests.swift` (2 tests)

## `Issue1440Polygon3DParameterGuardTests.swift` (2 tests)
Probe: `Scripts/repro/766-mesh-issue375/`.

Probe: `Scripts/repro/766-mesh-issue1440/`.
| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Issue #375, mesh() winding reflects true topological orientation, not a naive transform read | a mirrored valid solid still meshes 100% outward, matching the un-mirrored original | `OCCTShapeCreateMesh` | R1: REVERSED faces no longer swap n2/n3 | :55 `boxOutward == 1.0`, :58 `mirroredOutward == 1.0` | ✔ | MATCH |
| Issue #375, mesh() winding reflects true topological orientation, not a naive transform read | mesh(parameters:) has the same outward-normalization behavior as the deflection overload | `OCCTShapeCreateMeshWithParams` | R1: REVERSED faces no longer swap n2/n3 | :73 `mirroredOutward == 1.0` | ✔ | MATCH |

| Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|------|-----------------|-----------|--------------------|-------|--------|
| a no-params polygon's parameter(at:) is safe, not a crash | `OCCTPolyPolygon3DParameter` | R3: HasParameters() guard removed | process killed, signal 11 (SIGSEGV) inside the test | ✔ | MATCH on HasParameters; the 0 fallback is bridge behaviour (the kernel call it guards segfaults) |
| a with-parameters polygon still returns its real stored values | `OCCTPolyPolygon3DParameter` | R1: read Parameters()(NbNodes() - index), reversed order | :54 `polygon.parameter(at: i) == expected` (i = 0 and i = 2) | ✔ | MATCH |
## `Issue1440Polygon3DParameterGuardTests.swift` (2 tests)

## `Issue1566MergeNodesOverflowGuardTests.swift` (5 tests)
Probe: `Scripts/repro/766-mesh-issue1440/`.

Probe: `Scripts/repro/766-mesh-issue1566/`.

| Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|------|-----------------|-----------|--------------------|-------|--------|
| generous buffers: succeeds, reports the true counts, and every count matches the write | `OCCTPolyMergeNodes` | R2: *outTriangleCount never written | :61 `triCount > 0` | ✔ | MATCH |
| vertex buffer too small: refuses (returns 0), does not touch outTriangleCount | `OCCTPolyMergeNodes` | R1b: verticesOverflow = false (the #1566 refusal removed) | process killed, signal 5, writing 24 nodes into a 1-node buffer | ✔ | MATCH: kernel NbNodes 24 > maxVertices 1, so the refusal is the correct outcome; the refusal itself has no kernel counterpart |
| index buffer too small: refuses (returns 0), does not touch outTriangleCount | `OCCTPolyMergeNodes` | R2: indicesOverflow = false (the #1566 refusal removed) | :123 `nVerts == 0` | ✔ | MATCH: kernel needs 36 indices > maxIndices 1, so the refusal is the correct outcome; the refusal itself has no kernel counterpart |
| a null outIndices is not gated on maxIndices, even when maxIndices is 0 | `OCCTPolyMergeNodes` | R4: indicesOverflow no longer gated on outIndices being non-null | :146 `nVerts > 0`, :147 `triCount > 0` | ✔ | MATCH |
| mergedMeshNodes still succeeds normally for an ordinary box (non-regression) | `OCCTPolyMergeNodes` | R2: *outTriangleCount never written | :157 `merged.triangleCount > 0` | ✔ | MATCH |

## `Issue613MeshIndexContractTests.swift` (9 tests)

Probe: `Scripts/repro/766-mesh-issue613/`.

| Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|------|-----------------|-----------|--------------------|-------|--------|
| the fixture really does share one face between two solids | `OCCTShapeGetFaceCount, OCCTShapeGetOrientedFaces` | R4: Shape.faceCount reads OCCTShapeGetFaceOccurrenceCount (the pre-#651 explorer count) | :80 `compound.faceCount == 11` | ✔ | MATCH |
| no triangle claims a face index faces() cannot address | `OCCTShapeCreateMesh` | R4: faceIndex stamped from an occurrence counter, not the map index | :111 `compound.face(at: i) != nil` | ✔ | MATCH |
| a triangle's faceIndex names the face that triangle lies on | `OCCTShapeCreateMesh` | R4: faceIndex stamped from an occurrence counter, not the map index | :135 `#require(compound.face(at:))`, :143 `abs(Self.dot(offset, normal)) < 1e-6` | ✔ | MATCH |
| both sides of the shared wall are stamped with the one index that names it | `OCCTShapeCreateMesh` | R4: faceIndex stamped from an occurrence counter, not the map index | :174 `wallIndices.count == 1` | ✔ | MATCH |
| every mesh triangle is wound outward for the solid that owns it (control) | `OCCTShapeCreateMesh` | R4: winding swapped for FORWARD faces instead of REVERSED (global inversion) | :223 `inward == 0` | ✔ | MATCH |
| a plain box still meshes entirely outward | `OCCTShapeCreateMesh` | R4: winding swapped for FORWARD faces instead of REVERSED (global inversion) | :250 `outward == 12`, :251 `inward == 0` | ✔ | MATCH |
| the parameterised mesh entry point holds the same index contract | `OCCTShapeCreateMeshWithParams` | R4: faceIndex stamped from an occurrence counter, not the map index | :267 `compound.face(at: i) != nil`, :286 `wallIndices.count == 1` | ✔ | MATCH |
| merged mesh nodes keep both sides of a shared wall, oppositely wound | `OCCTPolyMergeNodes` | R4: reversed flag passed to AddTriangulation forced false | :316 `minusX > 0`, :317 `plusX == minusX` | ✔ | MATCH |
| merged mesh nodes on a plain box are entirely outward | `OCCTPolyMergeNodes` | R4: reversed flag passed to AddTriangulation forced false | :341 `outward == 12`, :342 `inward == 0` | ✔ | MATCH |
| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Issue #1440: Polygon3D.parameter(at:) null-Handle guard | a no-params polygon's parameter(at:) is safe, not a crash | `OCCTPolyPolygon3DParameter` | R3: HasParameters() guard removed | process killed, signal 11 (SIGSEGV) inside the test | ✔ | MATCH on HasParameters; the 0 fallback is bridge behaviour (the kernel call it guards segfaults) |
| Issue #1440: Polygon3D.parameter(at:) null-Handle guard | a with-parameters polygon still returns its real stored values | `OCCTPolyPolygon3DParameter` | R1: read Parameters()(NbNodes() - index), reversed order | :54 `polygon.parameter(at: i) == expected` (i = 0 and i = 2) | ✔ | MATCH |
## `Issue1566MergeNodesOverflowGuardTests.swift` (5 tests)
| Suite | Test | Bridge function | Injection | Red (failing line) | Green | Parity |
|-------|------|-----------------|-----------|--------------------|-------|--------|
| Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow | generous buffers: succeeds, reports the true counts, and every count matches the write | `OCCTPolyMergeNodes` | R2: *outTriangleCount never written | :61 `triCount > 0` | ✔ | MATCH |
| Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow | vertex buffer too small: refuses (returns 0), does not touch outTriangleCount | `OCCTPolyMergeNodes` | R1b: verticesOverflow = false (the #1566 refusal removed) | process killed, signal 5, writing 24 nodes into a 1-node buffer | ✔ | MATCH: kernel NbNodes 24 > maxVertices 1, so the refusal is the correct outcome; the refusal itself has no kernel counterpart |
| Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow | index buffer too small: refuses (returns 0), does not touch outTriangleCount | `OCCTPolyMergeNodes` | R2: indicesOverflow = false (the #1566 refusal removed) | :123 `nVerts == 0` | ✔ | MATCH: kernel needs 36 indices > maxIndices 1, so the refusal is the correct outcome; the refusal itself has no kernel counterpart |
| Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow | a null outIndices is not gated on maxIndices, even when maxIndices is 0 | `OCCTPolyMergeNodes` | R4: indicesOverflow no longer gated on outIndices being non-null | :146 `nVerts > 0`, :147 `triCount > 0` | ✔ | MATCH |
| Issue #1566: OCCTPolyMergeNodes refuses rather than mis-reports on buffer overflow | mergedMeshNodes still succeeds normally for an ordinary box (non-regression) | `OCCTPolyMergeNodes` | R2: *outTriangleCount never written | :157 `merged.triangleCount > 0` | ✔ | MATCH |
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
## `OCCTMeshTests.swift` (16 tests)
Probe: `Scripts/repro/766-mesh-core-1/`.
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
Rewritten because the original could not fail for the defect its title names:
- **Mesh from shape**: read vertexCount and triangleCount and asserted nothing; now pins 24 / 12 and the enclosed volume 150.
- **Mesh data access**: its two length checks are true by construction (all arrays are sized from vertexCount / triangleCount); now checks every index addresses a vertex and every vertex lies on the sphere.
