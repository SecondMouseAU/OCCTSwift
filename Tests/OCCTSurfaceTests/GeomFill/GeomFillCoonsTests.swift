import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill Coons")
struct GeomFillCoonsTests {
    /// The four sides of a flat 10 x 10 square in the z = 0 plane, as five points each.
    /// `bottom` and `top` are indexed along x, `left` and `right` along y.
    static func squareSides() -> (
        bottom: [SIMD3<Double>], top: [SIMD3<Double>], left: [SIMD3<Double>],
        right: [SIMD3<Double>]
    ) {
        let n = 5
        var bottom = [SIMD3<Double>]()
        var top = [SIMD3<Double>]()
        var left = [SIMD3<Double>]()
        var right = [SIMD3<Double>]()
        for i in 0..<n {
            let t = Double(i) / Double(n - 1)
            bottom.append(SIMD3(t * 10, 0, 0))
            top.append(SIMD3(t * 10, 10, 0))
            left.append(SIMD3(0, t * 10, 0))
            right.append(SIMD3(10, t * 10, 0))
        }
        return (bottom, top, left, right)
    }

    @Test("Coons filling from boundaries")
    func coonsFilling() throws {
        let s = Self.squareSides()
        let result = try #require(
            Shape.coonsFilling(
                boundary1: s.bottom, boundary2: s.top, boundary3: s.left, boundary4: s.right))
        // #766: `> 0` passed any grid. GeomFill_Coons on the same four rows gives 5 x 5 poles.
        // These are the kernel's own values for these inputs and they are NOT a flat square's.
        // GeomFill_Coons::Init reads P1/P3 as the two boundaries indexed along U and P2/P4 as the
        // two indexed along V, with the corners required to agree; this fixture passes
        // (bottom, top, left, right), so `top` arrives where the left column belongs and its first
        // point overwrites the square's (0, 0, 0) corner with (0, 10, 0). Read poles[8] below as
        // the kernel's answer to a mis-ordered call, not as square geometry. `correctArrangement`
        // below passes the same four rows in the order Init wants and pins the square's own grid,
        // so the two tests together bracket the arrangement rather than just recording it (#2795).
        // Transcripts: Scripts/repro/766-geomfill-a/ and
        // Scripts/repro/2795-geomfill-boundary-arrangement/.
        #expect(result.nbU == 5)
        #expect(result.nbV == 5)
        try #require(result.poles.count == 25)
        #expect(simd_length(result.poles[0] - SIMD3(0, 10, 0)) < 1e-9)
        #expect(simd_length(result.poles[8] - SIMD3(-2.5, 2.5, 0)) < 1e-9)
        #expect(simd_length(result.poles[24] - SIMD3(10, 10, 0)) < 1e-9)
    }

    /// #2795: the same four rows in the arrangement `GeomFill_Coons::Init` actually wants, which is
    /// (bottom, left, top, right): the two boundaries indexed along U in slots 1 and 3, the two
    /// indexed along V in slots 2 and 4.
    ///
    /// A flat square then gives its own uniform 5 x 5 grid, every
    /// pole on the square, which is a claim the fixture above cannot make. Any reordering of the
    /// four arguments breaks at least one pole here.
    @Test("the arrangement Init wants gives the flat square's own uniform grid")
    func correctArrangement() throws {
        let s = Self.squareSides()
        let result = try #require(
            Shape.coonsFilling(
                boundary1: s.bottom, boundary2: s.left, boundary3: s.top, boundary4: s.right))
        #expect(result.nbU == 5)
        #expect(result.nbV == 5)
        try #require(result.poles.count == 25)
        // Row-major in U, V varying fastest: pole (u, v) is at u * nbV + v.
        for u in 0..<5 {
            for v in 0..<5 {
                let expected = SIMD3<Double>(Double(u) * 2.5, Double(v) * 2.5, 0)
                #expect(
                    simd_length(result.poles[u * 5 + v] - expected) < 1e-9,
                    "pole (\(u), \(v)) should be \(expected)")
            }
        }
    }

    /// #2795: the corner disagreement is silent, and this pins which boundary wins.
    ///
    /// Init's second loop runs after the first over the full V range, so `boundary2` overwrites
    /// the corner `boundary1` wrote. Moving `boundary2[0]` off the square lands that point at pole
    /// (0, 0) even though `boundary1[0]` is the square's corner.
    @Test("a disagreeing corner is overwritten by boundary2, not rejected")
    func disagreeingCornerIsOverwritten() throws {
        let s = Self.squareSides()
        var left = s.left
        left[0] = SIMD3(0, 0, 99)
        let result = try #require(
            Shape.coonsFilling(
                boundary1: s.bottom, boundary2: left, boundary3: s.top, boundary4: s.right))
        try #require(result.poles.count == 25)
        #expect(simd_length(result.poles[0] - SIMD3(0, 0, 99)) < 1e-9)
        // And the well-formed call is unaffected, so the assertion above is about the corner and
        // not about the fixture.
        let clean = try #require(
            Shape.coonsFilling(
                boundary1: s.bottom, boundary2: s.left, boundary3: s.top, boundary4: s.right))
        #expect(simd_length(clean.poles[0] - SIMD3(0, 0, 0)) < 1e-9)
    }
}
