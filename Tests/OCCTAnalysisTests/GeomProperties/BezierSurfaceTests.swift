import Foundation
import Testing

@testable import OCCTSwift

@Suite("BezierSurface_Properties")
struct BezierSurfaceTests {
    func makeBezierSurface() -> Surface? {
        Surface.bezier(poles: [
            [SIMD3(0, 0, 0), SIMD3(0, 5, 1), SIMD3(0, 10, 0)],
            [SIMD3(5, 0, 1), SIMD3(5, 5, 2), SIMD3(5, 10, 1)],
            [SIMD3(10, 0, 0), SIMD3(10, 5, 1), SIMD3(10, 10, 0)],
        ])
    }

    @Test func nbPoles() {
        if let surf = makeBezierSurface() {
            let bp = surf.bezierProperties
            #expect(bp.nbUPoles >= 2)
            #expect(bp.nbVPoles >= 2)
        }
    }

    @Test func degree() {
        if let surf = makeBezierSurface() {
            let bp = surf.bezierProperties
            #expect(bp.uDegree >= 1)
            #expect(bp.vDegree >= 1)
        }
    }

    @Test func getPoleAndSet() {
        if let surf = makeBezierSurface() {
            let bp = surf.bezierProperties
            let p = bp.pole(uIndex: 1, vIndex: 1)
            // Should be a valid point
            #expect(p.x.isFinite)
            // Set it to a new value
            let ok = bp.setPole(uIndex: 1, vIndex: 1, point: SIMD3(1, 2, 3))
            #expect(ok)
            let p2 = bp.pole(uIndex: 1, vIndex: 1)
            #expect(abs(p2.x - 1.0) < 1e-10)
            #expect(abs(p2.y - 2.0) < 1e-10)
            #expect(abs(p2.z - 3.0) < 1e-10)
        }
    }

    @Test func rationalFlags() {
        if let surf = makeBezierSurface() {
            let bp = surf.bezierProperties
            // Non-rational by default
            #expect(!bp.isURational)
            #expect(!bp.isVRational)
        }
    }

    /// Which parametric axis each rationality flag actually reports on (#2976).
    ///
    /// `Geom_BezierSurface::IsURational()` is false when every ROW of the weight matrix is
    /// constant, a row being one U index across every V, so the flag is true exactly when the
    /// weights change as V advances. Each flag therefore names the axis opposite the one a reader
    /// supplies, and `Geom_BezierSurface.hxx` is no help: its prose says "identical in the U
    /// direction" while its example matrix is the BSpline page's, whose ROWS are the constant
    /// ones. The example is the behaviour, measured in
    /// `Scripts/repro/2976-surface-rational-axes/` and pinned here so the documented sentence
    /// has a test under it. Do not "correct" this pair.
    @Test func rationalFlagsReportTheOppositeAxis() throws {
        let varyingAlongU = try #require(makeBezierSurface()).bezierProperties
        // One weight per U row, each row constant: the weights vary with U, not with V.
        for v in 1...varyingAlongU.nbVPoles {
            varyingAlongU.setWeight(uIndex: 2, vIndex: v, weight: 0.5)
        }
        #expect(varyingAlongU.isURational == false)
        #expect(varyingAlongU.isVRational == true)

        let varyingAlongV = try #require(makeBezierSurface()).bezierProperties
        // The transpose: one weight per V column, each column constant.
        for u in 1...varyingAlongV.nbUPoles {
            varyingAlongV.setWeight(uIndex: u, vIndex: 2, weight: 0.5)
        }
        #expect(varyingAlongV.isURational == true)
        #expect(varyingAlongV.isVRational == false)
    }

    @Test func exchangeUV() {
        if let surf = makeBezierSurface() {
            let bp = surf.bezierProperties
            let uDeg = bp.uDegree
            let vDeg = bp.vDegree
            let ok = bp.exchangeUV()
            #expect(ok)
            #expect(bp.uDegree == vDeg)
            #expect(bp.vDegree == uDeg)
        }
    }
}
