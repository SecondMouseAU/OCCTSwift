import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.40.0: BSpline Bezier Patch Grid

@Suite("BSpline Bezier Patch Grid")
struct BezierPatchGridTests {
    // A single-span degree-3 surface is one Bezier patch that evaluates exactly as the surface
    // does (GeomConvert_BSplineSurfaceToBezierSurface, Scripts/repro/766-curve-batch-bezier/).
    // The earlier version wrapped every expectation in `if let`, and `>= 1` accepted any grid
    // dimensions consistent with the patch count (#766).
    @Test("BSpline surface decomposes to Bezier patches")
    func bsplineToBezier() {
        // 4x4 control points with uniform knots for degree 3
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 10, 1), SIMD3(0, 20, -1), SIMD3(0, 30, 0)],
            [SIMD3(10, 0, 1), SIMD3(10, 10, 3), SIMD3(10, 20, 0), SIMD3(10, 30, 1)],
            [SIMD3(20, 0, -1), SIMD3(20, 10, 0), SIMD3(20, 20, 2), SIMD3(20, 30, -1)],
            [SIMD3(30, 0, 0), SIMD3(30, 10, 1), SIMD3(30, 20, -1), SIMD3(30, 30, 0)],
        ]
        guard
            let surface = Surface.bspline(
                poles: poles,
                knotsU: [0, 1], multiplicitiesU: [4, 4],
                knotsV: [0, 1], multiplicitiesV: [4, 4],
                degreeU: 3, degreeV: 3
            )
        else {
            Issue.record("BSpline surface not built")
            return
        }
        guard let grid = surface.toBezierPatchGrid() else {
            Issue.record("toBezierPatchGrid returned nil for a BSpline surface")
            return
        }
        #expect(grid.uCount == 1)
        #expect(grid.vCount == 1)
        #expect(grid.patches.count == grid.uCount * grid.vCount)
        guard let patch = grid.patches.first else { return }
        let expected = SIMD3<Double>(9, 12, 0.80424)
        #expect(simd_distance(surface.point(atU: 0.3, v: 0.4), expected) < 1e-9)
        #expect(simd_distance(patch.point(atU: 0.3, v: 0.4), expected) < 1e-9)
    }
}
