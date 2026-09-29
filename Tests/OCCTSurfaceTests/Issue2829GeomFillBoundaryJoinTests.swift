import Testing
import simd

@testable import OCCTSwift

// MARK: - #2829: GeomFill_BSplineCurves / GeomFill_BezierCurves arrange and refuse
//
// Both OCCT classes arrange four boundary curves themselves (a private `Arrange` walks them head to
// tail at `Precision::Confusion()`, swapping and reversing as needed) and refuse a set that does not
// join. The refusal is `Standard_ConstructionError_Raise_if`, which our Release kernel compiles out
// via `-DNo_Exception`, leaving `Init` to dereference a null handle: an uncatchable SIGSEGV, not a
// catchable exception. `occtGeomFillCurvesJoin` in `OCCTBridge_Surface_Fill.mm` restores the
// refusal by transcribing `Arrange`'s acceptance half.
//
// Evidence, including the crashes and the 384-case agreement between the transcribed predicate and
// the kernel: `Scripts/repro/2829-geomfill-arrange-guard/`.
//
// Every joining case here is exercised on BOTH supports #430 asks for: a planar boundary and a
// boundary on a periodic support (a quarter patch on a cylinder). The non-joining cases are too,
// because the crash reproduced on both.

@Suite("Issue 2829: GeomFill boundary joining")
struct Issue2829GeomFillBoundaryJoinTests {

