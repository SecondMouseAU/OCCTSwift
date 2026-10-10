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

        guard let edge = circularEdge, let bspline = edge.approximatedCurve() else {
            Issue.record("no approximation of the circular edge")
            return
        }
        // Approx_Curve3d(1e-3, C2, 100, 8) on the cylinder's r = 5 cap circle: every sample
        // within the requested 1e-3 of radius 5 (Scripts/repro/766-curve-queries-transform-approx/).
        let d = bspline.domain
        for i in 0...16 {
            let p = bspline.point(at: d.lowerBound + (d.upperBound - d.lowerBound) * Double(i) / 16)
            #expect(abs(simd_length(SIMD2(p.x, p.y)) - 5) < 1e-3)
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
                // Approx_Curve3d's own answer: degree 7, 13 poles, MaxError 3.38e-4.
                #expect(abs(info.maxError - 0.00033800541390782121) < 1e-12)
                #expect(info.degree == 7)
                #expect(info.poleCount == 13)
            }
        }
    }

    @Test("Approximate straight edge")
    func approximateLine() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edge = box.edge(at: 0)
        #expect(edge != nil)

        guard let edge, let bspline = edge.approximatedCurve() else {
            Issue.record("no approximation of box edge 0")
            return
        }
        // Box edge 0 of the centred 10 box runs (-5,-5,-5) -> (-5,-5,5).
        #expect(simd_distance(bspline.startPoint, SIMD3(-5, -5, -5)) < 1e-9)
        #expect(simd_distance(bspline.endPoint, SIMD3(-5, -5, 5)) < 1e-9)
    }
}
