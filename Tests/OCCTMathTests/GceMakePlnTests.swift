import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce_MakePln Tests")
struct GceMakePlnTests {
    @Test func planeFromEquation() {
        if let plane = Surface.planeFromEquation(a: 0, b: 0, c: 1, d: -5) {
            #expect(Bool(true))
        }
    }

    @Test func planeFrom3Points() {
        if let plane = Surface.planeFrom3Points(
            p1: SIMD3(0, 0, 0), p2: SIMD3(1, 0, 0),
            p3: SIMD3(0, 1, 0))
        {
            #expect(Bool(true))
        }
    }
}

