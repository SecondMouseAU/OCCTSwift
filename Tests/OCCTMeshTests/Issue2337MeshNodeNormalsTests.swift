import Testing

@testable import OCCTSwift

/// #2337: `Mesh.normals` used to be `(0, 0, 1)` at every vertex of every meshed shape.
///
/// `BRepMesh_IncrementalMesh` never stores node normals, so `Poly_Triangulation::HasNormals()` is
/// false for every face it meshes, and the bridge's `else` branch pushed a `(0, 0, 1)` placeholder
/// under the comment "will be computed later if needed". Nothing computed it later. Measured before
/// the fix: `Shape.sphere(radius: 5)!.mesh(linearDeflection: 0.5)!.normals` had 168 entries and
/// **one** distinct value.
///
/// The predecessor test ("Mesh data access" in `OCCTMeshTests`) compared `normals.count` to
/// `vertices.count`, and both are sized from `vertexCount`, so it could not see this. Every test
/// here therefore asserts a *direction*, not a count.
///
/// The fix copies OCCT's own consumers: `StdPrs_ShadedShape.cxx:186` calls
/// `StdPrs_ToolTriangulatedShape::ComputeNormals(aFace, aT)` immediately before reading
/// `aT->Normal()`, and `:199-208` reverses for a REVERSED face xor a mirroring location before
/// carrying the location's transformation.
@Suite("Issue 2337: meshed node normals are measured, not a placeholder")
struct Issue2337MeshNodeNormalsTests {

    /// The placeholder value, kept as a named constant so the defect signature is greppable.
    static let placeholder = SIMD3<Float>(0, 0, 1)

    private static func length(_ v: SIMD3<Float>) -> Double {
        (Double(v.x) * Double(v.x) + Double(v.y) * Double(v.y) + Double(v.z) * Double(v.z))
            .squareRoot()
    }

    private static func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Double {
        Double(a.x) * Double(b.x) + Double(a.y) * Double(b.y) + Double(a.z) * Double(b.z)
    }

    @Test("A sphere's node normals are radial and unit length, not one repeated value")
    func sphereNormalsAreRadial() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let mesh = try #require(sphere.mesh(linearDeflection: 0.5))

        let vertices = mesh.vertices
        let normals = mesh.normals
        #expect(vertices.count == normals.count)

        // Fixture guard: prove this is still a radius-5 sphere centred on the origin and a
        // non-trivial tessellation of one, before reading any normal off it. A fixture that had
        // stopped meaning its name would satisfy every assertion below vacuously.
        try #require(mesh.triangleCount > 100)
        for p in vertices {
            #expect(abs(Self.length(p) - 5.0) < 0.5, "vertex \(p) is not on the radius-5 sphere")
        }

