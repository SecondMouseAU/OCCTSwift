import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.127.0, BSpline Curve Completions")
struct BSplineCurveCompletionsTests {

    @Test("BSpline periodic normalization")
    func periodicNormalization() {
        // Create a periodic BSpline via interpolation of closed points
        if let curve = Curve3D.interpolatePeriodic(points: [
            SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-1, 0, 0), SIMD3(0, -1, 0),
        ]) {
            if let normalized = curve.bsplinePeriodicNormalization(100.0) {
                let domain = curve.domain
                #expect(normalized >= domain.lowerBound)
                #expect(normalized <= domain.upperBound)
            }
        }
    }

    @Test("BSpline periodic normalization returns nil for non-periodic")
    func periodicNormalizationNonPeriodic() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 0, 0),
        ]) {
            let result = curve.bsplinePeriodicNormalization(0.5)
            #expect(result == nil)
        }
    }

    @Test("BSpline IsG1 returns true for smooth curve")
    func bsplineIsG1() {
        if let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 1, 0), SIMD3(3, 0, 0),
        ]) {
            let domain = curve.domain
            let result = curve.bsplineIsG1(tFirst: domain.lowerBound, tLast: domain.upperBound)
            #expect(result == true)
        }
    }
}
