import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `GC_MakeConicalSurface`, asserted on the cone it produced rather than on the handle.
///
/// Both tests used to end at `#expect(surf.handle != nil)`, which `Surface.handle` is
/// non-optional for, so the compiler reported it as always true and the `try #require` above it
/// was the only thing either test measured (#3018). A cone is fully determined by its axis, its
/// semi-angle and its reference radius, so each test now pins all three, plus the apex they imply,
/// which is the one value a wrong semi-angle or a wrong radius cannot leave in place.
@Suite("GC_MakeConicalSurface")
struct ConicalSurfaceTests {
    @Test("Conical surface from axis and angle")
    func fromAxis() throws {
        let surf = try #require(Surface.conicalSurface(semiAngle: .pi / 6, radius: 5.0))
        #expect(surf.isCone)
        #expect(abs(surf.coneProperties.semiAngle - .pi / 6) < 1e-12)
        #expect(abs(surf.coneProperties.refRadius - 5.0) < 1e-12)
        // The default axis is +Z through the origin, and the reference radius sits at v = 0, so
        // the apex is 5/tan(30 degrees) below the origin.
        let apex = SIMD3(0, 0, -5.0 / tan(Double.pi / 6))
        #expect(simd_length(surf.coneProperties.apex - apex) < 1e-9)
        // v = 0 is the reference circle itself: the surface passes through radius 5 at z = 0.
        #expect(simd_length(surf.point(atU: 0, v: 0) - SIMD3(5, 0, 0)) < 1e-9)
    }

    @Test("Conical surface from points and radii")
    func fromPointsRadii() throws {
        let surf = try #require(
            Surface.conicalSurface(
                point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
                r1: 5.0, r2: 2.0))
        #expect(surf.isCone)
        #expect(abs(surf.coneProperties.refRadius - 5.0) < 1e-12)
        // Radius 5 at z = 0 falling to radius 2 at z = 10 is a slope of 3 in 10. OCCT signs the
        // semi-angle against its own axis sense, measured negative for this pairing, so the
        // magnitude is what the inputs fix.
        #expect(abs(abs(surf.coneProperties.semiAngle) - atan(0.3)) < 1e-12)
        // The apex is where that slope reaches radius 0, at z = 10 * 5/3, and it is the value no
        // single wrong radius leaves standing: 5 and 2 are both in it.
        #expect(simd_length(surf.coneProperties.apex - SIMD3(0, 0, 50.0 / 3.0)) < 1e-9)
        #expect(simd_length(surf.point(atU: 0, v: 0) - SIMD3(5, 0, 0)) < 1e-9)
    }
}
