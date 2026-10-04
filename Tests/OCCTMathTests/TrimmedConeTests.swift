import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `GC_MakeTrimmedCone`, asserted on the trim it produced rather than on the handle.
///
/// This used to end at `#expect(surf.handle != nil)`, always true for a non-optional
/// `OCCTSurfaceRef` (#3018). The one thing that separates this factory from
/// ``Surface/conicalSurface(point1:point2:r1:r2:)`` is that the result is bounded, so that is what
/// the test measures: a finite v range, and the two end circles sitting at the radii and heights
/// the caller asked for.
@Suite("GC_MakeTrimmedCone")
struct TrimmedConeTests {
    @Test("Trimmed cone from endpoints and radii")
    func trimmedCone() throws {
        let surf = try #require(
            Surface.trimmedCone(
                point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
                r1: 5.0, r2: 2.0))
        #expect(surf.isCone)

        let d = surf.domain
        // The untrimmed spelling reports +/-2e100 here, so a finite v range is the trim itself.
        #expect(d.vMin.isFinite)
        #expect(d.vMax.isFinite)
        // v runs along the slant, 10 of height against 3 of radius change.
        #expect(abs((d.vMax - d.vMin) - (10.0 * 10.0 + 3.0 * 3.0).squareRoot()) < 1e-9)
        // u is still the full revolution.
        #expect(abs((d.uMax - d.uMin) - 2 * Double.pi) < 1e-9)

        // The two end circles, which pin both radii and both heights at once.
        #expect(simd_length(surf.point(atU: 0, v: d.vMin) - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(surf.point(atU: 0, v: d.vMax) - SIMD3(2, 0, 10)) < 1e-9)
        // Half a turn round the base circle, so the trim did not collapse u.
        #expect(simd_length(surf.point(atU: .pi, v: d.vMin) - SIMD3(-5, 0, 0)) < 1e-9)
    }
}
