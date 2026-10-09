import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeConstruct Curve Tests")
struct ShapeConstructCurveTests {
    @Test("convert 3D line segment to BSpline")
    func convert3DLine() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let bsp = line.convertSegmentToBSpline(first: 0, last: 10)
            #expect(bsp != nil)
        }
    }

    @Test("convert 3D circle segment to BSpline")
    func convert3DCircle() {
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            let bsp = circle.convertSegmentToBSpline(first: 0, last: Double.pi, precision: 1e-3)
            #expect(bsp != nil)
        }
    }

    @Test("convert 2D line to BSpline")
    func convert2DLine() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            let bsp = line.convertSegmentToBSpline(first: 0, last: 5)
            #expect(bsp != nil)
        }
    }

    @Test("adjust 3D curve endpoints")
    func adjust3D() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let ok = line.adjustEndpoints(start: SIMD3(0, 0, 0), end: SIMD3(10, 0, 0))
            #expect(ok)
        }
    }
}
