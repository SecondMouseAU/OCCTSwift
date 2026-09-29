import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill Curved")
struct GeomFillCurvedTests {
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

    @Test("Curved filling from boundaries")
    func curvedFilling() throws {
        let n = 5
        var b1 = [SIMD3<Double>]()
        var b2 = [SIMD3<Double>]()
        var b3 = [SIMD3<Double>]()
        var b4 = [SIMD3<Double>]()
        for i in 0..<n {
            let t = Double(i) / Double(n - 1)
            b1.append(SIMD3(t * 10, 0, sin(t * .pi)))
            b2.append(SIMD3(t * 10, 10, sin(t * .pi) + 1))
            b3.append(SIMD3(0, t * 10, sin(t * .pi) * 0.5))
            b4.append(SIMD3(10, t * 10, sin(t * .pi) * 0.5 + 0.5))
        }
        let result = try #require(
            Shape.curvedFilling(boundary1: b1, boundary2: b2, boundary3: b3, boundary4: b4))
        // #766: `poles.count > 0` passed any grid. GeomFill_Curved on the same four rows gives
        // 5 x 5 poles. As in GeomFillCoonsTests this fixture supplies (bottom, top, left, right),
        // so these are the kernel's own values for a mis-ordered call rather than a flat sheet's.
        //
        // #2795 filed this as "the same layout as GeomFill_Coons::Init". Measured, it is NOT:
        // GeomFill_Curved::Init puts P4 on the U = first edge and P2 on the U = last edge, the
        // reverse of GeomFill_Coons, and its second loop runs only over the interior V range, so
        // P1/P3 keep all four corners and P2's and P4's end points are never read. The corrected
        // arrangement for this class is therefore (bottom, right, top, left), not the
        // (bottom, left, top, right) that GeomFill_Coons takes. `correctArrangement` below pins it.
        // Transcripts: Scripts/repro/766-geomfill-a/ and
        // Scripts/repro/2795-geomfill-boundary-arrangement/.
        #expect(result.nbU == 5 && result.nbV == 5)
        try #require(result.poles.count == 25)
        #expect(simd_length(result.poles[1] - SIMD3(10, 2.5, 0.853553390593)) < 1e-9)
        #expect(simd_length(result.poles[12] - SIMD3(5, 5, 1.125)) < 1e-9)
        #expect(simd_length(result.poles[22] - SIMD3(5, 10, 2)) < 1e-9)
    }

    /// #2795: a flat square passed in the arrangement `GeomFill_Curved::Init` actually wants,
    /// (bottom, right, top, left), gives its own uniform 5 x 5 grid. This is the arrangement that
    /// distinguishes `GeomFill_Curved` from `GeomFill_Coons`: feeding this class the
    /// `coonsFilling` order, (bottom, left, top, right), does not produce the square, which the
    /// second half of this test pins.
    @Test("the arrangement Init wants gives the flat square's own uniform grid")
    func correctArrangement() throws {
        let s = Self.squareSides()
        let result = try #require(
            Shape.curvedFilling(
                boundary1: s.bottom, boundary2: s.right, boundary3: s.top, boundary4: s.left))
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

        // The Coons order on the same four rows: the corners survive, since P1/P3 own them here,
        // but boundary2 and boundary4 land on the wrong edges and the U = first column runs up
        // x = 10 instead of x = 0. So the two classes are not interchangeable.
        let coonsOrder = try #require(
            Shape.curvedFilling(
                boundary1: s.bottom, boundary2: s.left, boundary3: s.top, boundary4: s.right))
        try #require(coonsOrder.poles.count == 25)
        #expect(simd_length(coonsOrder.poles[1] - SIMD3(10, 2.5, 0)) < 1e-9)
        #expect(simd_length(coonsOrder.poles[21] - SIMD3(0, 2.5, 0)) < 1e-9)
    }

    /// #2795: `GeomFill_Curved::Init` never reads `boundary2`'s or `boundary4`'s first and last
    /// points, because its second loop runs only over `2 ... nbV - 1`. So a corner that disagrees
    /// is silently **dropped** here, where `GeomFill_Coons` silently lets it **win**. Moving
    /// `boundary4[0]` off the square leaves pole (0, 0) at `boundary1[0]`.
    @Test("a disagreeing corner is dropped, not honoured, unlike GeomFill_Coons")
    func disagreeingCornerIsDropped() throws {
        let s = Self.squareSides()
        var left = s.left
        left[0] = SIMD3(0, 0, 99)
        let result = try #require(
            Shape.curvedFilling(
                boundary1: s.bottom, boundary2: s.right, boundary3: s.top, boundary4: left))
        try #require(result.poles.count == 25)
        #expect(simd_length(result.poles[0] - SIMD3(0, 0, 0)) < 1e-9)

        // The same disagreement through GeomFill_Coons, where the corner wins instead. Both
        // assertions are about the corner rule, so pinning only one of them would leave the
        // difference between the two classes unobserved.
        var coonsLeft = s.left
        coonsLeft[0] = SIMD3(0, 0, 99)
        let coons = try #require(
            Shape.coonsFilling(
                boundary1: s.bottom, boundary2: coonsLeft, boundary3: s.top, boundary4: s.right))
        #expect(simd_length(coons.poles[0] - SIMD3(0, 0, 99)) < 1e-9)
    }
}
