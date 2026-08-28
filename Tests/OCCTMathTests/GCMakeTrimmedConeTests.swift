import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeTrimmedCone Tests")
struct GCMakeTrimmedConeTests {

    @Test func trimmedCone2Pts() {
        if let s = Surface.gcTrimmedCone2Pts(
            p1: SIMD3(0, 0, 0), p2: SIMD3(0, 0, 10),
            r1: 5, r2: 2)
        {
            #expect(s.continuity >= 0)
        }
    }

    @Test func trimmedCone4Pts() {
        let s = Surface.gcTrimmedCone4Pts(
            p1: SIMD3(5, 0, 0), p2: SIMD3(0, 5, 0),
            p3: SIMD3(2, 0, 10), p4: SIMD3(0, 2, 10))
        let _ = s
    }
}

