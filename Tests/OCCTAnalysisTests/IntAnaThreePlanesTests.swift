import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna ThreePlanes Tests")
struct IntAnaThreePlanesTests {

    @Test func threePlanesAtOrigin() {
        let pt = IntAna.threePlanes(
            p1Origin: SIMD3(0, 0, 0), p1Normal: SIMD3(1, 0, 0),
            p2Origin: SIMD3(0, 0, 0), p2Normal: SIMD3(0, 1, 0),
            p3Origin: SIMD3(0, 0, 0), p3Normal: SIMD3(0, 0, 1))
        #expect(pt != nil)
        if let pt {
            #expect(abs(pt.x) < 1e-10 && abs(pt.y) < 1e-10 && abs(pt.z) < 1e-10)
        }
    }

    @Test func offsetPlanes() {
        let pt = IntAna.threePlanes(
            p1Origin: SIMD3(1, 0, 0), p1Normal: SIMD3(1, 0, 0),
            p2Origin: SIMD3(0, 2, 0), p2Normal: SIMD3(0, 1, 0),
            p3Origin: SIMD3(0, 0, 3), p3Normal: SIMD3(0, 0, 1))
        #expect(pt != nil)
        if let pt {
            #expect(abs(pt.x - 1) < 1e-10 && abs(pt.y - 2) < 1e-10 && abs(pt.z - 3) < 1e-10)
        }
    }
}
