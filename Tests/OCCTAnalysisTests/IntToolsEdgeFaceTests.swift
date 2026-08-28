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
}
