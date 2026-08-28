import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - Curve isBounded")
struct CurveIsBoundedTests {

    @Test func lineIsNotBounded() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            #expect(!line.isBounded)
        }
    }

    @Test func bsplineIsBounded() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0)]
        if let curve = Curve3D.fit(points: points) {
            #expect(curve.isBounded)
        }
    }

    @Test func line2dIsNotBounded() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            #expect(!line.isBounded)
        }
    }

    @Test func bspline2dIsBounded() {
        let points = [SIMD2(0.0, 0.0), SIMD2(1.0, 1.0), SIMD2(2.0, 0.0)]
        if let curve = Curve2D.fit(through: points) {
            #expect(curve.isBounded)
        }
    }
}