    /// A straight segment as a 4-pole Bezier. Four poles matter: `.coons` refuses fewer than 4
    /// poles per direction after knot alignment (`GeomFill_BSplineCurves.cxx:300`), which is a
    /// different refusal from the joining one under test.
    private func segment(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Curve3D? {
        let d = b - a
        return Curve3D.bezier(poles: [a, a + d / 3, a + d * (2.0 / 3.0), b])
    }

    private func corners(_ s: Surface) -> [SIMD3<Double>] {
        let d = s.domain
        return [
            s.point(atU: d.uMin, v: d.vMin), s.point(atU: d.uMax, v: d.vMin),
            s.point(atU: d.uMin, v: d.vMax), s.point(atU: d.uMax, v: d.vMax),
        ]
    }

    private func closeEnough(_ a: [SIMD3<Double>], _ b: [SIMD3<Double>], _ tol: Double = 1e-7)
        -> Bool
    {
        guard a.count == b.count else { return false }
        return zip(a, b).allSatisfy { simd_distance($0, $1) < tol }
    }

    // The planar square, as four separate edges of a closed loop.
    private let a = SIMD3<Double>(0, 0, 0)
    private let b = SIMD3<Double>(10, 0, 0)
    private let c = SIMD3<Double>(10, 10, 0)
    private let d = SIMD3<Double>(0, 10, 0)

    // MARK: - Non-joining input is refused rather than crashing

    @Test("A non-joining BSpline set returns nil instead of crashing, on a planar boundary")
    func planarBSplineNonJoiningRefused() throws {
        // The top edge lifted to z = 5, so neither of its ends meets any other corner.
        let lifted1 = SIMD3<Double>(10, 10, 5)
        let lifted2 = SIMD3<Double>(0, 10, 5)
        let bottom = try #require(segment(a, b))
        let right = try #require(segment(b, c))
        let top = try #require(segment(lifted1, lifted2))
        let left = try #require(segment(d, a))

        // Before the guard this line was an uncatchable SIGSEGV, not a nil.
        for style in [Surface.FillStyle.stretch, .coons, .curved] {
            #expect(Surface.bsplineFill(curves: (bottom, right, top, left), style: style) == nil)
        }
    }

    @Test("A non-joining Bezier set returns nil instead of crashing, on a planar boundary")
    func planarBezierNonJoiningRefused() throws {
        let lifted1 = SIMD3<Double>(10, 10, 5)
        let lifted2 = SIMD3<Double>(0, 10, 5)
        let bottom = try #require(segment(a, b))
        let right = try #require(segment(b, c))
        let top = try #require(segment(lifted1, lifted2))
        let left = try #require(segment(d, a))

        for style in [BezierFillStyle.stretch, .coons, .curved] {
            #expect(Surface.bezierFill(bottom, right, top, left, style: style) == nil)
        }
    }

    @Test("A non-joining set on a periodic support returns nil instead of crashing")
    func periodicNonJoiningRefused() throws {
        let patch = try #require(cylinderPatch())
        // Push the top arc's far end off the seam by 12 in z: no corner meets it.
        let strayTop = try #require(segment(SIMD3(5, 0, 20), SIMD3(0, 5, 8)))

        #expect(
            Surface.bsplineFill(
                curves: (patch.bottom, patch.left, strayTop, patch.right), style: .curved) == nil)
        #expect(
            Surface.bezierFill(patch.bottomSeg, patch.left, strayTop, patch.right, style: .curved)
                == nil)
    }

    // MARK: - Joining input is still accepted, in any order and any direction

    @Test("Arrange reorders and reverses: a scrambled planar square gives the same surface")
    func planarScrambledOrderAcceptedAndEqual() throws {
        let ab = try #require(segment(a, b))
        let bc = try #require(segment(b, c))
        let cd = try #require(segment(c, d))
        let da = try #require(segment(d, a))
        let canonical = try #require(
            Surface.bsplineFill(curves: (ab, bc, cd, da), style: .coons))

        // The same four edges, slots scrambled and three of the four reversed. `Arrange` fixes
        // both, so the result must be corner-for-corner the canonical one. This is what makes the
        // guard's fidelity observable: a check stricter than `Arrange` would refuse this.
        let ab2 = try #require(segment(a, b))
        let dc = try #require(segment(d, c))
        let ad = try #require(segment(a, d))
        let cb = try #require(segment(c, b))
        let scrambled = try #require(
            Surface.bsplineFill(curves: (ab2, dc, ad, cb), style: .coons))

        #expect(closeEnough(corners(canonical), corners(scrambled)))
        // ...and it is the flat square, not some other patch.
        #expect(closeEnough(corners(canonical), [a, b, d, c]))
    }

    @Test("A joining boundary on a periodic support is still filled")
    func periodicJoiningAccepted() throws {
        let patch = try #require(cylinderPatch())

        // `.curved` rather than `.coons`: the arc converts to a 3-pole BSpline and `.coons` refuses
        // fewer than 4 poles per direction, which the measured transcript records as a
        // Standard_ConstructionError the bridge already turned into nil.
        let surface = try #require(
            Surface.bsplineFill(
                curves: (patch.bottom, patch.left, patch.top, patch.right), style: .curved))
        let got = corners(surface)
        #expect(got.count == 4)
        // Every corner sits on the cylinder of radius 5.
        for p in got {
            #expect(abs(simd_length(SIMD2<Double>(p.x, p.y)) - 5) < 1e-6)
        }
    }

    @Test("A side collapsed to a point is accepted, as Arrange's degenerate pre-pass allows")
    func degenerateSideAccepted() throws {
        // A triangular patch written as four sides with one collapsed onto the corner c.
        let s1 = try #require(segment(a, b))
        let s2 = try #require(segment(b, c))
        let s3 = try #require(Curve3D.bezier(poles: [c, c, c, c]))
        let s4 = try #require(segment(c, a))

        #expect(Surface.bsplineFill(curves: (s1, s2, s3, s4), style: .curved) != nil)
    }

    @Test("The joining tolerance is Precision::Confusion(), not looser and not tighter")
    func toleranceBoundary() throws {
        // One case list rather than @Test(arguments:), because an argument element pairing a
        // reference-counted member with a 32-byte builtin vector corrupts the Swift task allocator
        // (swiftlang/swift#91639); see CLAUDE.md's Test Conventions.
        let cases: [(gap: Double, joins: Bool)] = [
            (0.0, true), (5e-8, true), (9.9e-8, true), (2e-7, false), (1e-6, false),
        ]
        for one in cases {
            let shifted = SIMD3<Double>(10, 10 + one.gap, 0)
            let bottom = try #require(segment(a, b))
            let right = try #require(segment(b, shifted))
            let top = try #require(segment(c, d))
            let left = try #require(segment(d, a))
            let surface = Surface.bsplineFill(curves: (bottom, right, top, left), style: .curved)
            #expect(
                (surface != nil) == one.joins,
                "gap \(one.gap) should \(one.joins ? "join" : "not join")")
        }
    }

    @Test("The two-curve fill needs no guard, and .curved is the one style that refuses a pair")
    func twoCurveContract() throws {
        // The two-curve Init runs no Arrange, and its .curved branch refuses a disjoint pair with a
        // real `throw Standard_OutOfRange` (GeomFill_BSplineCurves.cxx:545) that No_Exception leaves
        // alone, so the bridge already turned it into nil. Pinned because the wrapper defaults to
        // .coons, which accepts the same pair, and nothing said so.
        let along = try #require(
            Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(5, 0, 2), SIMD3(10, 0, 0)]))
        let apart = try #require(
            Curve3D.interpolate(points: [SIMD3(0, 10, 0), SIMD3(5, 10, 2), SIMD3(10, 10, 0)]))

        #expect(Surface.bsplineFill(curve1: along, curve2: apart, style: .stretch) != nil)
        #expect(Surface.bsplineFill(curve1: along, curve2: apart, style: .coons) != nil)
        #expect(Surface.bsplineFill(curve1: along, curve2: apart, style: .curved) == nil)

        // ...and a pair that does share a start point is accepted by .curved.
        let meeting = try #require(
            Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(0, 5, 2), SIMD3(0, 10, 0)]))
        #expect(Surface.bsplineFill(curve1: along, curve2: meeting, style: .curved) != nil)
    }

    // MARK: - The periodic support

    private struct CylinderPatch {
        let bottom: Curve3D
        let top: Curve3D
        let left: Curve3D
        let right: Curve3D
        /// The bottom arc again, as a Bezier, for the `bezierFill` half of the periodic case.
        let bottomSeg: Curve3D
    }

    /// A quarter patch on a cylinder of radius 5 between z = 0 and z = 8: two arcs on the periodic
    /// support plus two vertical seams.
    private func cylinderPatch() -> CylinderPatch? {
        let r = 5.0
        let s = r * 0.7071067811865476
        let p0 = SIMD3<Double>(r, 0, 0)
        let p1 = SIMD3<Double>(0, r, 0)
        let p2 = SIMD3<Double>(0, r, 8)
        let p3 = SIMD3<Double>(r, 0, 8)
        guard let bottom = Curve3D.arc(through: p0, SIMD3(s, s, 0), p1),
            let top = Curve3D.arc(through: p3, SIMD3(s, s, 8), p2),
            let left = segment(p1, p2),
            let right = segment(p3, p0),
            let bottomSeg = Curve3D.bezier(poles: [
                p0, SIMD3(r, s * 0.5, 0), SIMD3(s * 0.5, r, 0), p1,
            ])
        else { return nil }
        return CylinderPatch(
            bottom: bottom, top: top, left: left, right: right, bottomSeg: bottomSeg)
    }
}
