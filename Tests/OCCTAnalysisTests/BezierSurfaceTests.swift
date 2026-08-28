import Foundation
import Testing
import simd

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
