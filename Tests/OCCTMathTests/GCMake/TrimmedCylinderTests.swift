import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `GC_MakeTrimmedCylinder`, asserted on the trim it produced rather than on the handle.
///
/// This used to end at `#expect(surf.handle != nil)`, always true for a non-optional
/// `OCCTSurfaceRef` (#3018). What separates this factory from
/// ``Surface/cylindricalSurface(origin:direction:radius:)`` is the bound, so the test measures the
/// bound: a finite v range equal to the requested height, and the two end circles at the requested
/// radius.
@Suite("GC_MakeTrimmedCylinder")
struct TrimmedCylinderTests {
    @Test("Trimmed cylinder from axis, radius, height")
    func trimmedCylinder() throws {
        let surf = try #require(Surface.trimmedCylinder(radius: 4.0, height: 8.0))
        #expect(surf.isCylinder)

        let d = surf.domain
        // The untrimmed spelling reports +/-2e100 here, so a finite v range is the trim itself.
        #expect(d.vMin.isFinite)
        #expect(d.vMax.isFinite)
        #expect(abs((d.vMax - d.vMin) - 8.0) < 1e-9)
        // u is still the full revolution.
        #expect(abs((d.uMax - d.uMin) - 2 * Double.pi) < 1e-9)

        // Both end circles, at the requested radius and at the two ends of the requested height.
        #expect(simd_length(surf.point(atU: 0, v: d.vMin) - SIMD3(4, 0, 0)) < 1e-9)
        #expect(simd_length(surf.point(atU: 0, v: d.vMax) - SIMD3(4, 0, 8)) < 1e-9)
        #expect(simd_length(surf.point(atU: .pi, v: d.vMin) - SIMD3(-4, 0, 0)) < 1e-9)
    }
}
