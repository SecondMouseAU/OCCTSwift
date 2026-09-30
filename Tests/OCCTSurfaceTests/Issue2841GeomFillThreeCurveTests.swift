import Testing
import simd

@testable import OCCTSwift

// MARK: - #2841: the three-curve constructors of GeomFill_BSplineCurves / GeomFill_BezierCurves
//
// Both classes synthesise the missing fourth side as a straight two-pole segment between the FAR
// ends of C1 and C3, where "far" means the endpoint that does not meet C2
// (`GeomFill_BSplineCurves.cxx:396-439`, `GeomFill_BezierCurves.cxx:304-335`), then run the
// four-curve construction. So C2 is positionally the middle curve. A caller who puts one of the
// outer curves in that slot hands the four-curve `Init` a set that cannot close, and the refusal
// that would catch it is compiled out of this kernel: an uncatchable SIGSEGV, not a nil (#2842).
// `occtGeomFillThreeCurvesJoin` in `OCCTBridge_Surface_Fill.mm` restores it by synthesising the
// chord's two endpoints with the kernel's own two tests and running #2829's transcribed `Arrange`
// predicate over the resulting four.
//
// Evidence, including the three crashing sections and the 48-case agreement between the guard and
// the kernel: `Scripts/repro/2841/`.
//
// Every joining case is exercised on both supports #430 asks for: a planar boundary and a boundary
// on a periodic support (a quarter patch on a cylinder), because the crash reproduced on both.

@Suite("Issue 2841: GeomFill three-curve fills")
struct Issue2841GeomFillThreeCurveTests {

    /// A straight segment as a 4-pole Bezier. Four poles matter for the BSpline flavour: `.coons`
    /// refuses fewer than 4 poles per direction after knot alignment, a different refusal from
    /// the joining one under test.
    private func segment(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Curve3D? {
        let d = b - a
        return Curve3D.bezier(poles: [a, a + d / 3, a + d * (2.0 / 3.0), b])
    }

    /// The same segment as a bare two-pole degree-1 Bezier.
    private func flatSegment(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Curve3D? {
        Curve3D.bezier(poles: [a, b])
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

    // Three sides of a planar 10 x 10 square. The fourth, d -> a, is the synthesised chord.
    private let a = SIMD3<Double>(0, 0, 0)
    private let b = SIMD3<Double>(10, 0, 0)
    private let c = SIMD3<Double>(10, 10, 0)
    private let d = SIMD3<Double>(0, 10, 0)

    // MARK: - The canonical middle builds the patch the chord closes

    @Test("Three planar sides fill, in every style, and the chord closes the fourth side")
    func planarBSplineThreeSidesFill() throws {
        for style in [Surface.FillStyle.stretch, .coons, .curved] {
            let bottom = try #require(segment(a, b))
            let right = try #require(segment(b, c))
            let top = try #require(segment(c, d))
            let surface = try #require(
                Surface.bsplineFill(curves: (bottom, right, top), style: style),
                "style \(style) should fill three cubic sides")
            // All four corners of the square, so the chord is a real boundary rather than a
            // collapsed side: a three-curve fill is a four-sided patch with a straight side.
            #expect(closeEnough(corners(surface), [a, b, d, c]), "style \(style)")
        }
    }

    @Test("The Bezier flavour fills the same three sides, in every style")
    func planarBezierThreeSidesFill() throws {
        for style in [BezierFillStyle.stretch, .coons, .curved] {
            let bottom = try #require(segment(a, b))
            let right = try #require(segment(b, c))
            let top = try #require(segment(c, d))
            let surface = try #require(
                Surface.bezierFill(bottom, right, top, style: style),
                "style \(style) should fill three cubic sides")
            #expect(closeEnough(corners(surface), [a, b, d, c]), "style \(style)")
        }
    }

    // MARK: - A wrong middle is refused rather than crashing

    @Test("A wrong middle slot returns nil instead of crashing, both flavours, every style")
    func wrongMiddleRefused() throws {
        // (bottom, top, right): the top edge is adjacent to neither of the others' far ends, so
        // the synthesised chord is a -> b, which duplicates C1 and closes nothing. Before the
        // guard each of these lines was an uncatchable SIGSEGV (Scripts/repro/2841, [D] and [E]).
        for style in [Surface.FillStyle.stretch, .coons, .curved] {
            let bottom = try #require(segment(a, b))
            let right = try #require(segment(b, c))
            let top = try #require(segment(c, d))
            #expect(Surface.bsplineFill(curves: (bottom, top, right), style: style) == nil)
        }
        for style in [BezierFillStyle.stretch, .coons, .curved] {
            let bottom = try #require(segment(a, b))
            let right = try #require(segment(b, c))
            let top = try #require(segment(c, d))
            #expect(Surface.bezierFill(bottom, top, right, style: style) == nil)
        }
    }

    @Test("Three curves that form no chain at all are refused, both flavours")
    func noChainRefused() throws {
        let bottom = try #require(segment(a, b))
        let floating = try #require(segment(SIMD3(10, 0, 5), SIMD3(10, 10, 5)))
        let top = try #require(segment(c, d))
        #expect(Surface.bsplineFill(curves: (bottom, floating, top), style: .curved) == nil)

        let bottom2 = try #require(segment(a, b))
        let floating2 = try #require(segment(SIMD3(10, 0, 5), SIMD3(10, 10, 5)))
        let top2 = try #require(segment(c, d))
        #expect(Surface.bezierFill(bottom2, floating2, top2, style: .curved) == nil)
    }

    @Test("A wrong middle is refused on a periodic support too")
    func periodicWrongMiddleRefused() throws {
        let patch = try #require(cylinderPatch())
        // The seam belongs in the middle slot; putting the top arc there closes nothing.
        #expect(
            Surface.bsplineFill(curves: (patch.bottom, patch.top, patch.seam), style: .curved)
                == nil)
    }

