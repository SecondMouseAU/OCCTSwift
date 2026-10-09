import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.67.0: FairCurve, LocalAnalysis, TopTrans

@Suite("FairCurve Batten Tests")
struct FairCurveBattenTests {
    @Test func basicBatten() {
        if let result = Curve2D.fairCurveBatten(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0), height: 2.0
        ) {
            #expect(result.code == .ok)
        }
    }

    @Test func battenWithSlope() {
        if let result = Curve2D.fairCurveBatten(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0),
            height: 3.0, slope: 0.5
        ) {
            #expect(result.code == .ok)
        }
    }

    @Test func battenWithAngles() {
        if let result = Curve2D.fairCurveBatten(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0),
            height: 2.0, angle1: 0.3, angle2: -0.3
        ) {
            #expect(result.code == .ok)
        }
    }

    @Test func battenConstraintOrders() {
        if let result = Curve2D.fairCurveBatten(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0),
            height: 2.0,
            constraintOrder1: 0, constraintOrder2: 0
        ) {
            #expect(result.code == .ok)
        }
    }

    @Test func battenCurveProperties() {
        if let result = Curve2D.fairCurveBatten(
            p1: SIMD2(0, 0), p2: SIMD2(10, 0), height: 2.0
        ) {
            let d = result.curve.domain
            #expect(d.lowerBound < d.upperBound)
        }
    }
}
