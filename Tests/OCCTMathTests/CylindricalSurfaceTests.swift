import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `GC_MakeCylindricalSurface`, asserted on the cylinder it produced rather than on the handle.
///
/// Both tests used to end at `#expect(surf.handle != nil)`, always true for a non-optional
/// `OCCTSurfaceRef` (#3018). A cylinder is determined by its axis and its radius, so each test
/// pins both, and a point on the surface as the second construction of the same two numbers.
@Suite("GC_MakeCylindricalSurface")
struct CylindricalSurfaceTests {
    @Test("Cylindrical surface from axis and radius")
    func fromAxis() throws {
        let surf = try #require(Surface.cylindricalSurface(radius: 3.0))
        #expect(surf.isCylinder)
        #expect(abs(surf.cylinderProperties.radius - 3.0) < 1e-12)
        let axis = surf.cylinderProperties.axis
        #expect(simd_length(axis.position - SIMD3(0, 0, 0)) < 1e-12)
        #expect(simd_length(axis.direction - SIMD3(0, 0, 1)) < 1e-12)
        // u = 0 is the seam, so the surface passes through (r, 0, 0) at v = 0.
        #expect(simd_length(surf.point(atU: 0, v: 0) - SIMD3(3, 0, 0)) < 1e-9)
        #expect(simd_length(surf.point(atU: .pi, v: 0) - SIMD3(-3, 0, 0)) < 1e-9)
    }

    @Test("Cylindrical surface from 3 points")
    func fromPoints() throws {
        let surf = try #require(
            Surface.cylindricalSurface(
                point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10), point3: SIMD3(5, 0, 5)))
        #expect(surf.isCylinder)
        // The axis runs through point1 and point2; the radius is point3's distance from it, which
        // is 5 and not point3's distance from either axis point (5*sqrt(2) and 5).
        #expect(abs(surf.cylinderProperties.radius - 5.0) < 1e-12)
        let axis = surf.cylinderProperties.axis
        #expect(simd_length(axis.position - SIMD3(0, 0, 0)) < 1e-12)
        #expect(simd_length(axis.direction - SIMD3(0, 0, 1)) < 1e-12)
        #expect(simd_length(surf.point(atU: 0, v: 0) - SIMD3(5, 0, 0)) < 1e-9)
    }
}
