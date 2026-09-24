import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakePlane")
struct PlaneConstructionTests {
    @Test("Plane from 3 points")
    func fromPoints() throws {
        let surf = try #require(
            Surface.planeFromPoints(
                SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(0, 10, 0)))
        #expect(surf.handle != nil)
        // A handle says nothing about which plane was built. GC_MakePlane puts the origin at
        // the first point with normal +Z (Scripts/repro/766-math-plane-construction-parity).
        let o = surf.point(atU: 0, v: 0)
        #expect(simd_length(o) < 1e-12)
        let n = try #require(surf.normal(atU: 0, v: 0))
        #expect(abs(n.z - 1.0) < 1e-12)
    }

    @Test("Plane from point and normal")
    func fromPointNormal() throws {
        let surf = try #require(
            Surface.planeFromPointNormal(
                point: SIMD3(5, 5, 5), normal: SIMD3(1, 1, 1)))
        #expect(surf.handle != nil)
        // Pin the plane itself: origin (5, 5, 5), normal (1, 1, 1) / sqrt(3) with its sign.
        let o = surf.point(atU: 0, v: 0)
        #expect(simd_length(o - SIMD3(5, 5, 5)) < 1e-12)
        let n = try #require(surf.normal(atU: 0, v: 0))
        let k = 1.0 / 3.0.squareRoot()
        #expect(simd_length(n - SIMD3(k, k, k)) < 1e-12)
    }
}

