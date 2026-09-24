import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeConicalSurface")
struct ConicalSurfaceTests {
    @Test("Conical surface from axis and angle")
    func fromAxis() throws {
        let surf = try #require(Surface.conicalSurface(semiAngle: .pi / 6, radius: 5.0))
        // A non-nil handle held for any cone at all, so a doubled semi-angle passed. Pin the
        // geometry: radius 5 at v = 0, widening by sin(pi/6) and rising by cos(pi/6) per unit v.
        // Kernel values from Scripts/repro/766-math-roots-cones-coordsys/transcript.txt.
        #expect(simd_length(surf.point(atU: 0, v: 0) - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(surf.point(atU: 0, v: 1) - SIMD3(5.5, 0, 0.866025403784)) < 1e-9)
        #expect(simd_length(surf.point(atU: .pi / 2, v: 2) - SIMD3(0, 6, 1.73205080757)) < 1e-9)
    }

    @Test("Conical surface from points and radii")
    func fromPointsRadii() throws {
        let surf = try #require(
            Surface.conicalSurface(
                point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
                r1: 5.0, r2: 2.0))
        // A non-nil handle held for any cone, so swapped radii passed. Pin the geometry: radius 5
        // at point1, and the generatrix (length sqrt(109)) ending at radius 2 at point2.
        // Kernel values from Scripts/repro/766-math-roots-cones-coordsys/transcript.txt.
        #expect(simd_length(surf.point(atU: 0, v: 0) - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(surf.point(atU: 0, v: 109.0.squareRoot()) - SIMD3(2, 0, 10)) < 1e-9)
    }
}

