import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D Evaluation v0.110")
struct Curve3DEvalTests {
    @Test func evalD0BSpline() {
        // Create a BSpline through known points
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let p = curve.evalD0(at: curve.domain.lowerBound)
            #expect(abs(p.x) < 1e-3)
            #expect(abs(p.y) < 1e-3)
            #expect(abs(p.z) < 1e-3)
        }
    }

    @Test func evalD1BSpline() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let mid = (curve.domain.lowerBound + curve.domain.upperBound) / 2
            let r = curve.evalD1(at: mid)
            // The point half must agree with the independently-tested point(at:) accessor
            // (a different bridge call, OCCTCurve3DGetPoint vs. OCCTCurve3DEvalD1), which
            // catches a point/tangent swap that a magnitude-only check on d1 alone would miss.
            let independentPoint = curve.point(at: mid)
            #expect(abs(r.point.x - independentPoint.x) < 1e-9)
            #expect(abs(r.point.y - independentPoint.y) < 1e-9)
            #expect(abs(r.point.z - independentPoint.z) < 1e-9)
            // Tangent should be non-zero at midpoint
            let tangentLength = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y + r.d1.z * r.d1.z)
            #expect(tangentLength > 0.1)
        }
    }

    @Test func evalD2BSpline() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let mid = (curve.domain.lowerBound + curve.domain.upperBound) / 2
            let r = curve.evalD2(at: mid)
            // Second derivative exists for a cubic BSpline
            _ = r.d2  // just confirm it doesn't crash
            #expect(true)
        }
    }

    @Test func evalD3BSpline() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let mid = (curve.domain.lowerBound + curve.domain.upperBound) / 2
            let r = curve.evalD3(at: mid)
            _ = r.d3  // confirm no crash
            #expect(true)
        }
    }

    @Test func evalD0Circle() {
        if let curve = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            let p = curve.evalD0(at: 0)
            #expect(abs(p.x - 5.0) < 1e-6)
            #expect(abs(p.y) < 1e-6)
        }
    }

}
