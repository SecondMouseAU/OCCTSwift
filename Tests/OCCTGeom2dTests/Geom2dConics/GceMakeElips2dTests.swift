import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeElips2d Tests")
struct GceMakeElips2dTests {
    @Test func ellipseFromCenterDir() {
        if let elips = Curve2D.ellipseFromCenterDir(
            center: SIMD2(0, 0), direction: SIMD2(1, 0),
            majorRadius: 8, minorRadius: 4)
        {
            let domain = elips.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}
