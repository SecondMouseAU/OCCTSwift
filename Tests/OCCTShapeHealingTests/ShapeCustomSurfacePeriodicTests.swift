import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeCustom Surface Periodic Tests")
struct ShapeCustomSurfacePeriodicTests {
    @Test("convert to periodic")
    func convertToPeriodic() {
        if let surf = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5) {
            // Cylinder surface is already periodic, result may be nil
            let _ = surf.convertToPeriodic()
            // Just verify no crash
        }
    }

    @Test("conversion gap is deprecated and always -1.0 (#1510)")
    func conversionGapIsDeprecatedSentinel() {
        // A genuinely U-closed, non-periodic clamped BSpline surface: a full-revolution trimmed
        // cylinder converted to BSpline form, then forced non-periodic. This is exactly the
        // shape ConvertToPeriodic is meant to consume, and #1510's own compiled reproducer
        // showed the OLD code fabricated a nonzero "gap" (0.003363078) from an unrelated,
        // throwaway ConvertToAnalytical(1e-3) call on surfaces like this, despite that
        // recognition attempt failing outright.
        guard let cyl = Surface.trimmedCylinder(radius: 5, height: 10),
            let bsp = cyl.toBSpline()
        else {
            Issue.record("setup: could not build a trimmed-cylinder BSpline surface")
            return
        }
        bsp.bsplineSetUNotPeriodic()

        // Before any conversion: the deprecated accessor reports the -1.0 sentinel, not 0.0
        // (ShapeCustom_Surface's own constructor default) and not a value derived from an
        // unrelated ConvertToAnalytical recognition pass.
        #expect(bsp.conversionGap == -1.0)

        // A real, successful ConvertToPeriodic call...
        let periodic = bsp.convertToPeriodic()
        #expect(periodic != nil)

        // ...changes nothing about the deprecated accessor. It never reflected this operation
        // (that was #1510's whole defect) and is now documented to always return -1.0, on the
        // original surface and on the conversion's own result alike.
        #expect(bsp.conversionGap == -1.0)
        if let periodic {
            #expect(periodic.conversionGap == -1.0)
        }
    }
}
