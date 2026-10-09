import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLib Interpolate Tests")
struct GeomLibInterpolateTests {
    // #766: this asserted only `curve != nil`, so a curve that missed every point passed. It now
    // pins the interpolation property itself: C(t_i) == P_i at every given parameter, which is
    // what GeomLib_Interpolate reports (Scripts/repro/766-math-geomlib-interp-planar-tool).
    @Test("polynomial interpolation")
    func interpolate() throws {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0), SIMD3(3, -1, 0), SIMD3(4, 0, 0),
        ]
        let params = [0.0, 0.25, 0.5, 0.75, 1.0]
        let curve = try #require(
            Curve3D.polynomialInterpolation(degree: 3, points: points, parameters: params))
        for (p, t) in zip(points, params) {
            #expect(simd_length(curve.point(at: t) - p) < 1e-9)
        }
    }

    @Test("interpolated curve endpoints")
    func endpoints() throws {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(2, 2, 0), SIMD3(4, 0, 0)]
        let params = [0.0, 0.5, 1.0]
        // #766: `try #require` rather than `if let`, so a nil curve fails instead of skipping.
        let curve = try #require(
            Curve3D.polynomialInterpolation(degree: 3, points: points, parameters: params))
        let dom = curve.domain
        let start = curve.point(at: dom.lowerBound)
        let end = curve.point(at: dom.upperBound)
        #expect(abs(start.x) < 1e-6 && abs(start.y) < 1e-6)
        #expect(abs(end.x - 4.0) < 1e-6 && abs(end.y) < 1e-6)
    }
}
