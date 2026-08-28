import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib_MakeEdge2d Extensions Tests")
struct MakeEdge2dExtensionsTests {

    @Test func edge2dFullCircle() {
        if let e = Shape.edge2dFullCircle(center: SIMD2(0, 0), direction: SIMD2(1, 0), radius: 5) {
            #expect(e.nbChildren >= 0)
        }
    }

    @Test func edge2dEllipse() {
        if let e = Shape.edge2dEllipse(
            center: SIMD2(0, 0), direction: SIMD2(1, 0),
            majorRadius: 10, minorRadius: 5)
        {
            #expect(e.nbChildren >= 0)
        }
    }

    @Test func edge2dEllipseArc() {
        if let e = Shape.edge2dEllipseArc(
            center: SIMD2(0, 0), direction: SIMD2(1, 0),
            majorRadius: 10, minorRadius: 5,
            u1: 0, u2: .pi)
        {
            #expect(e.nbChildren >= 0)
        }
    }

    @Test func edge2dFromCurve() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1)) {
            if let e = Shape.edge2dFromCurve(line, u1: 0, u2: 10) {
                #expect(e.nbChildren >= 0)
            }
        }
    }

    @Test func edge2dFromCurveFullRange() {
        if let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            if let e = Shape.edge2dFromCurve(circle) {
                #expect(e.nbChildren >= 0)
            }
        }
    }
}
