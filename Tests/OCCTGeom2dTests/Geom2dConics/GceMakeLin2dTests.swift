import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeLin2d Tests")
struct GceMakeLin2dTests {
    @Test func lineFrom2Points() {
        if let line = Curve2D.lineFrom2Points(SIMD2(0, 0), SIMD2(1, 0)) {
            let domain = line.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }

    @Test func lineFromEquation() {
        if let line = Curve2D.lineFromEquation(a: 1, b: 0, c: -5) {
            let domain = line.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}
