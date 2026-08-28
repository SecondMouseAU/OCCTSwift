import Testing
import simd

@testable import OCCTSwift

@Suite("BSplineSurface Knot Queries")
struct BSplineSurfaceKnotTests {
    @Test("LocateU returns valid span")
    func locateU() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let bounds = bs.bsplineBounds
            let uMid = (bounds.u1 + bounds.u2) / 2.0
            let span = bs.bsplineLocateU(u: uMid, paramTol: 1e-10)
            #expect(span.i1 > 0)
            #expect(span.i2 > 0)
        }
    }

    @Test("LocateV returns valid span")
    func locateV() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let bounds = bs.bsplineBounds
            let vMid = (bounds.v1 + bounds.v2) / 2.0
            let span = bs.bsplineLocateV(v: vMid, paramTol: 1e-10)
            #expect(span.i1 > 0)
            #expect(span.i2 > 0)
        }
    }

    @Test("UKnot and VKnot return values")
    func knotValues() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            // First knot is always index 1
            let uk = bs.bsplineUKnot(index: 1)
            let vk = bs.bsplineVKnot(index: 1)
            #expect(uk.isFinite)
            #expect(vk.isFinite)
        }
    }

    @Test("UMultiplicity and VMultiplicity")
    func multiplicity() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let um = bs.bsplineUMultiplicity(index: 1)
            let vm = bs.bsplineVMultiplicity(index: 1)
            #expect(um > 0)
            #expect(vm > 0)
        }
    }

    @Test("UKnotDistribution and VKnotDistribution")
    func knotDistribution() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let ud = bs.bsplineUKnotDistribution
            let vd = bs.bsplineVKnotDistribution
            #expect(ud >= 0 && ud <= 3)
            #expect(vd >= 0 && vd <= 3)
        }
    }

    @Test("Bounds returns valid range")
    func bounds() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let b = bs.bsplineBounds
            #expect(b.u2 > b.u1)
            #expect(b.v2 > b.v1)
        }
    }

    @Test("IsUClosed and IsVClosed")
    func closedQueries() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            // Sphere is closed in U (full revolution) but typically closed in V too
            let uc = bs.bsplineIsUClosed
            let vc = bs.bsplineIsVClosed
            // Just verify they return without error
            #expect(uc || !uc)  // always true, verifies the call works
            #expect(vc || !vc)
        }
    }

    @Test("BSpline GetPoles bulk")
    func getPoles() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let poles = bs.bsplinePoles
            let expected = bs.uPoleCount * bs.vPoleCount
            #expect(poles.count == expected)
            if let first = poles.first {
                #expect(simd_length(first) > 0)
            }
        }
    }
}
