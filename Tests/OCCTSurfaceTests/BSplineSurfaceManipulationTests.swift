import Testing
import simd

@testable import OCCTSwift

@Suite("BSpline Surface Manipulation Tests")
struct BSplineSurfaceManipulationTests {

    // The fixture (a cylinder converted to BSpline form) lives in
    // `SurfaceTestFixtures.swift` as `makeCylinderDerivedBSplineSurface(radius:)`; see #1254.
    //
    // #766: until this change the fixture converted an UNTRIMMED cylinder, which
    // GeomConvert::SurfaceToBSplineSurface refuses ("infinite surface"), so it returned nil and
    // every test below skipped its whole body behind `if let bs`: not one expectation in this
    // suite had ever run. The fixture now trims V to [0, 10] first, and each test asserts the
    // surface exists. The trimmed cylinder's BSpline form has 4 x 2 knots, 6 x 2 poles, degree
    // 2 x 1, bounds [0, 2 pi] x [0, 10], and the kernel reports it rational in V only. Values are
    // Geom_BSplineSurface's own, see Scripts/repro/766-bspline-manipulation/.
    private func makeBSplineSurface() -> Surface? {
        let s = makeCylinderDerivedBSplineSurface()
        #expect(s != nil, "cylinder-derived BSpline fixture")
        return s
    }

    @Test func nbKnots() {
        if let bs = makeBSplineSurface() {
            let nuk = bs.bsplineSurface.nbUKnots
            let nvk = bs.bsplineSurface.nbVKnots
            #expect(nuk == 4)
            #expect(nvk == 2)
        }
    }

    @Test func nbPoles() {
        if let bs = makeBSplineSurface() {
            let nup = bs.bsplineSurface.nbUPoles
            let nvp = bs.bsplineSurface.nbVPoles
            #expect(nup == 6)
            #expect(nvp == 2)
        }
    }

    @Test func degree() {
        if let bs = makeBSplineSurface() {
            let uDeg = bs.bsplineSurface.uDegree
            let vDeg = bs.bsplineSurface.vDegree
            #expect(uDeg == 2)
            #expect(vDeg == 1)
        }
    }

    @Test func isRational() {
        if let bs = makeBSplineSurface() {
            // Was two discarded reads. Geom_BSplineSurface reports this conversion rational in V
            // and not in U.
            #expect(!bs.bsplineSurface.isURational)
            #expect(bs.bsplineSurface.isVRational)
        }
    }

    @Test func getPole() {
        if let bs = makeBSplineSurface() {
            // Was `let _ = p`. Pole (1, 1) is the seam point at radius 5 on the base.
            let p = bs.bsplineSurface.pole(uIndex: 1, vIndex: 1)
            #expect(p == SIMD3(5, 0, 0))
        }
    }

    @Test func setPole() {
        if let bs = makeBSplineSurface() {
            let ok = bs.bsplineSurface.setPole(uIndex: 1, vIndex: 1, to: SIMD3(10, 10, 10))
            #expect(ok)
            let p = bs.bsplineSurface.pole(uIndex: 1, vIndex: 1)
            #expect(p == SIMD3(10, 10, 10))
        }
    }

    @Test func exchangeUV() {
        if let bs = makeBSplineSurface() {
            let nupBefore = bs.bsplineSurface.nbUPoles
            let nvpBefore = bs.bsplineSurface.nbVPoles
            let ok = bs.bsplineSurface.exchangeUV()
            #expect(ok)
            #expect(bs.bsplineSurface.nbUPoles == nvpBefore)
            #expect(bs.bsplineSurface.nbVPoles == nupBefore)
            #expect(bs.bsplineSurface.uDegree == 1 && bs.bsplineSurface.vDegree == 2)
        }
    }

    @Test func insertUKnot() {
        if let bs = makeBSplineSurface() {
            let d = bs.domain
            let uMid = (d.uMin + d.uMax) / 2.0
            let ok = bs.bsplineSurface.insertUKnot(u: uMid)
            #expect(ok)
            // pi was not a knot, so it is added at multiplicity 1: 4 -> 5 knots.
            #expect(bs.bsplineSurface.nbUKnots == 5)
            #expect(bs.bsplineUMultiplicities == [2, 2, 1, 2, 2])
        }
    }

    @Test func insertVKnot() {
        if let bs = makeBSplineSurface() {
            let d = bs.domain
            let vMid = (d.vMin + d.vMax) / 2.0
            let ok = bs.bsplineSurface.insertVKnot(v: vMid)
            #expect(ok)
            #expect(bs.bsplineSurface.nbVKnots == 3)
            #expect(bs.bsplineVMultiplicities == [2, 1, 2])
        }
    }

    @Test func segment() {
        if let bs = makeBSplineSurface() {
            let d = bs.domain
            let u1 = d.uMin + (d.uMax - d.uMin) * 0.25
            let u2 = d.uMin + (d.uMax - d.uMin) * 0.75
            let v1 = d.vMin + (d.vMax - d.vMin) * 0.25
            let v2 = d.vMin + (d.vMax - d.vMin) * 0.75
            let ok = bs.bsplineSurface.segment(u1: u1, u2: u2, v1: v1, v2: v2)
            #expect(ok)
            // The surface is now just that patch.
            let after = bs.bsplineBounds
            #expect(abs(after.u1 - Double.pi / 2) < 1e-12 && abs(after.u2 - 3 * Double.pi / 2) < 1e-12)
            #expect(after.v1 == 2.5 && after.v2 == 7.5)
        }
    }

    @Test func increaseDegree() {
        if let bs = makeBSplineSurface() {
            let uDeg = bs.bsplineSurface.uDegree
            let vDeg = bs.bsplineSurface.vDegree
            let before = bs.point(atU: 1.0, v: 0.5)
            let ok = bs.bsplineSurface.increaseDegree(uDeg: uDeg + 1, vDeg: vDeg + 1)
            #expect(ok)
            #expect(bs.bsplineSurface.uDegree == uDeg + 1)
            #expect(bs.bsplineSurface.vDegree == vDeg + 1)
            // Degree elevation keeps the geometry.
            #expect(simd_length(bs.point(atU: 1.0, v: 0.5) - before) < 1e-12)
        }
    }

    @Test func setWeight() {
        if let bs = makeBSplineSurface() {
            // Was `let _ = ok`, "may or may not succeed". It succeeds and the weight lands.
            let ok = bs.bsplineSurface.setWeight(uIndex: 1, vIndex: 1, to: 2.0)
            #expect(ok)
            #expect(bs.bsplineWeight(uIndex: 1, vIndex: 1) == 2.0)
        }
    }
}
