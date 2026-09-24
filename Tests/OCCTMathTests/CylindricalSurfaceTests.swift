import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeCylindricalSurface")
struct CylindricalSurfaceTests {
    @Test("Cylindrical surface from axis and radius")
    func fromAxis() throws {
        let surf = try #require(Surface.cylindricalSurface(radius: 3.0))
        // A non-nil handle held for any cylinder, so a doubled radius passed. Kernel values from
        // Scripts/repro/766-math-curve-transform-cylinder/transcript.txt.
        #expect(simd_length(surf.point(atU: 0, v: 0) - SIMD3(3, 0, 0)) < 1e-9)
        #expect(simd_length(surf.point(atU: .pi / 2, v: 4) - SIMD3(0, 3, 4)) < 1e-9)
    }

    @Test("Cylindrical surface from 3 points")
    func fromPoints() throws {
        let surf = try #require(
            Surface.cylindricalSurface(
                point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10), point3: SIMD3(5, 0, 5)))
        // A non-nil handle held for any cylinder, so swapping point1 and point3 passed. The axis
        // runs through point1 and point2, and point3 sets radius 5. Kernel values from
        // Scripts/repro/766-math-curve-transform-cylinder/transcript.txt.
        #expect(abs(surf.cylinderProperties.radius - 5) < 1e-9)
        #expect(simd_length(surf.cylinderProperties.axis.direction - SIMD3(0, 0, 1)) < 1e-9)
        #expect(simd_length(surf.point(atU: 0, v: 5) - SIMD3(5, 0, 5)) < 1e-9)
    }
}