        // The defect signature: one distinct normal for the whole mesh.
        let distinct = Set(normals.map { "\($0.x),\($0.y),\($0.z)" })
        #expect(
            distinct.count > 100, "only \(distinct.count) distinct normals over \(normals.count)")
        #expect(
            !normals.allSatisfy { $0 == Self.placeholder },
            "every normal is still the (0, 0, 1) placeholder")

        // On a sphere centred at the origin the outward normal at a node IS that node's direction,
        // so this is a measurement the mesher's own node positions can be checked against.
        var worstRadialDot = 1.0
        var worstLengthError = 0.0
        for i in 0..<vertices.count {
            let r = Self.length(vertices[i])
            let len = Self.length(normals[i])
            worstLengthError = max(worstLengthError, abs(len - 1.0))
            guard r > 1e-9, len > 1e-9 else { continue }
            worstRadialDot = min(worstRadialDot, Self.dot(vertices[i], normals[i]) / (r * len))
        }
        #expect(worstLengthError < 1e-5, "worst unit-length error \(worstLengthError)")
        #expect(worstRadialDot > 0.999, "worst radial agreement \(worstRadialDot)")
    }

    @Test("A box's node normals are the six outward face normals")
    func boxNormalsAreTheSixOutwardFaceNormals() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let mesh = try #require(box.mesh(linearDeflection: 0.1))

        let vertices = mesh.vertices
        let normals = mesh.normals

        // Fixture guard: a centred 10-cube meshes to 6 faces x 4 corners and 6 x 2 triangles. If
        // this is not that shape, the outwardness test below means nothing.
        try #require(vertices.count == 24)
        try #require(mesh.triangleCount == 12)
        for p in vertices {
            #expect(abs(abs(Double(p.x)) - 5.0) < 1e-6)
            #expect(abs(abs(Double(p.y)) - 5.0) < 1e-6)
            #expect(abs(abs(Double(p.z)) - 5.0) < 1e-6)
        }

        // Six planar faces, six distinct normals. The placeholder gave one.
        let distinct = Set(
            normals.map { "\(Int($0.x.rounded())),\(Int($0.y.rounded())),\(Int($0.z.rounded()))" })
        #expect(distinct.count == 6, "expected the six axis directions, got \(distinct.sorted())")
        #expect(
            distinct == ["-1,0,0", "0,-1,0", "0,0,-1", "0,0,1", "0,1,0", "1,0,0"],
            "\(distinct.sorted())")

        // Outward, for a box centred on the origin: the normal at a corner points away from the
        // centre, so its dot with the position is the half-extent, 5, on every one of the 24.
        for i in 0..<vertices.count {
            #expect(
                abs(Self.dot(vertices[i], normals[i]) - 5.0) < 1e-5,
                "normal \(normals[i]) at \(vertices[i]) does not point out of the box")
        }
    }

    @Test("Node normals agree with the independently computed per-triangle normals")
    func normalsAgreeWithTriangleNormals() throws {
        // Second construction: `trianglesWithFaces()` derives its per-triangle normal from the
        // cross product of the three node positions, a different route from the node normals
        // (which come from the surface via GeomLib::NormEstim inside ComputeNormals). On a box
        // every face is planar, so the two must agree exactly, and disagreement in sign would mean
        // the orientation handling had drifted apart between the two.
        let box = try #require(Shape.box(width: 10, height: 6, depth: 4))
        let mesh = try #require(box.mesh(linearDeflection: 0.1))
        let triangles = mesh.trianglesWithFaces()
        try #require(triangles.count == 12)

        let normals = mesh.normals
        for tri in triangles {
            for index in [tri.v1, tri.v2, tri.v3] {
                let nodeNormal = normals[Int(index)]
                #expect(
                    Self.dot(nodeNormal, tri.normal) > 0.999,
                    "node normal \(nodeNormal) disagrees with triangle normal \(tri.normal)")
            }
        }
    }

    @Test("A mirroring location flips the node normals, as OCCT's shaded display does")
    func mirroringLocationFlipsTheNodeNormals() throws {
        // Isolates the one branch copied from StdPrs_ShadedShape.cxx:200, `REVERSED ^ isMirrored`.
        //
        // It has to be a mirroring *location*. `Shape.mirrored(planeNormal:)` goes through
        // BRepBuilderAPI_Transform with copying on, which rebuilds the geometry and flips the face
        // orientations, leaving the location identity: measured, that construction passes with the
        // `isMirrored` term removed, so it exercises the orientation path only.
        // `located(matrix:)` sets a TopLoc_Location straight onto the shape
        // (`TopoDS_Shape::Located`), which is the case StdPrs's determinant test exists for.
        //
        // The measured answer is that the normals point *inward*, and that is correct rather than a
        // defect: `Located` does not reverse the face orientations, so a mirroring location leaves
        // the solid inside out, and OCCT's own shaded presentation shades it that way. The
        // expectation here is therefore the negation of `boxNormalsAreTheSixOutwardFaceNormals`,
        // -5 rather than +5 at every corner of a centred 10-cube.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // 4x3 row-major: mirror in x, no translation. Determinant -1.
        let mirrorInX: [Double] = [
            -1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
        ]
        let mirrored = try #require(box.located(matrix: mirrorInX))
        let mesh = try #require(mirrored.mesh(linearDeflection: 0.1))

        let vertices = mesh.vertices
        let normals = mesh.normals
        try #require(vertices.count == 24)

        for i in 0..<vertices.count {
            #expect(
                abs(Self.dot(vertices[i], normals[i]) + 5.0) < 1e-5,
                "normal \(normals[i]) at \(vertices[i]) does not carry the mirror's sense")
        }
    }

    @Test("A rotating location is carried into the node normals")
    func rotatingLocationIsCarriedIntoTheNodeNormals() throws {
        // Isolates the other half of StdPrs_ShadedShape.cxx:204-208, the `aNorm.Transform(aTrsf)`.
        // ComputeNormals works on the face with its location stripped
        // (`BRepLib_ToolTriangulatedShape.cxx:35`), so the stored normal is in the triangulation's
        // own frame and has to be carried into world coordinates alongside the node. A 90 degree
        // rotation about z has determinant +1, so the mirror branch is not involved here.
        let box = try #require(Shape.box(width: 10, height: 6, depth: 4))
        // 4x3 row-major: rotate +90 degrees about z, no translation.
        let rotateZ90: [Double] = [
            0, -1, 0, 0,
            1, 0, 0, 0,
            0, 0, 1, 0,
        ]
        let rotated = try #require(box.located(matrix: rotateZ90))
        let mesh = try #require(rotated.mesh(linearDeflection: 0.1))

        let vertices = mesh.vertices
        let normals = mesh.normals
        try #require(vertices.count == 24)

        // Outward on a box centred on the origin, whatever the rotation: the dot of a corner with
        // its own face normal is that face's half-extent, one of 5, 3 or 2.
        for i in 0..<vertices.count {
            let d = Self.dot(vertices[i], normals[i])
            #expect(
                [5.0, 3.0, 2.0].contains(where: { abs(d - $0) < 1e-5 }),
                "normal \(normals[i]) at \(vertices[i]) gives \(d), not a half-extent")
        }
    }

    @Test("A geometry-copying mirror also keeps the normals outward")
    func geometryMirroredBoxNormalsStillPointOutward() throws {
        // The other mirror, the one that rebuilds the geometry and flips the face orientations
        // rather than setting a mirroring location. It is covered by the orientation branch alone,
        // not by the determinant test, and it is here because it is the mirror a caller reaches for.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let mirrored = try #require(box.mirrored(planeNormal: SIMD3(1, 0, 0)))
        let mesh = try #require(mirrored.mesh(linearDeflection: 0.1))

        let vertices = mesh.vertices
        let normals = mesh.normals
        try #require(vertices.count == 24)

        for i in 0..<vertices.count {
            #expect(
                Self.dot(vertices[i], normals[i]) > 0,
                "mirrored box normal \(normals[i]) at \(vertices[i]) points inward")
        }
    }

    @Test("mesh(parameters:) computes normals too, not just mesh(linearDeflection:)")
    func parameterisedMeshNormalsAreAlsoMeasured() throws {
        // The placeholder lived in both public meshing entry points, written out twice. They now
        // share one helper; this test is what notices if they are ever split again.
        let sphere = try #require(Shape.sphere(radius: 5))
        var params = MeshParameters.default
        params.deflection = 0.5
        params.angle = 0.5
        let mesh = try #require(sphere.mesh(parameters: params))

        let vertices = mesh.vertices
        let normals = mesh.normals
        try #require(mesh.triangleCount > 100)
        #expect(!normals.allSatisfy { $0 == Self.placeholder })

        var worstRadialDot = 1.0
        for i in 0..<vertices.count {
            let r = Self.length(vertices[i])
            let len = Self.length(normals[i])
            guard r > 1e-9, len > 1e-9 else { continue }
            worstRadialDot = min(worstRadialDot, Self.dot(vertices[i], normals[i]) / (r * len))
        }
        #expect(worstRadialDot > 0.999, "worst radial agreement \(worstRadialDot)")
    }
}
