import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-curve-custom/probe.mm (transcript.txt beside it).
// Before #766 the only assertion sat inside `if let` and dereferenced `size!`, so a nil result
// passed. Planes are left alone by ShapeCustom_BSplineRestriction, so the kernel returns the box.
@Suite("ShapeCustom_BSplineRestriction Advanced")
struct BSplineRestrictionAdvancedTests {
    @Test("restrict box BSpline")
    func restrictBox() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let r = try #require(
            Shape.bsplineRestrictionAdvanced(
                box,
                tol3d: 0.1, tol2d: 0.1,
                maxDegree: 5, maxSegments: 20))
        let size = try #require(r.size)
        #expect(simd_distance(size, SIMD3(10, 20, 30)) < 1e-6)
        #expect(abs((r.volume ?? 0) - 6000) < 1e-9)
        #expect(r.faces().allSatisfy { $0.surfaceType == .plane })
    }
}
