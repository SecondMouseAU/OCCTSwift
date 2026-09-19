import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntTools_EdgeFace Tests")
struct IntToolsEdgeFaceTests {
    @Test("Edge crossing face produces intersection")
    func edgeFaceIntersection() {
        // Use a box face and an edge going through it
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let edge = Shape.edgeFromPoints(SIMD3(5, 5, -1), SIMD3(5, 5, 11))
        if let b = box, let e = edge {
            let faces = b.subShapes(ofType: .face)
            if let face = faces.first {
                let parts = e.edgeFaceIntersection(with: face)
                #expect(parts != nil)
            }
        }
    }

    /// The intersection is actually found, not merely reported as done (#1631).
    ///
    /// `IntTools_EdgeFace::myRange` defaults to `(0, 0)` and `Perform()` passes it straight to
    /// `IntTools_BeanFaceIntersector::SetBeanParameters`, so without an explicit `SetRange` the
    /// search interval is empty: every face answers `IsDone() == true` with zero common parts.
    /// The test above cannot see that, because it asserts only that the array exists.
    ///
    /// `Shape.box` is centred on the origin, so this edge runs up the middle of the box and
    /// crosses exactly two of its six faces, the ones at z = -5 and z = +5.
    @Test("Exactly the two faces the edge crosses report a common part")
    func onlyCrossedFacesIntersect() {
        guard
            let box = Shape.box(width: 10, height: 10, depth: 10),
            let edge = Shape.edgeFromPoints(SIMD3(0, 0, -10), SIMD3(0, 0, 10))
        else {
            Issue.record("fixture construction failed")
            return
        }

        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)

        var hits: [(index: Int, point: SIMD3<Double>)] = []
        for (index, face) in faces.enumerated() {
            guard let parts = edge.edgeFaceIntersection(with: face) else {
                Issue.record("face \(index) reported failure rather than an empty result")
                return
            }
            for part in parts {
                hits.append((index, part.point))
            }
        }

        #expect(hits.count == 2, "the edge crosses two of the six faces")

        // Both hits sit on the axis the edge runs along, at the two z faces.
        for hit in hits {
            #expect(abs(hit.point.x) < 1e-6)
            #expect(abs(hit.point.y) < 1e-6)
            #expect(abs(abs(hit.point.z) - 5.0) < 1e-6, "hit at z = \(hit.point.z)")
        }
        #expect(Set(hits.map { $0.point.z > 0 }).count == 2, "one hit per end, not two at one end")
    }
}
