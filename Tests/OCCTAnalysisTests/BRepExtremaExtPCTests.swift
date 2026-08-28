import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema_ExtPC Tests")
struct BRepExtremaExtPCTests {
    /// Every edge answers. This used to loop "until we find one that gives a valid extremum", a
    /// workaround for how often a point with no perpendicular foot came back nil, and asserted
    /// `solutionCount > 0`, which the guard it was testing made unfalsifiable. See #580.
    @Test("Point to edge distance on box")
    func pointToEdge() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edgeCount = box.edges().count
        #expect(edgeCount == 12)

        for i in 0..<edgeCount {
            let result = try #require(box.pointEdgeExtrema(point: SIMD3(5, 5, 15), edgeIndex: i))
            // Every edge of the box is a bounded segment, so no answer can exceed the box's
            // diagonal plus the probe's own offset from it.
            #expect(result.distance > 0)
            #expect(result.distance < 30)
        }

        // The box is centred on the origin, so (5, 5, 15) is the corner (5, 5, 5) plus 10 in z: the
        // nearest edge point is that corner itself.
        let nearest = (0..<edgeCount).compactMap {
            box.pointEdgeExtrema(point: SIMD3(5, 5, 15), edgeIndex: $0)?.distance
        }.min()
        #expect(abs(try #require(nearest) - 10) < 1e-9)
    }

    @Test("Point to wire edge, known distance")
    func pointToWireEdge() throws {
        // Use a wire from (0,0,0) to (10,0,0), single edge
        let wire = Wire.polygon3D([SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0)], closed: false)!
        let shape = Shape.fromWire(wire)!
        // Point at (5, 3, 0), distance should be 3.0
        if let result = shape.pointEdgeExtrema(point: SIMD3(5.0, 3.0, 0.0), edgeIndex: 0) {
            #expect(abs(result.distance - 3.0) < 0.1)
            #expect(abs(result.pointOnEdge.x - 5.0) < 0.5)
        }
    }
}