    // MARK: - Direction is free, the middle slot is not

    @Test("All 8 direction combinations of the three curves give the same surface")
    func directionIndependence() throws {
        let refBottom = try #require(segment(a, b))
        let refRight = try #require(segment(b, c))
        let refTop = try #require(segment(c, d))
        let ref = try #require(
            Surface.bsplineFill(curves: (refBottom, refRight, refTop), style: .curved))
        let want = corners(ref)

        // One case list rather than @Test(arguments:), because an argument element pairing a
        // reference-counted member with a 32-byte builtin vector corrupts the Swift task
        // allocator (swiftlang/swift#91639); see CLAUDE.md's Test Conventions.
        let sides: [(SIMD3<Double>, SIMD3<Double>)] = [(a, b), (b, c), (c, d)]
        for flips in 0..<8 {
            var built: [Curve3D] = []
            for k in 0..<3 {
                let reversed = (flips >> k) & 1 == 1
                let s = sides[k]
                built.append(try #require(segment(reversed ? s.1 : s.0, reversed ? s.0 : s.1)))
            }
            let surface = try #require(
                Surface.bsplineFill(curves: (built[0], built[1], built[2]), style: .curved),
                "flips \(flips) should still fill")
            // curves.0's own direction becomes U, so a reversed C1 swaps the U ends. Compare the
            // corner SET rather than the ordered list.
            let got = corners(surface)
            for p in want {
                #expect(
                    got.contains(where: { simd_distance($0, p) < 1e-7 }),
                    "flips \(flips) lost corner \(p)")
            }
        }
    }

    // MARK: - Which styles are reachable, and why

    @Test("The synthesised side does not cap .coons; a low-degree middle curve does")
    func coonsReachability() throws {
        // Degrees are raised before knot distributions are aligned, so the two-pole chord is
        // lifted to the middle curve's degree first: three cubic sides give a 4 x 4 Coons surface.
        let bottom = try #require(segment(a, b))
        let right = try #require(segment(b, c))
        let top = try #require(segment(c, d))
        #expect(Surface.bsplineFill(curves: (bottom, right, top), style: .coons) != nil)

        // A two-pole MIDDLE curve leaves nothing to raise the chord to, so NbVPoles is 2 and the
        // kernel throws a real (catchable) Standard_ConstructionError the bridge turns into nil.
        let bottom2 = try #require(segment(a, b))
        let flatMiddle = try #require(flatSegment(b, c))
        let top2 = try #require(segment(c, d))
        #expect(Surface.bsplineFill(curves: (bottom2, flatMiddle, top2), style: .coons) == nil)
        // ...while the other two styles take it.
        let bottom3 = try #require(segment(a, b))
        let flatMiddle3 = try #require(flatSegment(b, c))
        let top3 = try #require(segment(c, d))
        #expect(Surface.bsplineFill(curves: (bottom3, flatMiddle3, top3), style: .stretch) != nil)

        // The Bezier flavour raises every side to at least degree 3 for Coons first, so the same
        // two-pole middle is no limit there.
        let bb = try #require(segment(a, b))
        let bflat = try #require(flatSegment(b, c))
        let bt = try #require(segment(c, d))
        #expect(Surface.bezierFill(bb, bflat, bt, style: .coons) != nil)
    }

    // MARK: - The periodic support

    @Test("Three boundaries on a periodic support fill, in every style")
    func periodicThreeSidesFill() throws {
        let patch = try #require(cylinderPatch())
        let surface = try #require(
            Surface.bsplineFill(curves: (patch.bottom, patch.seam, patch.top), style: .curved))
        let got = corners(surface)
        #expect(got.count == 4)
        for p in got {
            #expect(abs(simd_length(SIMD2<Double>(p.x, p.y)) - 5) < 1e-6)
        }

        // `.coons` reaches the same patch, which the raw kernel on the same three curves does
        // not: the bridge converts every input with `Convert_QuasiAngular`, which takes the
        // quarter arc from 3 poles to 7, so the Coons minimum of 4 per direction is met here and
        // is not met by OCCT's default conversion. Measured, Scripts/repro/2841 section [H].
        for style in [Surface.FillStyle.stretch, .coons] {
            let p = try #require(cylinderPatch())
            #expect(
                Surface.bsplineFill(curves: (p.bottom, p.seam, p.top), style: style) != nil,
                "style \(style) should fill the cylinder patch")
        }
    }

    private struct CylinderPatch {
        let bottom: Curve3D
        let seam: Curve3D
        let top: Curve3D
    }

    /// A quarter patch on a cylinder of radius 5 between z = 0 and z = 8, given as the bottom arc,
    /// one vertical seam and the top arc. The second seam is the synthesised chord.
    private func cylinderPatch() -> CylinderPatch? {
        let r = 5.0
        let s = r * 0.7071067811865476
        let p0 = SIMD3<Double>(r, 0, 0)
        let p1 = SIMD3<Double>(0, r, 0)
        let p2 = SIMD3<Double>(0, r, 8)
        let p3 = SIMD3<Double>(r, 0, 8)
        guard let bottom = Curve3D.arc(through: p0, SIMD3(s, s, 0), p1),
            let top = Curve3D.arc(through: p3, SIMD3(s, s, 8), p2),
            let seam = segment(p1, p2)
        else { return nil }
        return CylinderPatch(bottom: bottom, seam: seam, top: top)
    }
}
