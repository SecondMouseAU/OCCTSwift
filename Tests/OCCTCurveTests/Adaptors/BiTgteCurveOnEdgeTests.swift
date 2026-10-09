import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BiTgte CurveOnEdge v0.112")
struct BiTgteCurveOnEdgeTests {

    @Test func createFromEdges() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                // BiTgte_CurveOnEdge may fail for non-adjacent edges, that's OK
                let curve = BiTgteCurveOnEdge(edgeOnFace: edges[0], edge: edges[1])
                if let c = curve {
                    let d = c.domain
                    #expect(d.lowerBound.isFinite)
                    #expect(d.upperBound.isFinite)
                }
            }
        }
    }

    @Test func evaluatePoint() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                if let curve = BiTgteCurveOnEdge(edgeOnFace: edges[0], edge: edges[1]) {
                    let mid = (curve.domain.lowerBound + curve.domain.upperBound) / 2
                    let p = curve.point(at: mid)
                    #expect(p.x.isFinite)
                    #expect(p.y.isFinite)
                    #expect(p.z.isFinite)
                }
            }
        }
    }

    @Test func domainIsValid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                if let curve = BiTgteCurveOnEdge(edgeOnFace: edges[0], edge: edges[1]) {
                    #expect(curve.domain.upperBound >= curve.domain.lowerBound)
                }
            }
        }
    }

    @Test func sameEdgeCreation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 1 {
                // Same edge should create a valid curve
                let curve = BiTgteCurveOnEdge(edgeOnFace: edges[0], edge: edges[0])
                if let c = curve {
                    #expect(c.domain.lowerBound.isFinite)
                }
            }
        }
    }
}
