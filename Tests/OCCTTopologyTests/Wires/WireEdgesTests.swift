import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue Fix Tests

@Suite("Wire.edges(), Issue #44") struct WireEdgesTests {
    @Test("Wire.edges returns edges for rectangle")
    func rectangleEdges() {
        let wire = Wire.rectangle(width: 10, height: 5)
        if let wire {
            let edges = wire.edges()
            #expect(edges.count == 4)
            for edge in edges {
                #expect(edge.length > 0)
            }
        }
    }

    @Test("Wire.edges returns edges for circle")
    func circleEdges() {
        let wire = Wire.circle(radius: 5)
        if let wire {
            let edges = wire.edges()
            #expect(edges.count >= 1)
        }
    }
}
