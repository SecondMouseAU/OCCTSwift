import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeHypr Tests")
struct GceMakeHyprTests {
    @Test func hyperbolaFromCenterNormal() {
        if let hypr = Curve3D.hyperbolaFromCenterNormal(
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            majorRadius: 8, minorRadius: 3)
        {
            let domain = hypr.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

