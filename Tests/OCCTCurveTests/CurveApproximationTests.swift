import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve Approximation Tests")
struct CurveApproximationTests {
    @Test("Approximate circle edge to BSpline")
    func approximateCircle() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.edges()
        // Find a circular edge
        var circularEdge: Edge?
        for edge in edges {
            if edge.isCircle {
                circularEdge = edge
                break
            }
        }
        #expect(circularEdge != nil)

        if let edge = circularEdge {
            let bspline = edge.approximatedCurve()
            #expect(bspline != nil)
        }
    }

    @Test("Approximation info returns valid data")
    func approxInfo() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let edges = cyl.edges()
        var circularEdge: Edge?
        for edge in edges {
            if edge.isCircle {
                circularEdge = edge
                break
            }
        }
        #expect(circularEdge != nil)

        if let edge = circularEdge {
            let info = edge.curveApproximationInfo()
            #expect(info != nil)
            if let info {
                #expect(info.maxError < 0.01)
                #expect(info.degree >= 2)
                #expect(info.poleCount > 0)
            }
        }
    }

    @Test("Approximate straight edge")
    func approximateLine() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edge = box.edge(at: 0)
        #expect(edge != nil)

        if let edge {
            let bspline = edge.approximatedCurve()
            #expect(bspline != nil)
        }
    }
}
