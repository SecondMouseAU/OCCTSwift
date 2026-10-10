import Testing

@testable import OCCTSwift

@Suite("BSplineSurface KnotSplitting Tests")
struct BSplineSurfaceKnotSplitTests {

    @Test func knotSplitsU() {
        // Create a sphere surface and convert to BSpline
        // #766: `n >= 0` held for any Int, inside two `if let`s. GeomConvert's sphere BSpline has
        // U knots 0, 2pi/3, 4pi/3, 2pi (all x2, degree 2) and V knots -pi/2, 0, pi/2 (x3, x2, x3):
        // at C0 the kernel splits only at the two ends in each direction; asking for C1 adds the
        // two interior U knots and the V knot at 0, which are only C0. Values from
        // GeomConvert_BSplineSurfaceKnotSplitting, see Scripts/repro/766-bspline-extras-fill-iso/.
        let bsp = Surface.sphere(center: .zero, radius: 5)?.toBSpline()
        #expect(bsp != nil)
        if let bsp {
            // #562: was bsplineKnotSplitsU, now deprecated onto this one analyzer call.
            let c0 = bsp.knotSplitting(uContinuity: .c0, vContinuity: .c0)
            #expect(c0.uSplitCount == 2)
            #expect(c0.vSplitCount == 2)
            let c1 = bsp.knotSplitting(uContinuity: .c1, vContinuity: .c1)
            #expect(c1.uSplitCount == 4)
            #expect(c1.vSplitCount == 3)
        }
    }
}
