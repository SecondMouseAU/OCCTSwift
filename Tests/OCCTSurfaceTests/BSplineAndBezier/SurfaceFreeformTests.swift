import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Freeform")
struct SurfaceFreeformTests {
    @Test("Bezier surface from 3x3 control points")
    func bezierSurface() {
        // Simple 3x3 bilinear-ish surface
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(5, 0, 0), SIMD3(10, 0, 0)],
            [SIMD3(0, 5, 2), SIMD3(5, 5, 3), SIMD3(10, 5, 2)],
            [SIMD3(0, 10, 0), SIMD3(5, 10, 0), SIMD3(10, 10, 0)],
        ]
        let bez = Surface.bezier(poles: poles)
        #expect(bez != nil)
        if let bez = bez {
            #expect(bez.uPoleCount == 3)
            #expect(bez.vPoleCount == 3)
            #expect(bez.uDegree == 2)
            #expect(bez.vDegree == 2)

            // Corner at (0,0) = first pole
            let p00 = bez.point(atU: 0, v: 0)
            #expect(abs(p00.x) < 1e-10)
            #expect(abs(p00.y) < 1e-10)

            // Corner at (1,1) = last pole
            let p11 = bez.point(atU: 1, v: 1)
            #expect(abs(p11.x - 10) < 1e-10)
            #expect(abs(p11.y - 10) < 1e-10)
        }
    }

    @Test("BSpline surface creation")
    func bsplineSurface() {
        // 4x4 control grid, degree 3x3
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(3, 0, 0), SIMD3(7, 0, 0), SIMD3(10, 0, 0)],
            [SIMD3(0, 3, 1), SIMD3(3, 3, 2), SIMD3(7, 3, 2), SIMD3(10, 3, 1)],
            [SIMD3(0, 7, 1), SIMD3(3, 7, 2), SIMD3(7, 7, 2), SIMD3(10, 7, 1)],
            [SIMD3(0, 10, 0), SIMD3(3, 10, 0), SIMD3(7, 10, 0), SIMD3(10, 10, 0)],
        ]
        let bsp = Surface.bspline(
            poles: poles,
            knotsU: [0, 1], multiplicitiesU: [4, 4],
            knotsV: [0, 1], multiplicitiesV: [4, 4],
            degreeU: 3, degreeV: 3)
        #expect(bsp != nil)
        if let bsp = bsp {
            #expect(bsp.uDegree == 3)
            #expect(bsp.vDegree == 3)
            let p = bsp.poles
            #expect(p.count == 4)
            #expect(p[0].count == 4)
        }
    }

    @Test("Bezier surface poles round-trip")
    func bezierPolesRoundTrip() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(5, 0, 1)],
            [SIMD3(0, 5, 1), SIMD3(5, 5, 0)],
        ]
        let bez = Surface.bezier(poles: poles)!
        let retrieved = bez.poles
        #expect(retrieved.count == 2)
        #expect(retrieved[0].count == 2)
        for i in 0..<2 {
            for j in 0..<2 {
                let diff = simd_length(retrieved[i][j] - poles[i][j])
                #expect(diff < 1e-10)
            }
        }
    }
}
