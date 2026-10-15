import Foundation
import Testing

@testable import OCCTSwift

@Suite("ShapeCustom Surface Periodic Tests")
struct ShapeCustomSurfacePeriodicTests {
    @Test("convert to periodic")
    func convertToPeriodic() throws {
        // #766: this discarded its answer. A cylindrical surface is already periodic, and the
        // kernel's ShapeCustom_Surface::ConvertToPeriodic returns null for it (probe
        // Scripts/repro/766-healing-construct-custom-extend), so the wrapper's nil is pinned.
        let surf = try #require(
            Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5))
        #expect(surf.convertToPeriodic() == nil)
    }

    // Pins the deprecated accessor's -1.0, so it must keep reading it; the test is itself
    // deprecated so the reads sit in a deprecated context and raise no diagnostic (#3470).
    @available(*, deprecated)
    @Test("conversion gap is deprecated and always -1.0 (#1510)")
    func conversionGapIsDeprecatedSentinel() throws {
        // A genuinely U-closed, non-periodic clamped BSpline surface: a full-revolution trimmed
        // cylinder converted to BSpline form, then forced non-periodic. This is exactly the
        // shape ConvertToPeriodic is meant to consume, and #1510's own compiled reproducer
        // showed the OLD code fabricated a nonzero "gap" (0.003363078) from an unrelated,
        // throwaway ConvertToAnalytical(1e-3) call on surfaces like this, despite that
        // recognition attempt failing outright.
        let cyl = try #require(Surface.trimmedCylinder(radius: 5, height: 10), "setup: cylinder")
        let bsp = try #require(cyl.toBSpline(), "setup: could not convert to BSpline")
        // Measured on the pinned kernel: the BSpline starts periodic in U, and un-periodising it
        // leaves it closed in U, which is the shape ConvertToPeriodic consumes.
        try #require(bsp.isUPeriodic, "setup: the BSpline should start periodic in U")
        bsp.bsplineSetUNotPeriodic()
        try #require(!bsp.isUPeriodic, "setup: the BSpline is still periodic in U")
        try #require(bsp.isUClosed, "setup: the BSpline is not closed in U")

        // Before any conversion: the deprecated accessor reports the -1.0 sentinel, not 0.0
        // (ShapeCustom_Surface's own constructor default) and not a value derived from an
        // unrelated ConvertToAnalytical recognition pass.
        #expect(bsp.conversionGap == -1.0)

        // A real, successful ConvertToPeriodic call...
        let periodic = try #require(bsp.convertToPeriodic(), "convertToPeriodic returned nil")
        // ...which really did make it periodic in U (and only in U).
        #expect(periodic.isUPeriodic)
        #expect(!periodic.isVPeriodic)

        // ...changes nothing about the deprecated accessor. It never reflected this operation
        // (that was #1510's whole defect) and is now documented to always return -1.0, on the
        // original surface and on the conversion's own result alike.
        #expect(bsp.conversionGap == -1.0)
        #expect(periodic.conversionGap == -1.0)
    }
}
