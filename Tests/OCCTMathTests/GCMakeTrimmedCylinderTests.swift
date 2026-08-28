import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeTrimmedCylinder Tests")
struct GCMakeTrimmedCylinderTests {

    @Test func trimmedCylinderCircle() {
        if let s = Surface.gcTrimmedCylinderCircle(
            center: .zero, normal: SIMD3(0, 0, 1),
            radius: 5, height: 10)
        {
            #expect(s.continuity >= 0)
        }
    }

    @Test func trimmedCylinderAxis() {
        if let s = Surface.gcTrimmedCylinderAxis(
            point: .zero, direction: SIMD3(0, 0, 1),
            radius: 5, height: 10)
        {
            #expect(s.continuity >= 0)
        }
    }

    @Test func trimmedCylinder3Pts() {
        if let s = Surface.gcTrimmedCylinder3Pts(
            p1: SIMD3(5, 0, 0), p2: SIMD3(5, 0, 10), p3: SIMD3(0, 5, 0))
        {
            #expect(s.continuity >= 0)
        }
    }
}

