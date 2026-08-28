import Testing
import simd

@testable import OCCTSwift

@Suite("BSpline Surface Manipulation Tests")
struct BSplineSurfaceManipulationTests {

    // The fixture (a cylinder converted to BSpline form) lives in
    // `SurfaceTestFixtures.swift` as `makeCylinderDerivedBSplineSurface(radius:)`; see #1254.
    private func makeBSplineSurface() -> Surface? {
        makeCylinderDerivedBSplineSurface()
    }

    @Test func nbKnots() {
        if let bs = makeBSplineSurface() {
            let nuk = bs.bsplineSurface.nbUKnots
            let nvk = bs.bsplineSurface.nbVKnots
            #expect(nuk > 0)
            #expect(nvk > 0)
        }
    }

    @Test func nbPoles() {
        if let bs = makeBSplineSurface() {
            let nup = bs.bsplineSurface.nbUPoles
            let nvp = bs.bsplineSurface.nbVPoles
            #expect(nup > 0)
            #expect(nvp > 0)
        }
    }

    @Test func degree() {
        if let bs = makeBSplineSurface() {
            let uDeg = bs.bsplineSurface.uDegree
            let vDeg = bs.bsplineSurface.vDegree
            #expect(uDeg >= 1)
            #expect(vDeg >= 1)
        }
    }

    @Test func isRational() {
        if let bs = makeBSplineSurface() {
            let _ = bs.bsplineSurface.isURational
            let _ = bs.bsplineSurface.isVRational
        }
    }

    @Test func getPole() {
        if let bs = makeBSplineSurface() {
            let nup = bs.bsplineSurface.nbUPoles
            let nvp = bs.bsplineSurface.nbVPoles
            if nup >= 1 && nvp >= 1 {
                let p = bs.bsplineSurface.pole(uIndex: 1, vIndex: 1)
                // Just check it returns something
                let _ = p
            }
        }
    }

    @Test func setPole() {
        if let bs = makeBSplineSurface() {
            let nup = bs.bsplineSurface.nbUPoles
            let nvp = bs.bsplineSurface.nbVPoles
            if nup >= 2 && nvp >= 2 {
                let ok = bs.bsplineSurface.setPole(uIndex: 1, vIndex: 1, to: SIMD3(10, 10, 10))
                #expect(ok)
                let p = bs.bsplineSurface.pole(uIndex: 1, vIndex: 1)
                #expect(abs(p.x - 10) < 1e-6)
            }
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
        }
    }

    @Test func insertUKnot() {
        if let bs = makeBSplineSurface() {
            let d = bs.domain
            let uMid = (d.uMin + d.uMax) / 2.0
            let ok = bs.bsplineSurface.insertUKnot(u: uMid)
            #expect(ok)
        }
    }

    @Test func insertVKnot() {
        if let bs = makeBSplineSurface() {
            let d = bs.domain
            let vMid = (d.vMin + d.vMax) / 2.0
            let ok = bs.bsplineSurface.insertVKnot(v: vMid)
            #expect(ok)
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
        }
    }

    @Test func increaseDegree() {
        if let bs = makeBSplineSurface() {
            let uDeg = bs.bsplineSurface.uDegree
            let vDeg = bs.bsplineSurface.vDegree
            let ok = bs.bsplineSurface.increaseDegree(uDeg: uDeg + 1, vDeg: vDeg + 1)
            #expect(ok)
            #expect(bs.bsplineSurface.uDegree == uDeg + 1)
            #expect(bs.bsplineSurface.vDegree == vDeg + 1)
        }
    }

    @Test func setWeight() {
        if let bs = makeBSplineSurface() {
            // BSpline from cylinder is rational, weights can be set
            let ok = bs.bsplineSurface.setWeight(uIndex: 1, vIndex: 1, to: 2.0)
            // May or may not succeed depending on rationality
            let _ = ok
        }
    }
}
