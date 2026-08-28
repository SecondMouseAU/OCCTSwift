import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeParab Tests")
struct GceMakeParabTests {
    @Test func parabolaFromCenterNormal() {
        if let parab = Curve3D.parabolaFromCenterNormal(
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            focal: 4.0)
        {
            let domain = parab.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

