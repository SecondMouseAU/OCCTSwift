import Testing
import simd

@testable import OCCTSwift

// MARK: - #2843: which boundary goes in which slot of Surface.stretchFill
//
// `GeomFill_Stretch::Init` takes the `GeomFill_Curved` arrangement, not the `GeomFill_Coons` one:
// P1 and P3 along U on the V = first / V = last edges, P4 on U = first and P2 on U = last
// (`GeomFill_Stretch.cxx:60-99`). For a quadrilateral that is (bottom, right, top, left), where
// `Shape.coonsFilling` takes (bottom, left, top, right). OCCT's own caller settles it:
// `GeomFill_BSplineCurves::Init` passes `GeomFill_Stretch(P1, P2, P3, P4)` unswapped exactly as it
// passes `GeomFill_Curved`, and swaps only for `GeomFill_Coons`
// (`GeomFill_BSplineCurves.cxx:344-350`).
//
// The corner behaviour is Stretch's own, and is not Curved's: the second loop runs over the
// interior V range only, so the corner poles keep P1's and P3's values, but the interior subtracts
// a bilinear patch through P1(1), P2(1), P3(NPolU) and P4(NPolV), a term Curved has no counterpart
// for. P2(1) and P4(NPolV) therefore move the interior while the boundary ignores them.
//
// Measured side by side against GeomFill_Coons and GeomFill_Curved in
// `Scripts/repro/2795-geomfill-boundary-arrangement/`.

@Suite("Issue 2843: GeomFill_Stretch boundary arrangement")
struct Issue2843StretchFillArrangementTests {

    private static let n = 5
    private static let t = (0..<n).map { Double($0) / Double(n - 1) * 10 }

    private var bottom: [SIMD3<Double>] { Self.t.map { SIMD3($0, 0, 0) } }  // along U, V = first
    private var top: [SIMD3<Double>] { Self.t.map { SIMD3($0, 10, 0) } }  // along U, V = last
    private var left: [SIMD3<Double>] { Self.t.map { SIMD3(0, $0, 0) } }  // along V, U = first
    private var right: [SIMD3<Double>] { Self.t.map { SIMD3(10, $0, 0) } }  // along V, U = last

    /// The pole at `(u, v)`, both zero-based, in the row-major-in-U grid the bridge flattens.
    private func pole(_ r: Surface.StretchFillResult, _ u: Int, _ v: Int) -> SIMD3<Double> {
        r.poles[u * r.nbVPoles + v]
    }

    @Test("(bottom, right, top, left) is the arrangement: a flat square comes back as a flat grid")
    func correctArrangementGivesUniformGrid() throws {
        let r = try #require(
            Surface.stretchFill(p1: bottom, p2: right, p3: top, p4: left))
        #expect(r.nbUPoles == Self.n)
        #expect(r.nbVPoles == Self.n)

        // Every pole of a correctly arranged flat square sits at (x from U, y from V, 0).
        for u in 0..<r.nbUPoles {
            for v in 0..<r.nbVPoles {
                let want = SIMD3<Double>(Self.t[u], Self.t[v], 0)
                #expect(
                    simd_distance(pole(r, u, v), want) < 1e-9,
                    "pole (\(u),\(v)) should be \(want), got \(pole(r, u, v))")
            }
        }
        // The square's centre, spelled the way the doc snippet spells it.
        #expect(simd_distance(r.poles[12], SIMD3(5, 5, 0)) < 1e-9)
    }

    @Test("The Coons arrangement is wrong here, and the grid says so")
    func coonsArrangementIsNotUniform() throws {
        // (bottom, left, top, right) is what Shape.coonsFilling wants. Swapping slots 2 and 4
        // silently changes the surface rather than failing, which is why this is pinned.
        let r = try #require(
            Surface.stretchFill(p1: bottom, p2: left, p3: top, p4: right))
        let uniform = (0..<r.nbUPoles).allSatisfy { u in
            (0..<r.nbVPoles).allSatisfy { v in
                simd_distance(pole(r, u, v), SIMD3(Self.t[u], Self.t[v], 0)) < 1e-9
            }
        }
        #expect(!uniform, "the Coons arrangement must not reproduce the flat square")
    }

    @Test("A disagreeing p2[0] is dropped from the boundary and still moves the interior")
    func cornerIsDroppedFromTheBoundaryButNotFromTheInterior() throws {
        let clean = try #require(
            Surface.stretchFill(p1: bottom, p2: right, p3: top, p4: left))

        var moved = right
        moved[0] = SIMD3(10, 0, 99)  // the (u = last, v = first) corner, which p1 also supplies
        let r = try #require(
            Surface.stretchFill(p1: bottom, p2: moved, p3: top, p4: left))

        // The boundary corner keeps p1's value: the second loop never writes it.
        #expect(
            simd_distance(pole(r, r.nbUPoles - 1, 0), SIMD3(10, 0, 0)) < 1e-9,
            "the corner pole should still be p1's (10, 0, 0)")
        // ...but the bilinear correction term reads p2[0], so the interior moves.
        #expect(
            simd_distance(pole(r, 1, 1), pole(clean, 1, 1)) > 1.0,
            "the interior pole should have moved, got \(pole(r, 1, 1))")
    }

    @Test("p2[n - 1] is never read, so moving it changes nothing at all")
    func theOtherEndOfP2IsNeverRead() throws {
        let clean = try #require(
            Surface.stretchFill(p1: bottom, p2: right, p3: top, p4: left))

        var moved = right
        moved[Self.n - 1] = SIMD3(10, 10, 99)
        let r = try #require(
            Surface.stretchFill(p1: bottom, p2: moved, p3: top, p4: left))

        #expect(r.nbUPoles == clean.nbUPoles && r.nbVPoles == clean.nbVPoles)
        for i in 0..<clean.poles.count {
            #expect(
                simd_distance(r.poles[i], clean.poles[i]) < 1e-12,
                "pole \(i) should be untouched")
        }
    }

    @Test("Mismatched or too-short boundary arrays are refused")
    func lengthContract() throws {
        #expect(
            Surface.stretchFill(p1: bottom, p2: right, p3: top, p4: Array(left.dropLast()))
                == nil)
        let one = [SIMD3<Double>(0, 0, 0)]
        #expect(Surface.stretchFill(p1: one, p2: one, p3: one, p4: one) == nil)
    }
}
