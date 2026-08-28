import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeCylindricalSurface")
struct CylindricalSurfaceTests {
    @Test("Cylindrical surface from axis and radius")
    func fromAxis() throws {
        let surf = try #require(Surface.cylindricalSurface(radius: 3.0))
        #expect(surf.handle != nil)
    }

    @Test("Cylindrical surface from 3 points")
    func fromPoints() throws {
        let surf = try #require(
            Surface.cylindricalSurface(
                point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10), point3: SIMD3(5, 0, 5)))
        #expect(surf.handle != nil)
    }
}

