import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomLib CheckBSpline Tests")
struct GeomLibCheckBSplineTests {
    @Test("check 3D BSpline tangents")
    func check3D() {
        if let bsp = Curve3D.bspline(
            poles: [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(4, 0, 0)],
            knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3)
        {
            let result = bsp.checkBSplineTangents()
            // May be nil for simple Bezier-like BSplines, just verify no crash
            let _ = result
        }
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

    @Test("check 2D BSpline tangents")
    func check2D() {
        if let bsp = Curve2D.bspline(
            poles: [SIMD2(0, 0), SIMD2(1, 2), SIMD2(3, 1), SIMD2(4, 0)],
            knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3)
        {
            let result = bsp.checkBSplineTangents()
            let _ = result
        }
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

