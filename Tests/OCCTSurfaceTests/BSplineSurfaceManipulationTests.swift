import Testing
import simd

@testable import OCCTSwift

// Lifted from #2464 on `v5.0.0-766-execution`, re-measured against `main`'s kernel.
//
// #766: until this change the fixture converted an UNTRIMMED cylinder, which
// `GeomConvert::SurfaceToBSplineSurface` refuses ("infinite surface"), so it returned nil and
// every test below skipped its whole body behind `if let bs`: not one expectation in this suite
// had ever run. The fixture now trims V to [0, 10] first, and the surface is `#require`d rather
// than bound with `if let`, so a fixture that stops building fails the suite instead of
// silencing it.
//
// The trimmed cylinder's BSpline form has 4 x 2 knots, 6 x 2 poles, degree 2 x 1 and bounds
// [0, 2 pi] x [0, 10]. Every expected value below is `Geom_BSplineSurface`'s own, measured in
// `Scripts/repro/766-bspline-manipulation/`.
@Suite("BSpline Surface Manipulation Tests")
struct BSplineSurfaceManipulationTests {

    // The fixture (a trimmed cylinder converted to BSpline form) lives in
    // `SurfaceTestFixtures.swift` as `makeCylinderDerivedBSplineSurface(radius:)`; see #1254.
    private func makeBSplineSurface() throws -> Surface {
        try #require(makeCylinderDerivedBSplineSurface(), "cylinder-derived BSpline fixture")
    }

    @Test func nbKnots() throws {
        let bs = try makeBSplineSurface()
        #expect(bs.bsplineSurface.nbUKnots == 4)
        #expect(bs.bsplineSurface.nbVKnots == 2)
    }

    @Test func nbPoles() throws {
        let bs = try makeBSplineSurface()
        #expect(bs.bsplineSurface.nbUPoles == 6)
        #expect(bs.bsplineSurface.nbVPoles == 2)
    }

    @Test func degree() throws {
        let bs = try makeBSplineSurface()
        #expect(bs.bsplineSurface.uDegree == 2)
        #expect(bs.bsplineSurface.vDegree == 1)
    }

    /// Was two discarded reads. The kernel's answer looks inverted and is not: OCCT defines
    /// `IsURational()` as "False if for each ROW of weights all the weights are identical"
    /// (`Geom_BSplineSurface.hxx`), a row being one U index across every V. A cylinder's weights
    /// are the circle's, constant down each row and varying across each column, so the exact
    /// answer is U non-rational and V rational. Do not "correct" this pair.
    @Test func isRational() throws {
        let bs = try makeBSplineSurface()
        #expect(!bs.bsplineSurface.isURational)
        #expect(bs.bsplineSurface.isVRational)
    }

    @Test func getPole() throws {
        let bs = try makeBSplineSurface()
        // Was `let _ = p`. Pole (1, 1) is the seam point at radius 5 on the base.
        #expect(bs.bsplineSurface.pole(uIndex: 1, vIndex: 1) == SIMD3(5, 0, 0))
        #expect(bs.bsplineWeight(uIndex: 1, vIndex: 1) == 1.0)
    }

    @Test func setPole() throws {
        let bs = try makeBSplineSurface()
        #expect(bs.bsplineSurface.setPole(uIndex: 1, vIndex: 1, to: SIMD3(10, 10, 10)))
        // Was `abs(p.x - 10) < 1e-6`, which said nothing about y or z.
        #expect(bs.bsplineSurface.pole(uIndex: 1, vIndex: 1) == SIMD3(10, 10, 10))
    }

    @Test func exchangeUV() throws {
        let bs = try makeBSplineSurface()
        let nupBefore = bs.bsplineSurface.nbUPoles
        let nvpBefore = bs.bsplineSurface.nbVPoles
        #expect(bs.bsplineSurface.exchangeUV())
        #expect(bs.bsplineSurface.nbUPoles == nvpBefore)
        #expect(bs.bsplineSurface.nbVPoles == nupBefore)
        #expect(bs.bsplineSurface.uDegree == 1)
        #expect(bs.bsplineSurface.vDegree == 2)
        // The rationality flags swap with the directions they describe.
        #expect(bs.bsplineSurface.isURational)
        #expect(!bs.bsplineSurface.isVRational)
        let after = bs.bsplineBounds
        #expect(after.u1 == 0 && after.u2 == 10)
    }

    @Test func insertUKnot() throws {
        let bs = try makeBSplineSurface()
        let d = bs.domain
        let uMid = (d.uMin + d.uMax) / 2.0
        #expect(bs.bsplineSurface.insertUKnot(u: uMid))
        // pi falls inside a 120-degree arc and was not a knot, so it is added at
        // multiplicity 1: 4 -> 5 knots, and the periodic pole count rises by one.
        #expect(bs.bsplineSurface.nbUKnots == 5)
        #expect(bs.bsplineUMultiplicities == [2, 2, 1, 2, 2])
        #expect(bs.bsplineSurface.nbUPoles == 7)
    }

    @Test func insertVKnot() throws {
        let bs = try makeBSplineSurface()
        let d = bs.domain
        let vMid = (d.vMin + d.vMax) / 2.0
        #expect(bs.bsplineSurface.insertVKnot(v: vMid))
        #expect(bs.bsplineSurface.nbVKnots == 3)
        #expect(bs.bsplineVMultiplicities == [2, 1, 2])
    }

    @Test func segment() throws {
        let bs = try makeBSplineSurface()
        let d = bs.domain
        let u1 = d.uMin + (d.uMax - d.uMin) * 0.25
        let u2 = d.uMin + (d.uMax - d.uMin) * 0.75
        let v1 = d.vMin + (d.vMax - d.vMin) * 0.25
        let v2 = d.vMin + (d.vMax - d.vMin) * 0.75
        #expect(bs.bsplineSurface.segment(u1: u1, u2: u2, v1: v1, v2: v2))
        // The surface is now just that patch.
        let after = bs.bsplineBounds
        #expect(abs(after.u1 - Double.pi / 2) < 1e-12)
        #expect(abs(after.u2 - 3 * Double.pi / 2) < 1e-12)
        #expect(after.v1 == 2.5 && after.v2 == 7.5)
        #expect(bs.bsplineSurface.nbUPoles == 7)
        #expect(bs.bsplineSurface.nbVPoles == 2)
    }

    @Test func increaseDegree() throws {
        let bs = try makeBSplineSurface()
        let before = bs.point(atU: 1.0, v: 0.5)
        #expect(bs.bsplineSurface.increaseDegree(uDeg: 3, vDeg: 2))
        #expect(bs.bsplineSurface.uDegree == 3)
        #expect(bs.bsplineSurface.vDegree == 2)
        #expect(bs.bsplineSurface.nbUPoles == 9)
        #expect(bs.bsplineSurface.nbVPoles == 3)
        // Degree elevation keeps the geometry.
        #expect(simd_length(bs.point(atU: 1.0, v: 0.5) - before) < 1e-12)
    }

    @Test func setWeight() throws {
        let bs = try makeBSplineSurface()
        // Was `let _ = ok`, "may or may not succeed". It succeeds, the weight lands, and the
        // surface becomes rational in the direction it was not.
        #expect(bs.bsplineSurface.setWeight(uIndex: 1, vIndex: 1, to: 2.0))
        #expect(bs.bsplineWeight(uIndex: 1, vIndex: 1) == 2.0)
        #expect(bs.bsplineSurface.isURational)
        #expect(bs.bsplineSurface.isVRational)
    }
}
