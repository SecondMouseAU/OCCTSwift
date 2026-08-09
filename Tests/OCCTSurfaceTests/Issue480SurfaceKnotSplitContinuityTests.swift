import Testing
import simd
@testable import OCCTSwift

/// #480: `Surface.knotSplitting` took a raw `Int` documented as "0=C0, 1=C1, 2=C2", which on
/// ordinary bicubic geometry is a list of every value that does nothing.
/// `GeomConvert_BSplineSurfaceKnotSplitting` splits a knot only when
/// `degree - multiplicity < ContinuityRange`, so a cubic with simple interior knots is already
/// C2 there and ranges 0, 1 and 2 all return just the two bracketing knots. #398 established
/// this on curves and widened `Curve3D.continuityBreaks` to `ParametricContinuity`, whose `.c3`
/// is reachable; the surface and law siblings kept the old cap.
///
/// These cases pin the measured contract rather than the signature: the counts below would also
/// catch the opposite mistake of routing the enum through a GeomAbs_Shape decoder first, since
/// `GeomAbs_C2` is ordinal 4 and would split at every knot where `.c2` must split at none.
@Suite("Surface knot-splitting continuity range (#480)")
struct Issue480SurfaceKnotSplitContinuityTests {

    /// A BSpline surface of the given degree in both directions, with `interiorKnots` interior
    /// knots at multiplicity 1, except knot `bumpAt` (1-based), which gets `bumpMult`.
    private func bsplineSurface(degree: Int, interiorKnots: Int,
                                bumpAt: Int = 0, bumpMult: Int = 1) -> Surface? {
        var knots: [Double] = [0]
        var mults: [Int32] = [Int32(degree + 1)]
        for i in 1...interiorKnots {
            knots.append(Double(i))
            mults.append(Int32(i == bumpAt ? bumpMult : 1))
        }
        knots.append(Double(interiorKnots + 1))
        mults.append(Int32(degree + 1))

        let nPoles = Int(mults.reduce(0, +)) - degree - 1
        let poles = (0..<nPoles).map { u in
            (0..<nPoles).map { v in
                SIMD3<Double>(Double(u), Double(v), Double((u + v) % 3) * 0.5)
            }
        }
        return Surface.bspline(poles: poles,
                               knotsU: knots, multiplicitiesU: mults,
                               knotsV: knots, multiplicitiesV: mults,
                               degreeU: degree, degreeV: degree)
    }

    @Test("A bicubic surface with simple interior knots reports interior splits only at .c3")
    func cubicSimpleKnotsNeedC3() throws {
        let surface = try #require(bsplineSurface(degree: 3, interiorKnots: 4))
        let bounds = surface.domain

        // .c0/.c1/.c2: the surface is already C2 at every interior knot, so the only splits
        // are the two curves bounding each direction.
        for continuity: ParametricContinuity in [.c0, .c1, .c2] {
            let result = surface.knotSplitting(uContinuity: continuity, vContinuity: continuity)
            #expect(result.uSplitCount == 2, "u splits at \(continuity)")
            #expect(result.vSplitCount == 2, "v splits at \(continuity)")
            #expect(result.uSplitParams == [bounds.uMin, bounds.uMax])
            #expect(result.vSplitParams == [bounds.vMin, bounds.vMax])
        }

        // .c3 is the order that reaches a simple knot on a cubic: 4 interior + 2 bounds.
        let atC3 = surface.knotSplitting(uContinuity: .c3, vContinuity: .c3)
        #expect(atC3.uSplitCount == 6)
        #expect(atC3.vSplitCount == 6)
        #expect(atC3.uSplitParams == [0, 1, 2, 3, 4, 5])
        #expect(atC3.vSplitParams == [0, 1, 2, 3, 4, 5])
    }

    @Test("The .c1 default reports a real kink, which is why it stays the default")
    func defaultFindsGenuineKink() throws {
        // Multiplicity 3 on a cubic leaves continuity 3-3 = 0 at that knot: a genuine kink.
        let surface = try #require(bsplineSurface(degree: 3, interiorKnots: 4, bumpAt: 2, bumpMult: 3))

        let defaulted = surface.knotSplitting()
        #expect(defaulted.uSplitParams == [0, 2, 5])
        #expect(defaulted.vSplitParams == [0, 2, 5])

        // .c0 asks only for position, which the kink still satisfies.
        #expect(surface.knotSplitting(uContinuity: .c0, vContinuity: .c0).uSplitCount == 2)
        // .c3 still reports every interior knot, kink or not. That is a Bezier decomposition,
        // not a discontinuity report, which is why .c3 is not the default.
        #expect(surface.knotSplitting(uContinuity: .c3, vContinuity: .c3).uSplitCount == 6)
    }

    @Test("Each direction is asked independently")
    func directionsAreIndependent() throws {
        let surface = try #require(bsplineSurface(degree: 3, interiorKnots: 4))
        let mixed = surface.knotSplitting(uContinuity: .c3, vContinuity: .c1)
        #expect(mixed.uSplitCount == 6)
        #expect(mixed.vSplitCount == 2)
    }

    @Test("On a degree-5 surface .c3 is the strictest question this vocabulary can ask")
    func degreeFivePlusIsCappedAtC3() throws {
        // Documents the measured reach limit rather than asserting it is desirable: a degree-5
        // surface with simple interior knots is C4 there, so every order the enum can spell
        // answers "already continuous enough". `toBezierPatches()` is the every-knot split.
        let surface = try #require(bsplineSurface(degree: 5, interiorKnots: 4))
        for continuity in ParametricContinuity.allCases {
            #expect(surface.knotSplitting(uContinuity: continuity, vContinuity: continuity).uSplitCount == 2,
                    "u splits at \(continuity)")
        }
        #expect(surface.toBezierPatches().count == 25)
    }
}
