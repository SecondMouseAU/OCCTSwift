import Testing

@testable import OCCTSwift

@Suite("Surface Continuity Queries v0.120.0")
struct SurfaceContinuityQueriesTests {

    // #766: every test sat inside `if let s = makePlane()`, so a nil plane passed, and four
    // checked only non-nil, `isFinite`, or `>= 25`. They now pin the kernel's answers on the same
    // GC_MakePlane z = 0 plane, see Scripts/repro/766-surface-continuity/.
    // #2983: the plane answers `true` to every order, so a constant-true `isCNu` passed. The
    // continuity tests now also read a bicubic B-spline whose interior U knot multiplicity m
    // gives C(3 - m), where the answer flips from true to false at a measured order, and the
    // reversal tests read a surface whose reversed parameter is not just the negation.
    func makePlane() throws -> Surface {
        try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)), "plane")
    }

    @Test func isCNu() throws {
        let s = try makePlane()
        #expect(s.isCNu(0))
        #expect(s.isCNu(1))
        #expect(s.isCNu(2))
        // Interior knot multiplicity 1, 2, 3 is C2, C1, C0 in U (measured: true up to that order,
        // false from the next one).
        for (multiplicity, lastTrue) in [(Int32(1), 2), (2, 1), (3, 0)] {
            let b = try #require(makeContinuityBSplineSurface(interiorMultiplicityU: multiplicity))
            for n in 0...lastTrue { #expect(b.isCNu(n), "mult \(multiplicity) is C\(n) in U") }
            #expect(!b.isCNu(lastTrue + 1), "mult \(multiplicity) is not C\(lastTrue + 1) in U")
            // V carries no interior knot, so it stays smooth at every order asked.
            #expect(b.isCNv(lastTrue + 1))
        }
    }

    @Test func isCNv() throws {
        let s = try makePlane()
        #expect(s.isCNv(0))
        #expect(s.isCNv(1))
        #expect(s.isCNv(2))
        // `exchangeUV()` moves the interior knot from U to V, so the answers swap.
        for (multiplicity, lastTrue) in [(Int32(1), 2), (2, 1), (3, 0)] {
            let b = try #require(makeContinuityBSplineSurface(interiorMultiplicityU: multiplicity))
            b.bsplineSurface.exchangeUV()
            for n in 0...lastTrue { #expect(b.isCNv(n), "mult \(multiplicity) is C\(n) in V") }
            #expect(!b.isCNv(lastTrue + 1), "mult \(multiplicity) is not C\(lastTrue + 1) in V")
            #expect(b.isCNu(lastTrue + 1))
        }
    }

    @Test func uReversed() throws {
        let s = try makePlane()
        let rev = try #require(s.uReversed())
        // Reversing U maps (3, 4) to (-3, 4, 0).
        #expect(rev.point(atU: 3, v: 4) == SIMD3(-3, 4, 0))
        // On a curved surface the reversed point is the original at 1 - u (bounds are [0, 1]),
        // with v untouched.
        let b = try #require(makeContinuityBSplineSurface(interiorMultiplicityU: 1))
        let brev = try #require(b.uReversed())
        #expect(vectorLength(brev.point(atU: 0.25, v: 0.5) - b.point(atU: 0.75, v: 0.5)) < 1e-12)
        #expect(vectorLength(brev.point(atU: 0.25, v: 0.5) - b.point(atU: 0.25, v: 0.5)) > 0.1)
    }

    @Test func vReversed() throws {
        let s = try makePlane()
        let rev = try #require(s.vReversed())
        #expect(rev.point(atU: 3, v: 4) == SIMD3(3, -4, 0))
        let b = try #require(makeContinuityBSplineSurface(interiorMultiplicityU: 1))
        let brev = try #require(b.vReversed())
        #expect(vectorLength(brev.point(atU: 0.5, v: 0.25) - b.point(atU: 0.5, v: 0.75)) < 1e-12)
        #expect(vectorLength(brev.point(atU: 0.5, v: 0.25) - b.point(atU: 0.5, v: 0.25)) > 0.1)
    }

    @Test func uReversedParameter() throws {
        let s = try makePlane()
        // Was `isFinite`. A plane's reversed parameter is -u.
        #expect(s.uReversedParameter(0.5) == -0.5)
        // A B-spline on [0, 1] reverses to 1 - u, and a periodic cylinder to 2 pi - u.
        let b = try #require(makeContinuityBSplineSurface(interiorMultiplicityU: 1))
        #expect(abs(b.uReversedParameter(0.25) - 0.75) < 1e-12)
        let cyl = try #require(Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5))
        #expect(abs(cyl.uReversedParameter(1.0) - (2 * Double.pi - 1.0)) < 1e-12)
    }

    @Test func vReversedParameter() throws {
        let s = try makePlane()
        #expect(s.vReversedParameter(0.5) == -0.5)
        let b = try #require(makeContinuityBSplineSurface(interiorMultiplicityU: 1))
        #expect(abs(b.vReversedParameter(0.25) - 0.75) < 1e-12)
        // V on a cylinder is the axis, which is not periodic, so it reverses to -v and not to a
        // wrapped value.
        let cyl = try #require(Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5))
        #expect(cyl.vReversedParameter(2.0) == -2.0)
    }

    @Test func bezierMaxDegree() {
        let md = Surface.bezierMaxDegree
        #expect(md == 25)
    }

    @Test func bsplineMaxDegree() {
        let md = Surface.bsplineMaxDegree
        #expect(md == 25)
    }
}
