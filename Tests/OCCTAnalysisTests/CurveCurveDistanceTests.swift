import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve-Curve Distance")
struct CurveCurveDistanceTests {
    @Test("Distance between parallel lines")
    func parallelLines() {
        let c1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let c2 = Curve3D.segment(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0))!
        let dist = c1.minDistance(to: c2)
        #expect(dist != nil)
        #expect(abs(dist! - 5.0) < 1e-6)
    }

    @Test("Extrema between skew lines")
    func skewLines() {
        let c1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let c2 = Curve3D.segment(from: SIMD3(5, 3, -5), to: SIMD3(5, 3, 5))!
        let extrema = c1.extrema(with: c2)
        #expect(extrema.count >= 1)
        #expect(abs(extrema[0].distance - 3.0) < 1e-6)
    }

    @Test("Curve-surface distance")
    func curveSurfaceDistance() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 5), to: SIMD3(10, 0, 5))!
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let dist = line.minDistance(to: plane)
        #expect(dist != nil)
        #expect(abs(dist! - 5.0) < 1e-6)
    }
}
