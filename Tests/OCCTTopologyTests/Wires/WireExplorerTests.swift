import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Wire Explorer")
struct WireExplorerTests {
    @Test("Rectangle has 4 ordered edges")
    func rectangleEdges() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        #expect(rect.orderedEdgeCount == 4)
    }

    @Test("Get edge points in order")
    func getEdgePoints() throws {
        // The 10 x 5 rectangle is walked corner to corner, each edge starting where the
        // previous one ended: (-5,-2.5) to (5,-2.5) to (5,2.5) to (-5,2.5) back to (-5,-2.5).
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        let corners: [SIMD3<Double>] = [
            SIMD3(-5, -2.5, 0), SIMD3(5, -2.5, 0), SIMD3(5, 2.5, 0), SIMD3(-5, 2.5, 0),
        ]
        #expect(rect.orderedEdgeCount == 4)
        for i in 0..<rect.orderedEdgeCount {
            let points = try #require(rect.orderedEdgePoints(at: i))
            // A straight edge is its two endpoints.
            #expect(points.count == 2)
            guard points.count == 2 else { continue }
            #expect(vectorDistance(points[0], corners[i]) < 1e-9)
            #expect(vectorDistance(points[1], corners[(i + 1) % 4]) < 1e-9)
        }
    }

    @Test("Out of range returns nil")
    func outOfRange() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        #expect(rect.orderedEdgePoints(at: 99) == nil)
        #expect(rect.orderedEdgePoints(at: -1) == nil)
    }

    @Test("Circle has 1 ordered edge")
    func circleEdge() throws {
        let circle = try #require(Wire.circle(radius: 5))
        #expect(circle.orderedEdgeCount == 1)
        // The one edge is sampled around the circle: it starts and ends at (5,0,0) and every
        // point is on the radius-5 circle in the z = 0 plane.
        let points = try #require(circle.orderedEdgePoints(at: 0))
        #expect(points.count > 8)
        if let first = points.first, let last = points.last {
            #expect(vectorDistance(first, SIMD3(5, 0, 0)) < 1e-9)
            #expect(vectorDistance(last, SIMD3(5, 0, 0)) < 1e-9)
        }
        for p in points {
            #expect(abs((p.x * p.x + p.y * p.y).squareRoot() - 5) < 1e-9)
            #expect(abs(p.z) < 1e-9)
        }
        // Control: there is no second edge.
        #expect(circle.orderedEdgePoints(at: 1) == nil)
    }
}
