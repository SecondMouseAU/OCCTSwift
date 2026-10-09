import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeHypr2d Tests")
struct GceMakeHypr2dTests {
    @Test func hyperbolaFromCenterDir() {
        if let hypr = Curve2D.hyperbolaFromCenterDir(
            center: SIMD2(0, 0), direction: SIMD2(1, 0),
            majorRadius: 6, minorRadius: 3)
        {
            let domain = hypr.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}
