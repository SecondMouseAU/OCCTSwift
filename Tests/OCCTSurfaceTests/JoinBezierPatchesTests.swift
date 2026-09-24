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
        // #766: was `joined.handle != nil`, true of any Surface. The two patches become one
        // BSpline on [0, 2] x [0, 1] with 3 x 2 poles, and the second patch's midpoint (7.5, 5, 0)
        // sits at 75% / 50% of it, per GeomConvert_CompBezierSurfacesToBSplineSurface
        // (Scripts/repro/766-join-local-loft/).
        #expect(joined.bsplineSurface.nbUPoles == 3)
        #expect(joined.bsplineSurface.nbVPoles == 2)
        let d = joined.domain
        #expect(d.uMin == 0 && d.uMax == 2 && d.vMin == 0 && d.vMax == 1)
        #expect(simd_length(joined.point(atU: 1.5, v: 0.5) - SIMD3(7.5, 5, 0)) < 1e-12)
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
