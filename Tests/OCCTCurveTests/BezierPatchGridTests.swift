import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.40.0: BSpline Bezier Patch Grid

@Suite("BSpline Bezier Patch Grid")
struct BezierPatchGridTests {
    @Test("BSpline surface decomposes to Bezier patches")
    func bsplineToBezier() {
        // Create a BSpline surface using the full bspline API
        // 4x4 control points with uniform knots for degree 3
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 10, 1), SIMD3(0, 20, -1), SIMD3(0, 30, 0)],
            [SIMD3(10, 0, 1), SIMD3(10, 10, 3), SIMD3(10, 20, 0), SIMD3(10, 30, 1)],
            [SIMD3(20, 0, -1), SIMD3(20, 10, 0), SIMD3(20, 20, 2), SIMD3(20, 30, -1)],
            [SIMD3(30, 0, 0), SIMD3(30, 10, 1), SIMD3(30, 20, -1), SIMD3(30, 30, 0)],
        ]
        let surface = Surface.bspline(
            poles: poles,
            knotsU: [0, 1], multiplicitiesU: [4, 4],
            knotsV: [0, 1], multiplicitiesV: [4, 4],
            degreeU: 3, degreeV: 3
        )
        #expect(surface != nil)
        if let surface {
            let grid = surface.toBezierPatchGrid()
            if let grid {
                #expect(grid.uCount >= 1)
                #expect(grid.vCount >= 1)
                #expect(grid.patches.count == grid.uCount * grid.vCount)
            }
        }
    }
}
