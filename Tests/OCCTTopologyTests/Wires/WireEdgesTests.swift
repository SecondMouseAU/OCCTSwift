import Foundation
import OCCTBridge
import Testing

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
    func circleEdges() throws {
        let wire = try #require(Wire.circle(radius: 5))
        // One closed circular edge of length 10 pi.
        let edges = wire.edges()
        #expect(edges.count == 1)
        for edge in edges {
            #expect(edge.isCircle)
            #expect(edge.isClosed3D)
            #expect(abs(edge.length - 10 * .pi) < 1e-9)
        }

        // Control: a rectangle's four edges are straight, so none of them is a circle.
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        let rectEdges = rect.edges()
        #expect(rectEdges.count == 4)
        for edge in rectEdges {
            #expect(!edge.isCircle)
            #expect(edge.isLine)
        }
    }
}
