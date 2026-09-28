import Testing

@testable import OCCTSwift

/// #2301: `Mesh.union(with:)`, `subtracting(_:)` and `intersection(with:)` are Booleans on the sewn
/// tessellated **surfaces**, not on solids, and this suite pins that contract with measurements
/// instead of the `!= nil` the three predecessor tests asserted.
///
/// Why it is a contract and not a kernel defect, established by following OCCT's own callers:
///
///   - OCCT has no mesh Boolean. These three methods wrap no OCCT entry point; they compose
///     `BRepBuilderAPI_Sewing`, `BRepAlgoAPI_Fuse`/`Cut`/`Common` and `BRepMesh_IncrementalMesh`.
///   - OCCT's own mesh-to-shape path, `StlAPI_Reader::Read` -> `BRepBuilderAPI_MakeShapeOnMesh`,
///     emits a `TopoDS_Compound` of planar faces (`BRepBuilderAPI_MakeShapeOnMesh.cxx:181-183`) and
///     stops. It does not sew, does not build a shell, and does not build a solid.
///   - `BRepBuilderAPI_MakeSolid` and `BRepLib_MakeSolid` have no production caller anywhere in
///     OCCT's `src` tree: the only reference outside their own definitions is `TNaming_Name.cxx:408`,
///     OCAF topological naming resolving an already-selected shell. DRAW's `sewing` command
///     (`BRepTest_SurfaceCommands.cxx:549`) returns `SewedShape()` and stops, exactly as our
///     `OCCTMeshToShapeWithTolerance` does.
///   - `BOPAlgo_BOP` takes the dimension of its arguments and documents that at
///     `BOPAlgo_BOP.cxx:145-150`. A Boolean over two shells is a defined, correct, two-dimensional
///     operation, so the kernel is answering the question the bridge asks.
///
/// `solidBooleanRouteDeliversTheVolumeOperation` is the other half: it runs the route the doc
/// comments now point callers at, and proves it gives the volume answers.
@Suite("Issue 2301: mesh Booleans are surface Booleans, and the documented solid route works")
struct Issue2301MeshBooleanContractTests {

