import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("projectWire with Wire, Issue #47") struct ProjectWireWithWireTests {
    @Test("projectWire accepts Wire directly")
    func projectWireFromWire() throws {
        let wire = try #require(Wire.circle(radius: 5))
        let target = try #require(Shape.box(width: 20, height: 20, depth: 20))
        // A 5-radius circle in the z = 0 plane projected along z onto the 20-cube lands as
        // a circle of the same radius on each of the cube's top and bottom faces (z = +-10).
        let result = try #require(Shape.projectWire(wire, onto: target, direction: SIMD3(0, 0, 1)))
        let edges = result.edges()
        #expect(edges.count == 2)
        var heights: [Double] = []
        for edge in edges {
            #expect(edge.isCircle)
            #expect(abs(edge.length - 10 * .pi) < 1e-9)
            let b = try #require(edge.bounds)
            heights.append((b.min.z + b.max.z) / 2)
            #expect(abs(b.max.x - 5) < 1e-6)
        }
        heights.sort()
        if heights.count == 2 {
            #expect(abs(heights[0] + 10) < 1e-6)
            #expect(abs(heights[1] - 10) < 1e-6)
        }
    }

    @Test("projectWireConical accepts Wire directly")
    func projectWireConicalFromWire() throws {
        let wire = try #require(Wire.circle(radius: 3))
        let target = try #require(Shape.box(width: 20, height: 20, depth: 20))
        // Rays fan out from an eye at z = 50 through the circle in the z = 0 plane. They meet
        // the top face (z = 10) at radius 3 * (50 - 10) / 50 = 2.4 and the bottom face
        // (z = -10) at radius 3 * (50 + 10) / 50 = 3.6.
        let result = try #require(
            Shape.projectWireConical(wire, onto: target, eye: SIMD3(0, 0, 50)))
        let edges = result.edges()
        #expect(edges.count == 2)
        var byHeight: [(z: Double, length: Double)] = []
        for edge in edges {
            #expect(edge.isCircle)
            let b = try #require(edge.bounds)
            byHeight.append(((b.min.z + b.max.z) / 2, edge.length))
        }
        byHeight.sort { $0.z < $1.z }
        if byHeight.count == 2 {
            #expect(abs(byHeight[0].z + 10) < 1e-6)
            #expect(abs(byHeight[0].length - 2 * .pi * 3.6) < 1e-9)
            #expect(abs(byHeight[1].z - 10) < 1e-6)
            #expect(abs(byHeight[1].length - 2 * .pi * 2.4) < 1e-9)
        }
    }
}
