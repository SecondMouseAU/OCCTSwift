import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Wire Fixing Tests")
struct WireFixingTests {

    @Test("Fix healthy wire")
    func fixHealthyWire() throws {
        let wire = try #require(Wire.rectangle(width: 10, height: 10))
        // A healthy rectangle comes back as the same closed 10-square: four edges, length 40.
        let fixed = try #require(wire.fixed(tolerance: 0.001))
        #expect(fixed.edges().count == 4)
        #expect(abs(try #require(fixed.length) - 40) < 1e-9)
        #expect(try #require(fixed.curveInfo).isClosed)

        // Control: a pentagon whose top side overshoots the corner by 1e-4 and comes back has
        // five edges and length 40.0002, and the fix removes the overshoot: four edges,
        // length 40. (The repair does not depend on the tolerance argument: measured the same
        // from 0 to 2.0 and for overshoots from 1e-4 to 1, so this checks that the fix runs and
        // does not pin the tolerance.)
        let pentagon = try #require(
            Wire.polygon3D(
                [
                    SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(10.0001, 10, 0),
                    SIMD3(0, 10, 0),
                ], closed: true))
        #expect(pentagon.edges().count == 5)
        #expect(abs(try #require(pentagon.length) - 40.0002) < 1e-9)
        let healed = try #require(pentagon.fixed(tolerance: 0.001))
        #expect(healed.edges().count == 4)
        #expect(abs(try #require(healed.length) - 40) < 1e-9)
    }

    @Test("Fix circle wire")
    func fixCircleWire() throws {
        let circle = try #require(Wire.circle(radius: 5))
        // The one circular edge survives untouched: length 10 pi, still a circle, still closed.
        let fixed = try #require(circle.fixed(tolerance: 0.001))
        let edges = fixed.edges()
        #expect(edges.count == 1)
        if let edge = edges.first {
            #expect(edge.isCircle)
            #expect(abs(edge.length - 10 * .pi) < 1e-9)
        }
        #expect(try #require(fixed.curveInfo).isClosed)
    }
}
