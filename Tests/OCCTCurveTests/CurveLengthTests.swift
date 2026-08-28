import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Curve Length and Closest")
struct CurveLengthTests {

    @Test func curve3DArcLength() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        if let curve = Curve3D.interpolate(
            points: points,
            startTangent: SIMD3(1, 0, 0),
            endTangent: SIMD3(1, 0, 0))
        {
            let domain = curve.domain
            let len = curve.arcLength(from: domain.lowerBound, to: domain.upperBound)
            #expect(len > 0)
        }
    }

    @Test func curve3DClosestParameter() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let param = line.nearestParameter(to: SIMD3(5, 3, 0))
            // For a line along X, closest to (5,3,0) should be near param=5
            #expect(param != nil)
            if let param { #expect(abs(param - 5.0) < 0.1) }
        }
    }

    @Test func curve2DArcLength() {
        let points = [SIMD2(0.0, 0.0), SIMD2(5.0, 5.0), SIMD2(10.0, 0.0)]
        if let curve = Curve2D.interpolate(
            points: points,
            startTangent: SIMD2(1, 1),
            endTangent: SIMD2(1, -1))
        {
            let domain = curve.domain
            let len = curve.arcLength(from: domain.lowerBound, to: domain.upperBound)
            #expect(len > 0)
        }
    }
}
