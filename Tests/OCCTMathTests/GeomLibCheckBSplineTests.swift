import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLib CheckBSpline Tests")
struct GeomLibCheckBSplineTests {
    // #1457: `OCCTGeomLibCheckBSpline3D`/`2D` used to gate on `GeomLib_CheckBSplineCurve::IsDone()`
    // (resp. `GeomLib_Check2dBSplineCurve`), which `myDone` only ever sets true in the
    // constructor's trivial early-exit branch (periodic curve, or fewer than 4 poles) or at the
    // end of `FixTangentOnCurve()`. Along the real analysis branch, an ordinary non-periodic
    // curve with 4+ poles, `myDone` is never touched even though the tangent flags are correctly
    // computed, so `checkBSplineTangents()` returned `nil` unconditionally for virtually every
    // real curve. These fixtures assert the actual computed flags, not just "no crash".

    @Test("check 3D BSpline tangents: ordinary curve returns a real result, not nil")
    func check3DOrdinaryCurve() throws {
        let bsp = try #require(
            Curve3D.bspline(
                poles: [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(4, 0, 0)],
                knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3))
        let result = try #require(bsp.checkBSplineTangents())
        #expect(result.fixFirst == false)
        #expect(result.fixLast == false)
    }

    @Test("check 3D BSpline tangents: reversed-first control polygon is detected")
    func check3DReversedFirstTangent() throws {
        // Pole 2 folds back past pole 1 relative to pole 3 (all colinear on the X axis), which
        // GeomLib_CheckBSplineCurve's own algorithm defines as a reversed first tangent.
        let bsp = try #require(
            Curve3D.bspline(
                poles: [SIMD3(2, 0, 0), SIMD3(0, 0, 0), SIMD3(4, 0, 0), SIMD3(8, 0, 0)],
                knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3))
        let result = try #require(bsp.checkBSplineTangents())
        #expect(result.fixFirst == true)
        #expect(result.fixLast == false)
    }

    @Test("check 3D BSpline tangents: reversed-last control polygon is detected")
    func check3DReversedLastTangent() throws {
        // Mirror image of the reversed-first fixture: the fold now sits at the curve's end.
        let bsp = try #require(
            Curve3D.bspline(
                poles: [SIMD3(8, 0, 0), SIMD3(4, 0, 0), SIMD3(0, 0, 0), SIMD3(2, 0, 0)],
                knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3))
        let result = try #require(bsp.checkBSplineTangents())
        #expect(result.fixFirst == false)
        #expect(result.fixLast == true)
    }

    @Test("fix 3D BSpline tangents")
    func fix3D() {
        if let bsp = Curve3D.bspline(
            poles: [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(4, 0, 0)],
            knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3)
        {
            let fixed = bsp.fixBSplineTangents(fixFirst: false, fixLast: false)
            let _ = fixed
        }
    }

    @Test("check 2D BSpline tangents: ordinary curve returns a real result, not nil")
    func check2DOrdinaryCurve() throws {
        let bsp = try #require(
            Curve2D.bspline(
                poles: [SIMD2(0, 0), SIMD2(1, 2), SIMD2(3, 1), SIMD2(4, 0)],
                knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3))
        let result = try #require(bsp.checkBSplineTangents())
        #expect(result.fixFirst == false)
        #expect(result.fixLast == false)
    }

    @Test("check 2D BSpline tangents: reversed-first control polygon is detected")
    func check2DReversedFirstTangent() throws {
        let bsp = try #require(
            Curve2D.bspline(
                poles: [SIMD2(2, 0), SIMD2(0, 0), SIMD2(4, 0), SIMD2(8, 0)],
                knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3))
        let result = try #require(bsp.checkBSplineTangents())
        #expect(result.fixFirst == true)
        #expect(result.fixLast == false)
    }

    @Test("check 2D BSpline tangents: reversed-last control polygon is detected")
    func check2DReversedLastTangent() throws {
        let bsp = try #require(
            Curve2D.bspline(
                poles: [SIMD2(8, 0), SIMD2(4, 0), SIMD2(0, 0), SIMD2(2, 0)],
                knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3))
        let result = try #require(bsp.checkBSplineTangents())
        #expect(result.fixFirst == false)
        #expect(result.fixLast == true)
    }

    @Test("fix 2D BSpline tangents")
    func fix2D() {
        if let bsp = Curve2D.bspline(
            poles: [SIMD2(0, 0), SIMD2(1, 2), SIMD2(3, 1), SIMD2(4, 0)],
            knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3)
        {
            let fixed = bsp.fixBSplineTangents(fixFirst: false, fixLast: false)
            let _ = fixed
        }
    }
}
