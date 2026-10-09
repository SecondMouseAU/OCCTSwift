import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// `Shape.computeNormals()` wraps `BRepLib_ToolTriangulatedShape::ComputeNormals`, which opens
/// `if (theTris.IsNull() || theTris->HasNormals()) return;` and so is an idempotent *ensure*.
///
/// The version of this suite that stood until #2905 asserted `result == true` on a box meshed with
/// `Shape.mesh`, which could not fail: the bridge set its flag for every non-null triangulation,
/// and #2337 had already made `Shape.mesh` compute the normals itself, so there was never anything
/// for the call to do and it said so anyway. The fixture below is the one Swift-reachable path
/// that triangulates **without** normals, `CoherentTriangulation.createFromMesh`, which is what
/// lets the count mean something. Ground truth: `Scripts/repro/2905/`.
@Suite("BRepLib ToolTriangulatedShape")
struct BRepLibToolTriangulatedShapeTests {

    /// `CoherentTriangulation.createFromMesh` runs `BRepMesh_IncrementalMesh` on the shape and
    /// never calls `ComputeNormals`, so it leaves every face triangulated and normal-less.
    private func boxTriangulatedWithoutNormals() -> Shape? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        guard CoherentTriangulation.createFromMesh(box, deflection: 0.1) != nil else { return nil }
        return box
    }

    @Test("Compute normals on a triangulation that has none")
    func computeNormals() throws {
        let box = try #require(boxTriangulatedWithoutNormals())

        // The fixture's whole point: meshing alone leaves no normals. If this ever goes true, the
        // count below stops measuring anything, which is exactly how the old test went blind.
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        #expect(faces.allSatisfy { $0.triangulationNodeCount == 4 })
        #expect(faces.allSatisfy { !$0.triangulationHasNormals })

        // Six faces gain normals, and each is counted because HasNormals() flipped on it.
        #expect(box.computeNormals() == 6)
        #expect(faces.allSatisfy { $0.triangulationHasNormals })

        // Idempotent: a second call finds nothing to do and says so, rather than reporting the
        // same success as the first.
        #expect(box.computeNormals() == 0)
    }

    @Test("A shape meshed through Shape.mesh already has its normals, so the count is zero")
    func meshedShapeHasNothingLeftToCompute() throws {
        // #2337 made occtAppendFaceTriangulation call the same OCCT entry point, so every face
        // Shape.mesh walks comes back with normals already stored on the triangulation.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = try #require(box.mesh(linearDeflection: 0.1))

        #expect(box.subShapes(ofType: .face).allSatisfy { $0.triangulationHasNormals })
        #expect(box.computeNormals() == 0)
    }

    @Test("A shape with no triangulation at all reports zero, not a failure")
    func unmeshedShapeReportsZero() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.computeNormals() == 0)
    }

    @Test("Every computed node normal is perpendicular to its own planar face")
    func computedNormalsArePerpendicularToTheFace() throws {
        let box = try #require(boxTriangulatedWithoutNormals())
        #expect(box.computeNormals() == 6)

        // A box face is planar, so each of its four node normals must be the face's own normal up
        // to sign. Taking the absolute dot product against the first node's normal keeps the test
        // independent of which way ComputeNormals oriented the face.
        for face in box.subShapes(ofType: .face) {
            let count = face.triangulationNodeCount
            #expect(count == 4)
            guard count == 4 else { continue }
            let reference = face.triangulationNormal(at: 1)
            #expect(abs(simd_length(reference) - 1.0) < 1e-6)
            for index in Int32(1)...count {
                let normal = face.triangulationNormal(at: index)
                #expect(abs(abs(simd_dot(normal, reference)) - 1.0) < 1e-6)
                // A box's faces are axis aligned, so exactly one component carries the whole
                // normal. A normal taken from the triangle winding rather than the surface would
                // still be axis aligned here, but one taken from nothing at all, the (0, 0, 1)
                // placeholder this call used to leave behind, would not satisfy the dot product
                // above on four of the six faces.
                let components = [abs(normal.x), abs(normal.y), abs(normal.z)].sorted()
                #expect(abs(components[2] - 1.0) < 1e-6)
                #expect(components[1] < 1e-6)
            }
        }
    }
}
