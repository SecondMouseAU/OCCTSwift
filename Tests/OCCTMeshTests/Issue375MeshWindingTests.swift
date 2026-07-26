import Testing
import Foundation
import simd
@testable import OCCTSwift

// #375: `Shape.mesh()` always emits consistently outward-facing triangles for a valid,
// closed solid, even after a mirror transform (determinant -1). Empirically confirmed to be
// intentional/correct OCCT behavior, not a bridge bug: `BRepBuilderAPI_Transform` compensates a
// negative-determinant transform by flipping each face's `TopoDS_Face::Orientation()` flag, so a
// valid solid's faces always classify consistently outward — the bridge's extraction (which
// reads that flag faithfully) has nothing left to get "wrong". See `Shape.mesh()`'s doc comment
// for the caller-controlled-winding workaround (`Mesh(vertices:normals:indices:)`).
@Suite("Issue #375 — mesh() winding reflects true topological orientation, not a naive transform read")
struct Issue375MeshWindingTests {

    /// Returns the fraction of `mesh`'s triangles whose (v1,v2,v3) winding faces away from
    /// `center` — i.e. cross(v2-v1, v3-v1) points away from the center, the expected convention
    /// for a convex solid's outward-facing mesh.
    private func outwardFraction(of mesh: Mesh, center: SIMD3<Float>) -> Double {
        let verts = mesh.vertices
        let idx = mesh.indices
        guard !idx.isEmpty else { return .nan }
        var outward = 0
        var total = 0
        var i = 0
        while i + 2 < idx.count {
            let p1 = verts[Int(idx[i])], p2 = verts[Int(idx[i + 1])], p3 = verts[Int(idx[i + 2])]
            let normal = simd_cross(p2 - p1, p3 - p1)
            if simd_dot(normal, p1 - center) > 0 { outward += 1 }
            total += 1
            i += 3
        }
        return Double(outward) / Double(total)
    }

    @Test("a mirrored valid solid still meshes 100% outward, matching the un-mirrored original")
    func mirroredSolidMeshesConsistentlyOutward() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let mirrored = try #require(box.mirrored(planeNormal: SIMD3(0, 0, 1), planeOrigin: .zero))

        let boxMesh = try #require(box.mesh(linearDeflection: 0.5, angularDeflection: 0.5))
        let mirroredMesh = try #require(mirrored.mesh(linearDeflection: 0.5, angularDeflection: 0.5))

        // Shape.box(width:height:depth:) is centered at the origin (both before and after a
        // mirror through a plane containing the origin), so `.zero` is the outward reference
        // center for both meshes.
        let boxOutward = outwardFraction(of: boxMesh, center: .zero)
        let mirroredOutward = outwardFraction(of: mirroredMesh, center: .zero)

        #expect(boxOutward == 1.0, "expected the un-mirrored box to mesh fully outward, got \(boxOutward)")
        #expect(mirroredOutward == 1.0,
                "expected the mirrored box to STILL mesh fully outward (OCCT compensates the flip), got \(mirroredOutward)")
    }

    @Test("mesh(parameters:) has the same outward-normalization behavior as the deflection overload")
    func meshParametersOverloadMatchesOutwardBehavior() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let mirrored = try #require(box.mirrored(planeNormal: SIMD3(1, 0, 0), planeOrigin: .zero))

        let mirroredMesh = try #require(mirrored.mesh(parameters: .default))
        let mirroredOutward = outwardFraction(of: mirroredMesh, center: .zero)

        #expect(mirroredOutward == 1.0, "expected mesh(parameters:) to also read fully outward, got \(mirroredOutward)")
    }
}
