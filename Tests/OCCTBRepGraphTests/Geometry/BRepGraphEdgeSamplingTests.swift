import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Edge Sampling")
struct BRepGraphEdgeSamplingTests {
    @Test func sampleBoxEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                // Find an edge with a curve
                var sampledEdge = -1
                for i in 0..<graph.edgeCount {
                    if graph.edgeHasCurve(i) {
                        sampledEdge = i
                        break
                    }
                }
                if sampledEdge >= 0 {
                    let points = graph.sampleEdgeCurve(edgeIndex: sampledEdge, count: 10)
                    #expect(points.count == 10)
                    // Points should be distinct (not all the same)
                    if points.count >= 2 {
                        let first = points[0]
                        let last = points[points.count - 1]
                        let dist =
                            ((first.x - last.x) * (first.x - last.x) + (first.y - last.y)
                            * (first.y - last.y) + (first.z - last.z) * (first.z - last.z))
                            .squareRoot()
                        #expect(dist > 0.001)
                    }
                }
            }
        }
    }

    @Test func sampleSinglePoint() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                for i in 0..<graph.edgeCount {
                    if graph.edgeHasCurve(i) {
                        let points = graph.sampleEdgeCurve(edgeIndex: i, count: 1)
                        #expect(points.count == 1)
                        break
                    }
                }
            }
        }
    }

    @Test func sampleEdgeWithoutCurve() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                // Test with invalid index
                let points = graph.sampleEdgeCurve(edgeIndex: 999, count: 10)
                #expect(points.isEmpty)
            }
        }
    }

    @Test func sampleZeroCount() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let points = graph.sampleEdgeCurve(edgeIndex: 0, count: 0)
                #expect(points.isEmpty)
            }
        }
    }

    @Test func sampleSphereEdge() {
        if let sphere = Shape.sphere(radius: 5) {
            if let graph = BRepGraph(shape: sphere) {
                for i in 0..<graph.edgeCount {
                    if graph.edgeHasCurve(i) {
                        let points = graph.sampleEdgeCurve(edgeIndex: i, count: 20)
                        #expect(points.count == 20)
                        // All points should be on the sphere surface (distance from origin ~= 5)
                        for p in points {
                            let r = (p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
                            #expect(abs(r - 5.0) < 0.1)
                        }
                        break
                    }
                }
            }
        }
    }
}
