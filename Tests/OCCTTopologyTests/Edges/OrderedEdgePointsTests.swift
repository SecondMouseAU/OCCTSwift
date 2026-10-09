import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("orderedEdgePoints no truncation, Issue #35") struct OrderedEdgePointsTests {
    @Test("orderedEdgePoints returns all points without truncation")
    func noTruncation() {
        let wire = Wire.circle(radius: 100)
        if let wire {
            let count = wire.orderedEdgePointCount(at: 0)
            #expect(count > 0)
            let points = wire.orderedEdgePoints(at: 0)
            if let points {
                #expect(points.count == count)
            }
        }
    }

    @Test("orderedEdgePoints respects explicit maxPoints")
    func withMaxPoints() {
        let wire = Wire.circle(radius: 100)
        if let wire {
            let points = wire.orderedEdgePoints(at: 0, maxPoints: 5)
            if let points {
                #expect(points.count <= 5)
                #expect(points.count > 0)
            }
        }
    }

    @Test("orderedEdgePointCount returns count for each edge")
    func pointCountPerEdge() {
        let wire = Wire.rectangle(width: 10, height: 5)
        if let wire {
            let edgeCount = wire.orderedEdgeCount
            #expect(edgeCount == 4)
            for i in 0..<edgeCount {
                let count = wire.orderedEdgePointCount(at: i)
                #expect(count >= 2)
            }
        }
    }
}
