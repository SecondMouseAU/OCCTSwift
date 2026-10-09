import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeParab2d Tests")
struct GceMakeParab2dTests {
    @Test func parabolaFromCenterDir() {
        if let parab = Curve2D.parabolaFromCenterDir(
            center: SIMD2(0, 0), direction: SIMD2(1, 0),
            focal: 3.0)
        {
            let domain = parab.domain
            #expect(domain.upperBound > domain.lowerBound)
        }
    }
}
