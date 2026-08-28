import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomConvert_CompBezierSurfacesToBSplineSurface")
struct JoinBezierPatchesTests {
    @Test("Join two Bezier patches into BSpline")
    func joinPatches() throws {
        let patch1 = try #require(
            Surface.bezier(poles: [
                [SIMD3(0, 0, 0), SIMD3(0, 10, 0)],
                [SIMD3(5, 0, 0), SIMD3(5, 10, 0)],
            ]))
        let patch2 = try #require(
            Surface.bezier(poles: [
                [SIMD3(5, 0, 0), SIMD3(5, 10, 0)],
                [SIMD3(10, 0, 0), SIMD3(10, 10, 0)],
            ]))
        let joined = try #require(Surface.joinBezierPatches([patch1, patch2], rows: 2, cols: 1))
        #expect(joined.handle != nil)
    }

    @Test("Rejects a rational patch instead of silently dropping its weights (#725)")
    func joinRejectsRationalPatch() throws {
        // GeomConvert_CompBezierSurfacesToBSplineSurface has no rational path: its own
        // Standard_NotImplemented_Raise_if(isrational, ...) guard is compiled out by this
        // project's Release kernel (No_Exception), so without this bridge-side check the
        // converter proceeds anyway and returns the POLYNOMIAL surface through the same
        // control net, with IsDone() == true. This is exactly the ground-truth fixture from
        // #725: a single rational quarter-cylinder Bezier patch (radius 10, three poles, the
        // standard quadratic-rational-Bezier middle weight 1/sqrt(2)), measured (before this
        // fix) to convert to a 0.606602-off polynomial surface reported as a success.
        let invSqrt2 = 1.0 / 2.0.squareRoot()
        let radius = 10.0
        let height = 5.0
        let patch = try #require(
            Surface.bezier(
                poles: [
                    [SIMD3(radius, 0, 0), SIMD3(radius, 0, height)],
                    [SIMD3(radius, radius, 0), SIMD3(radius, radius, height)],
                    [SIMD3(0, radius, 0), SIMD3(0, radius, height)],
                ],
                weights: [
                    [1, 1],
                    [invSqrt2, invSqrt2],
                    [1, 1],
                ]))
        // Sanity check the fixture is genuinely rational. IsURational()/IsVRational() are
        // OCCT's own, and this bridge's `poles[uRow][vCol]` axis does not correspond 1:1 to
        // OCCT's internal U/V (OCCTSurfaceCreateBezier's row/col map onto
        // Geom_BezierSurface's ColLength()/RowLength() the other way around), so check the
        // same `isURational || isVRational` predicate the fix itself uses rather than assuming
        // which one flips.
        #expect(patch.bezierProperties.isURational || patch.bezierProperties.isVRational)
        #expect(Surface.joinBezierPatches([patch], rows: 1, cols: 1) == nil)
    }
}
