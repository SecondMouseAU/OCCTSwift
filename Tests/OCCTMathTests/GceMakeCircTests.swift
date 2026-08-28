import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeCirc Tests")
struct GceMakeCircTests {
    @Test func circleThrough3Points() {
        if let circ = Curve3D.circleThrough3Points(SIMD3(5, 0, 0), SIMD3(0, 5, 0), SIMD3(-5, 0, 0))
        {
            let domain = circ.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }

    @Test func circleFromCenterNormal() {
        if let circ = Curve3D.circleFromCenterNormal(
            center: SIMD3(1, 2, 3),
            normal: SIMD3(0, 0, 1), radius: 7.0)
        {
            let domain = circ.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

