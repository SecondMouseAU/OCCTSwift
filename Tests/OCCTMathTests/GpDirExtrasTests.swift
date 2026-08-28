import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gp_Dir Extras v0.120.0")
struct GpDirExtrasTests {

    @Test func isOpposite() {
        let d1 = SIMD3<Double>(1, 0, 0)
        let d2 = SIMD3<Double>(-1, 0, 0)
        #expect(Shape.dirIsOpposite(d1, d2, tolerance: 0.01))
    }

    @Test func isNotOpposite() {
        let d1 = SIMD3<Double>(1, 0, 0)
        let d2 = SIMD3<Double>(0, 1, 0)
        #expect(!Shape.dirIsOpposite(d1, d2, tolerance: 0.01))
    }

    @Test func isNormal() {
        let d1 = SIMD3<Double>(1, 0, 0)
        let d2 = SIMD3<Double>(0, 1, 0)
        #expect(Shape.dirIsNormal(d1, d2, tolerance: 0.01))
    }

    @Test func isNotNormal() {
        let d1 = SIMD3<Double>(1, 0, 0)
        let d2 = SIMD3<Double>(1, 0, 0)
        #expect(!Shape.dirIsNormal(d1, d2, tolerance: 0.01))
    }

    @Test func isNormalDiagonal() {
        // (1,1,0) normalized is perpendicular to (1,-1,0) normalized
        let d1 = SIMD3<Double>(1, 1, 0)
        let d2 = SIMD3<Double>(1, -1, 0)
        #expect(Shape.dirIsNormal(d1, d2, tolerance: 0.01))
    }
}

