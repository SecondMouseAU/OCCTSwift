import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D Conversion Tests")
struct Curve3DConversionTests {

    @Test("Circle to BSpline")
    func circleToBSpline() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let bsp = circle.toBSpline()
        #expect(bsp != nil)
        if let b = bsp {
            #expect((b.poleCount ?? 0) > 0)
            #expect(b.degree > 0)
        }
    }

    @Test("BSpline to Bezier segments")
    func bsplineToBeziers() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let beziers = circle.toBezierSegments()
        #expect(beziers != nil)
        if let segs = beziers {
            #expect(segs.count >= 2)
        }
    }

    @Test("Join two segments into BSpline")
    func joinCurves() {
        let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(5, 0, 0))!
        let seg2 = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(10, 5, 0))!
        let joined = Curve3D.join([seg1, seg2])
        #expect(joined != nil)
        if let j = joined {
            let start = j.startPoint
            let end = j.endPoint
            #expect(abs(start.x) < 0.1)
            #expect(abs(end.x - 10) < 0.1)
        }
    }

    @Test("Join returns nil rather than silently dropping a disconnected curve")
    func joinRejectsDisconnectedCurve() {
        // seg2 starts 4 units away from seg1's end, far past the default 1e-6 tolerance, so
        // GeomConvert_CompCurveToBSplineCurve::Add() must fail (no G0 continuity). The join
        // must fail too, not silently hand back seg1 alone with seg2 dropped (#1441).
        let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0))!
        let seg2 = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(6, 0, 0))!
        let joined = Curve3D.join([seg1, seg2])
        #expect(joined == nil)
    }

    @Test("Approximate curve")
    func approximateCurve() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let arc = circle.trimmed(from: 0, to: .pi)!
        let approx = arc.approximated(tolerance: 0.01)
        #expect(approx != nil)
    }
}
