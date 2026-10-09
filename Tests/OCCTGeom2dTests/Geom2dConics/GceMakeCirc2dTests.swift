import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeCirc2d Tests")
struct GceMakeCirc2dTests {
    @Test func circleFromCenterRadius() {
        if let circ = Curve2D.circleFromCenterRadius(center: SIMD2(0, 0), radius: 5.0) {
            let domain = circ.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }

    @Test func circleThrough3Points() {
        if let circ = Curve2D.circleThrough3Points(SIMD2(5, 0), SIMD2(0, 5), SIMD2(-5, 0)) {
            let domain = circ.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}
