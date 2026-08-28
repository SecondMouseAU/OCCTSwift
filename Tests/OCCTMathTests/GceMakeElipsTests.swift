import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeElips Tests")
struct GceMakeElipsTests {
    @Test func ellipseFromCenterNormal() {
        if let elips = Curve3D.ellipseFromCenterNormal(
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 5)
        {
            let domain = elips.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}

