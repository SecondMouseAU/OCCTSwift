import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntTools_EdgeEdge Tests")
struct IntToolsEdgeEdgeTests {
    @Test("Intersecting edges produce vertex common part")
    func edgeEdgeVertex() {
        // Two edges crossing at origin: X-axis and Y-axis
        let e1 = Shape.edgeFromPoints(SIMD3(-1, 0, 0), SIMD3(1, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(0, -1, 0), SIMD3(0, 1, 0))
        if let edge1 = e1, let edge2 = e2 {
            let parts = edge1.edgeEdgeIntersection(with: edge2)
            #expect(parts != nil)
            if let p = parts {
                #expect(p.count >= 1)
                if let first = p.first {
                    #expect(first.type == .vertex)
                    #expect(abs(first.point.x) < 0.1)
                    #expect(abs(first.point.y) < 0.1)
                }
            }
        }
    }

    @Test("Overlapping collinear edges produce edge common part")
    func edgeEdgeOverlap() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(2, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(1, 0, 0), SIMD3(3, 0, 0))
        if let edge1 = e1, let edge2 = e2 {
            let parts = edge1.edgeEdgeIntersection(with: edge2)
            #expect(parts != nil)
            if let p = parts {
                #expect(p.count >= 1)
                if let first = p.first {
                    #expect(first.type == .edge)
                }
            }
        }
    }

    @Test("Non-intersecting edges return empty array")
    func edgeEdgeNoIntersection() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(1, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(0, 5, 0), SIMD3(1, 5, 0))
        if let edge1 = e1, let edge2 = e2 {
            let parts = edge1.edgeEdgeIntersection(with: edge2)
            #expect(parts != nil)
            if let p = parts {
                #expect(p.isEmpty)
            }
        }
    }
}