    /// Signed volume enclosed by a closed triangle soup, by the divergence theorem. Independent of
    /// every OCCT measurement: it reads only `Mesh.vertices` and `Mesh.indices`.
    static func enclosedVolume(_ mesh: Mesh) -> Double {
        let v = mesh.vertices
        let idx = mesh.indices
        var volume = 0.0
        var i = 0
        while i + 2 < idx.count {
            let a = v[Int(idx[i])], b = v[Int(idx[i + 1])], c = v[Int(idx[i + 2])]
            let ax = Double(a.x), ay = Double(a.y), az = Double(a.z)
            let bx = Double(b.x), by = Double(b.y), bz = Double(b.z)
            let cx = Double(c.x), cy = Double(c.y), cz = Double(c.z)
            volume +=
                (ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)) / 6.0
            i += 3
        }
        return volume
    }

    @Test("Mesh.toShape yields a shell, which is why the Booleans are two-dimensional")
    func toShapeYieldsAShell() throws {
        // The premise the whole suite rests on. If this ever returns a solid, every expectation
        // below changes and they should all be re-measured rather than nudged.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let mesh = try #require(box.mesh(linearDeflection: 0.5))
        let shell = try #require(mesh.toShape())
        #expect(shell.shapeType == .shell, "toShape gave \(shell.shapeType)")
    }

    @Test("Union of two overlapping box meshes keeps both volumes")
    func unionKeepsBothVolumes() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(5, 0, 0)))

        let mesh1 = try #require(box1.mesh(linearDeflection: 0.5))
        let mesh2 = try #require(box2.mesh(linearDeflection: 0.5))

        // Fixture guard: two 10-cubes overlapping over half their width. Each meshes to 12
        // triangles enclosing 1000, so the solid union is 1500 and a pass-through that simply
        // handed `mesh1` back would read 12 triangles and 1000.
        try #require(mesh1.triangleCount == 12)
        try #require(mesh2.triangleCount == 12)
        #expect(abs(Self.enclosedVolume(mesh1) - 1000.0) < 1e-6)

        let union = try #require(mesh1.union(with: mesh2, deflection: 0.5))

        // Measured: the surface union of the two shells, which keeps the two interior walls the
        // solid union would have consumed, so the enclosed volume double-counts the overlap.
        #expect(union.triangleCount == 72, "got \(union.triangleCount)")
        let volume = Self.enclosedVolume(union)
        #expect(abs(volume - 2000.0) < 1e-3, "got \(volume)")
        // Stated the other way round, so a change to the solid operation fails here and forces the
        // doc comments to be revisited with it rather than quietly diverging from them.
        #expect(abs(volume - 1500.0) > 1.0, "this is now the solid union; update the contract docs")
    }

    @Test("Subtracting a cylinder mesh from a box mesh removes nothing")
    func subtractionRemovesNothing() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let cylinder = try #require(Shape.cylinder(radius: 3, height: 15))

        let boxMesh = try #require(box.mesh(linearDeflection: 0.5))
        let cylMesh = try #require(cylinder.mesh(linearDeflection: 0.5))
        try #require(boxMesh.triangleCount == 12)
        try #require(cylMesh.triangleCount > 12)

        let difference = try #require(boxMesh.subtracting(cylMesh, deflection: 0.5))

        // The cut splits the box's faces where the cylinder's surface crosses them, so the triangle
        // count rises from 12 to 120 while the enclosed volume stays at the whole box: nothing was
        // removed. Asserting both is what separates this from a pass-through returning `boxMesh`,
        // whose volume would also read 1000 but whose triangle count would read 12.
        #expect(difference.triangleCount == 120, "got \(difference.triangleCount)")
        let volume = Self.enclosedVolume(difference)
        #expect(abs(volume - 1000.0) < 1e-3, "got \(volume)")
        // The solid answer is 1000 - pi * 9 * 5 = 858.63.
        #expect(abs(volume - 858.63) > 1.0, "this now subtracts a volume; update the contract docs")
    }

    @Test("Intersecting a box mesh with a sphere mesh yields no triangles")
    func intersectionYieldsNoTriangles() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 7))

        let boxMesh = try #require(box.mesh(linearDeflection: 0.5))
        let sphereMesh = try #require(sphere.mesh(linearDeflection: 0.5))
        try #require(boxMesh.triangleCount == 12)
        try #require(sphereMesh.triangleCount > 100)

        let intersection = try #require(boxMesh.intersection(with: sphereMesh, deflection: 0.5))

        // Two surfaces meet along curves, so `BRepAlgoAPI_Common` on the two shells produces edges,
        // one-dimensional geometry with nothing to triangulate. An empty `Mesh` is not `nil`, which
        // is exactly why the predecessor test passed.
        #expect(intersection.triangleCount == 0, "got \(intersection.triangleCount)")
        #expect(intersection.vertexCount == 0)
    }

    @Test("The documented solid route gives the volume operations")
    func solidBooleanRouteDeliversTheVolumeOperation() throws {
        // This is the route the three doc comments now point at, run end to end. It is also the
        // second construction for the numbers above: the same sewn shells, promoted to solids with
        // `Shape.solid(from:)` (BRepBuilderAPI_MakeSolid) before the Boolean instead of after.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(5, 0, 0)))
        let cylinder = try #require(Shape.cylinder(radius: 3, height: 15))
        let sphere = try #require(Shape.sphere(radius: 7))

        let boxShell = try #require(box.mesh(linearDeflection: 0.5)?.toShape())
        let box2Shell = try #require(box2.mesh(linearDeflection: 0.5)?.toShape())
        let cylShell = try #require(cylinder.mesh(linearDeflection: 0.5)?.toShape())
        let sphereShell = try #require(sphere.mesh(linearDeflection: 0.5)?.toShape())

        let boxSolid = try #require(Shape.solid(from: boxShell))
        let box2Solid = try #require(Shape.solid(from: box2Shell))
        let cylSolid = try #require(Shape.solid(from: cylShell))
        let sphereSolid = try #require(Shape.solid(from: sphereShell))

        // Fixture guard: the promotion has to have produced a real volume, or the three Booleans
        // below would be surface Booleans again under a different name.
        let boxVolume = try #require(boxSolid.volume)
        #expect(abs(boxVolume - 1000.0) < 1e-6, "got \(boxVolume)")

        let union = try #require(boxSolid.union(box2Solid))
        let unionVolume = try #require(union.volume)
        #expect(abs(unionVolume - 1500.0) < 1e-6, "got \(unionVolume)")

        // The cylinder and sphere are tessellated before promotion, so the cut and common volumes
        // are the faceted approximations of 858.63 and 959.23, not those numbers. Deflection 0.5 on
        // r=3 and r=7 puts them within about 1.5%.
        let difference = try #require(boxSolid.subtracting(cylSolid))
        let differenceVolume = try #require(difference.volume)
        #expect(abs(differenceVolume - 860.0) < 5.0, "got \(differenceVolume)")

        let common = try #require(boxSolid.intersection(sphereSolid))
        let commonVolume = try #require(common.volume)
        #expect(abs(commonVolume - 948.0) < 5.0, "got \(commonVolume)")

        // And the result re-meshes, which is the last step of the documented route.
        let remeshed = try #require(common.mesh(linearDeflection: 0.5))
        #expect(remeshed.triangleCount > 0)
        #expect(abs(Self.enclosedVolume(remeshed) - commonVolume) < 1.0)
    }
}
