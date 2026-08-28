import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeLin Tests")
struct GceMakeLinTests {
    @Test func lineFrom2Points() {
        if let line = Curve3D.lineFrom2Points(SIMD3(0, 0, 0), SIMD3(1, 2, 3)) {
            let domain = line.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

