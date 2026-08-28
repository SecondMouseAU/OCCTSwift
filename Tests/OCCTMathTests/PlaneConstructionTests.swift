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
    }

    @Test("Plane from point and normal")
    func fromPointNormal() throws {
        let surf = try #require(
            Surface.planeFromPointNormal(
                point: SIMD3(5, 5, 5), normal: SIMD3(1, 1, 1)))
        #expect(surf.handle != nil)
    }
}

