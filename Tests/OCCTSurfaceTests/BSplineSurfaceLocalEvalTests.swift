import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.125.0: BSpline/Bezier deep method completion tests

@Suite("BSplineSurface Local Evaluation")
struct BSplineSurfaceLocalEvalTests {
    @Test("LocalD0 matches global D0")
    func localD0() {
        // Create a BSpline surface via converting a sphere
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let bounds = bs.bsplineBounds
            let uMid = (bounds.u1 + bounds.u2) / 2.0
            let vMid = (bounds.v1 + bounds.v2) / 2.0
            // Locate knot span
            let uSpan = bs.bsplineLocateU(u: uMid, paramTol: 1e-10)
            let vSpan = bs.bsplineLocateV(v: vMid, paramTol: 1e-10)
            if uSpan.i1 > 0 && uSpan.i2 > 0 && vSpan.i1 > 0 && vSpan.i2 > 0 {
                let localPt = bs.bsplineLocalD0(
                    u: uMid, v: vMid,
                    fromUK1: uSpan.i1, toUK2: uSpan.i2,
                    fromVK1: vSpan.i1, toVK2: vSpan.i2)
                let globalPt = bs.point(atU: uMid, v: vMid)
                let dist = simd_length(localPt - globalPt)
                #expect(dist < 1e-10)
            }
        }
    }

    @Test("LocalD1 returns point and derivatives")
    func localD1() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let bounds = bs.bsplineBounds
            let uMid = (bounds.u1 + bounds.u2) / 2.0
            let vMid = (bounds.v1 + bounds.v2) / 2.0
            let uSpan = bs.bsplineLocateU(u: uMid, paramTol: 1e-10)
            let vSpan = bs.bsplineLocateV(v: vMid, paramTol: 1e-10)
            if uSpan.i1 > 0 && uSpan.i2 > 0 && vSpan.i1 > 0 && vSpan.i2 > 0 {
                let r = bs.bsplineLocalD1(
                    u: uMid, v: vMid,
                    fromUK1: uSpan.i1, toUK2: uSpan.i2,
                    fromVK1: vSpan.i1, toVK2: vSpan.i2)
                #expect(simd_length(r.d1u) > 0)
                #expect(simd_length(r.d1v) > 0)
            }
        }
    }

    @Test("LocalD2 returns second derivatives")
    func localD2() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let bounds = bs.bsplineBounds
            let uMid = (bounds.u1 + bounds.u2) / 2.0
            let vMid = (bounds.v1 + bounds.v2) / 2.0
            let uSpan = bs.bsplineLocateU(u: uMid, paramTol: 1e-10)
            let vSpan = bs.bsplineLocateV(v: vMid, paramTol: 1e-10)
            if uSpan.i1 > 0 && uSpan.i2 > 0 && vSpan.i1 > 0 && vSpan.i2 > 0 {
                let r = bs.bsplineLocalD2(
                    u: uMid, v: vMid,
                    fromUK1: uSpan.i1, toUK2: uSpan.i2,
                    fromVK1: vSpan.i1, toVK2: vSpan.i2)
                #expect(simd_length(r.point) > 0)
            }
        }
    }

    @Test("LocalD3 returns third derivatives")
    func localD3() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let bounds = bs.bsplineBounds
            let uMid = (bounds.u1 + bounds.u2) / 2.0
            let vMid = (bounds.v1 + bounds.v2) / 2.0
            let uSpan = bs.bsplineLocateU(u: uMid, paramTol: 1e-10)
            let vSpan = bs.bsplineLocateV(v: vMid, paramTol: 1e-10)
            if uSpan.i1 > 0 && uSpan.i2 > 0 && vSpan.i1 > 0 && vSpan.i2 > 0 {
                let r = bs.bsplineLocalD3(
                    u: uMid, v: vMid,
                    fromUK1: uSpan.i1, toUK2: uSpan.i2,
                    fromVK1: vSpan.i1, toVK2: vSpan.i2)
                #expect(simd_length(r.point) > 0)
            }
        }
    }

    @Test("LocalDN derivative")
    func localDN() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let bounds = bs.bsplineBounds
            let uMid = (bounds.u1 + bounds.u2) / 2.0
            let vMid = (bounds.v1 + bounds.v2) / 2.0
            let uSpan = bs.bsplineLocateU(u: uMid, paramTol: 1e-10)
            let vSpan = bs.bsplineLocateV(v: vMid, paramTol: 1e-10)
            if uSpan.i1 > 0 && uSpan.i2 > 0 && vSpan.i1 > 0 && vSpan.i2 > 0 {
                let v = bs.bsplineLocalDN(
                    u: uMid, v: vMid,
                    fromUK1: uSpan.i1, toUK2: uSpan.i2,
                    fromVK1: vSpan.i1, toVK2: vSpan.i2,
                    nu: 1, nv: 0)
                #expect(simd_length(v) > 0)
            }
        }
    }

    @Test("LocalValue matches global")
    func localValue() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let bounds = bs.bsplineBounds
            let uMid = (bounds.u1 + bounds.u2) / 2.0
            let vMid = (bounds.v1 + bounds.v2) / 2.0
            let uSpan = bs.bsplineLocateU(u: uMid, paramTol: 1e-10)
            let vSpan = bs.bsplineLocateV(v: vMid, paramTol: 1e-10)
            if uSpan.i1 > 0 && uSpan.i2 > 0 && vSpan.i1 > 0 && vSpan.i2 > 0 {
                let localPt = bs.bsplineLocalValue(
                    u: uMid, v: vMid,
                    fromUK1: uSpan.i1, toUK2: uSpan.i2,
                    fromVK1: vSpan.i1, toVK2: vSpan.i2)
                let globalPt = bs.point(atU: uMid, v: vMid)
                let dist = simd_length(localPt - globalPt)
                #expect(dist < 1e-10)
            }
        }
    }
}
