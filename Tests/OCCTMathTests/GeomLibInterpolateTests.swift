import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLib Interpolate Tests")
struct GeomLibInterpolateTests {
    @Test("polynomial interpolation")
    func interpolate() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0), SIMD3(3, -1, 0), SIMD3(4, 0, 0),
        ]
        let params = [0.0, 0.25, 0.5, 0.75, 1.0]
        let curve = Curve3D.polynomialInterpolation(degree: 3, points: points, parameters: params)
        #expect(curve != nil)
    }

    @Test("interpolated curve endpoints")
    func endpoints() {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(2, 2, 0), SIMD3(4, 0, 0)]
        let params = [0.0, 0.5, 1.0]
        if let curve = Curve3D.polynomialInterpolation(
            degree: 3, points: points, parameters: params)
        {
            let dom = curve.domain
            let start = curve.point(at: dom.lowerBound)
            let end = curve.point(at: dom.upperBound)
            #expect(abs(start.x) < 1e-6 && abs(start.y) < 1e-6)
            #expect(abs(end.x - 4.0) < 1e-6 && abs(end.y) < 1e-6)
        }
    }
}

