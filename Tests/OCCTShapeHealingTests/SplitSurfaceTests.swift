import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are ShapeUpgrade_SplitSurface*'s own answers on the same surfaces, from
// Scripts/repro/766-healing-small-files/probe.mm (transcript.txt beside it). Before #766 every
// assertion sat inside `if let` and was a `>=` lower bound. The continuity test converted an
// infinite cylinder, which GeomConvert refuses ("infinite surface", measured), so `toBSpline()`
// was nil and the test never reached its assertion; it now converts a trimmed cylinder.
@Suite("ShapeUpgrade_SplitSurface")
struct SplitSurfaceTests {
    @Test("split surface by continuity")
    func splitSurfaceByContinuity() throws {
        // criterion is a ParametricContinuity raw value: 2 = C2. It used to be read
        // here as a GeomAbs_Shape ordinal, where 4 meant C2 and 2 meant C1, see
        // Issue490ContinuityDecoderTests for the cross-check against the sibling entry
        // point that always read it the other way. #490.
        // Kernel: the degree-2 BSpline of a trimmed r10 h10 cylinder splits at its C1 knots,
        // U = [0, 2pi/3, 4pi/3, 2pi] (4 values), V = [0, 10] (2 values).
        let surf = try #require(Surface.trimmedCylinder(radius: 10, height: 10))
        let bsp = try #require(surf.toBSpline())
        let r = try #require(bsp.splitSurfaceByContinuity(criterion: 2, tolerance: 1e-6))
        #expect(r.uSplitCount == 4)
        #expect(r.vSplitCount == 2)
    }

    @Test("split by angle")
    func splitByAngle() throws {
        // Kernel: full circle / 90 degrees = 4 segments, 5 U split values; V keeps its 2 bounds.
        let surf = try #require(Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10))
        let r = try #require(surf.splitByAngle(.pi / 2))
        #expect(r.uSplitCount == 5)
        #expect(r.vSplitCount == 2)
    }

    @Test("split by area")
    func splitByArea() throws {
        // Kernel: 4 parts of the [0,10]^2 plane patch are a 2 x 2 grid, 3 split values each way.
        let surf = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let trimmed = try #require(surf.trimmed(u1: 0, u2: 10, v1: 0, v2: 10))
        let r = try #require(trimmed.splitByArea(parts: 4))
        #expect(r.uSplitCount == 3)
        #expect(r.vSplitCount == 3)
    }
}
