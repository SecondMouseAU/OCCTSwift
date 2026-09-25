import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib ToolTriangulatedShape")
struct BRepLibToolTriangulatedShapeTests {
    /// BRepMesh leaves a box's triangulations without normals (measured: 6 faces, 4 nodes and 2
    /// triangles each, none with normals). `BRepLib_ToolTriangulatedShape::ComputeNormals` gives
    /// every node the normal of its face's surface, so afterwards each face has 4 normals, each
    /// perpendicular to the face's plane. The sign follows the surface, not the face's
    /// orientation (two opposite faces of the box carry the same normal), so the plane is what is
    /// asserted, not the sign. A `gp_Dir` is unit by construction, so unit length is no check here.
    ///
    /// Before this asserted only `computeNormals() == true`, which a call that computed nothing
    /// also returns (#766); it also returned silently when the box was nil.
    @Test("Compute normals on meshed shape")
    func computeNormals() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = try #require(box.mesh(linearDeflection: 0.1))
        let faces = box.subShapes(ofType: .face)
        try #require(faces.count == 6)
        for face in faces {
            #expect(!face.triangulationHasNormals, "meshing alone leaves no normals")
        }

        #expect(box.computeNormals() == true)

        for (i, face) in faces.enumerated() {
            #expect(face.triangulationHasNormals, "face \(i) has normals")
            let nodeCount = face.triangulationNodeCount
            #expect(nodeCount == 4, "face \(i) has \(nodeCount) nodes")
            let (a, b, c) = face.triangulationTriangle(at: 1)
            let origin = face.triangulationNode(at: a)
            let plane = simd_normalize(
                simd_cross(face.triangulationNode(at: b) - origin, face.triangulationNode(at: c) - origin))
            for k in 1...max(nodeCount, 1) {
                let n = face.triangulationNormal(at: k)
                #expect(
                    abs(abs(simd_dot(n, plane)) - 1) < 1e-12,
                    "face \(i) node \(k): normal \(n) is not perpendicular to the face plane \(plane)")
            }
        }
    }
}
