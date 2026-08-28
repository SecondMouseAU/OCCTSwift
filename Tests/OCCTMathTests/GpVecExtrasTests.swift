import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gp_Vec Extras v0.120.0")
struct GpVecExtrasTests {

    @Test func crossMagnitude() {
        let v1 = SIMD3<Double>(1, 0, 0)
        let v2 = SIMD3<Double>(0, 1, 0)
        let mag = Shape.vecCrossMagnitude(v1, v2)
        #expect(abs(mag - 1.0) < 1e-10)
    }

    @Test func crossMagnitudeParallel() {
        let v1 = SIMD3<Double>(1, 0, 0)
        let v2 = SIMD3<Double>(2, 0, 0)
        let mag = Shape.vecCrossMagnitude(v1, v2)
        #expect(abs(mag) < 1e-10)
    }

    @Test func crossSquareMagnitude() {
        let v1 = SIMD3<Double>(1, 0, 0)
        let v2 = SIMD3<Double>(0, 1, 0)
        let sqMag = Shape.vecCrossSquareMagnitude(v1, v2)
        #expect(abs(sqMag - 1.0) < 1e-10)
    }

    @Test func crossMagnitudeScaled() {
        let v1 = SIMD3<Double>(3, 0, 0)
        let v2 = SIMD3<Double>(0, 4, 0)
        let mag = Shape.vecCrossMagnitude(v1, v2)
        #expect(abs(mag - 12.0) < 1e-10)
    }
}

