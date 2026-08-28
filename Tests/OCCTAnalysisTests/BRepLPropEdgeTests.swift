import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLProp Edge v0.111")
struct BRepLPropEdgeTests {
    @Test func edgeValue() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                if let p = edges[0].edgeLPropValue(at: 0.5) {
                    // Point should be somewhere on the box
                    let dist = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
                    #expect(dist > 0.0)
                }
            }
        }
    }

    @Test func edgeTangent() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            for edge in edges {
                if let tan = edge.edgeTangent(at: 0.5) {
                    let len = sqrt(tan.x * tan.x + tan.y * tan.y + tan.z * tan.z)
                    // Tangent should be a unit direction
                    #expect(abs(len - 1.0) < 1e-4)
                    break
                }
            }
        }
    }

    @Test func edgeCurvature() {
        // Edges of a box are straight lines, curvature should be 0
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let k = edges[0].edgeCurvatureLP(at: 0.5)
                if let k {
                    #expect(abs(k) < 1e-4)
                } else {
                    Issue.record("a box edge has curvature 0")
                }
            }
        }
    }

    @Test func edgeD1() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                if let d1 = edges[0].edgeLPropD1(at: 0.5) {
                    let len = sqrt(d1.x * d1.x + d1.y * d1.y + d1.z * d1.z)
                    #expect(len > 0.0)
                }
            }
        }
    }
}
