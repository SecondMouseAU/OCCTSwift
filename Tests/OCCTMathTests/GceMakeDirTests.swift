import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakeDir Tests")
struct GceMakeDirTests {
    @Test func directionFrom2Points() {
        if let dir = Curve3D.directionFrom2Points(SIMD3(0, 0, 0), SIMD3(3, 0, 0)) {
            #expect(abs(dir.x - 1.0) < 1e-10)
            #expect(abs(dir.y) < 1e-10)
            #expect(abs(dir.z) < 1e-10)
        }
    }
}

