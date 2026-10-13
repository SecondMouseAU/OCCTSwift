import Foundation
import Testing

@testable import OCCTSwift

/// #3110: `Shape.fromMesh` passed triangle indices to OCCT unchecked.
///
/// Measured on the released kernel with one index triple per process (`Scripts/repro/3110/`), three
/// nodes, valid range 1...3: `(0, 1, 2)` and `(1, 2, 4)` built an empty shape that reported valid,
/// `(-1, 2, 3)` raised `NCollection_IndexedDataMap::FindFromKey`, `(1, 2, Int32.max)` died with
/// SIGSEGV and `(Int32.min, 2, 3)` with SIGBUS. Each refusal is the bridge returning nil before
/// OCCT is called. A crash here kills the test process, which is how the prove-the-test-fails run
/// reports the unguarded build.
@Suite("Shape.fromMesh triangle index range (#3110)")
struct Issue3110FromMeshIndexRangeTests {

    private let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)]

    // One test walking a list: the cases are plain Int32 triples, but a crash in any one ends the
    // process, so a single walk reports the first failing triple by its position in the output.
    @Test("fromMesh refuses an index below 1 or above the node count")
    func refusesOutOfRangeIndices() {
        let bad: [(Int32, Int32, Int32)] = [
            (0, 1, 2), (1, 2, 4), (4, 4, 4), (-1, 2, 3), (1, -1, 3), (1, 2, -1),
            (1, 2, Int32.max), (Int32.max, 2, 3), (Int32.min, 2, 3), (1, Int32.min, 3),
        ]
        for tri in bad {
            #expect(Shape.fromMesh(points: points, triangles: [tri]) == nil, "\(tri)")
        }
    }

    @Test("fromMesh refuses a bad index in a later triangle")
    func refusesBadIndexInLaterTriangle() {
        let pts = points + [SIMD3(1, 1, 0)]
        #expect(Shape.fromMesh(points: pts, triangles: [(1, 2, 3), (2, 4, 3), (2, 3, 5)]) == nil)
    }

    @Test("fromMesh still builds with indices at both ends of the valid range")
    func acceptsBoundaryIndices() throws {
        let pts = points + [SIMD3(1, 1, 0)]
        let shape = try #require(Shape.fromMesh(points: pts, triangles: [(1, 2, 3), (2, 4, 3)]))
        #expect(shape.isValid)
    }
}
