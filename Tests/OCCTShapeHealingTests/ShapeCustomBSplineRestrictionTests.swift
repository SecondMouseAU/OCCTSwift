import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-construct-custom-extend/probe.mm (transcript.txt beside it).
// Before #766 both asserted only inside `if let`, so a nil result passed; the first also asserted
// `faces().count > 0`. Planes are not approximated by default, so the kernel returns the box's
// six planes and its volume, at both parameter sets.
@Suite("ShapeCustom BSplineRestriction Tests")
struct ShapeCustomBSplineRestrictionTests {
    @Test("BSpline restriction on box")
    func bsplineRestrictionBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.bsplineRestriction(tol3d: 0.01, tol2d: 0.01))
        #expect(result.isValid)
        #expect(result.faces().count == 6)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-9)
    }

    @Test("BSpline restriction with custom parameters")
    func bsplineRestrictionCustom() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(
            box.bsplineRestriction(
                tol3d: 0.001, tol2d: 0.001,
                maxDegree: 4, maxSegments: 50,
                continuity3d: .c2, continuity2d: .c2
            ))
        #expect(result.isValid)
        #expect(result.faces().count == 6)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-9)
    }
}
