import Testing
import simd

@testable import OCCTSwift

// #815 (Pass 5a of #807): `bsplineRemoveUKnot` had no test anywhere in the tree; its V twin
// (`BSplineSurfaceRemoveVKnotTests.swift`) does. Mirrors that file exactly, U instead of V.
@Suite("BSpline Surface RemoveUKnot (#815)")
struct BSplineSurfaceRemoveUKnotTests {

    // Same shared fixture as `BSplineSurfaceRemoveVKnotTests`.
    func makeBSplineSurface() -> Surface? {
        makeSinCosGridBSplineSurface()
    }

    @Test func removeUKnot() {
        if let s = makeBSplineSurface() {
            // Attempt removal on the ORIGINAL boundary knot, exactly as the V test this mirrors
            // does: may legitimately fail (boundary knots carry full multiplicity), so this half
            // only proves the call doesn't crash, matching that precedent.
            let _ = s.bsplineRemoveUKnot(index: 1, multiplicity: 0, tolerance: 1.0)
            #expect(true)  // no crash

            // A genuinely removable case, so the boolean itself is checked too, not just survival:
            // insert a fresh interior U knot at multiplicity 1, then remove it back out at a
            // generous tolerance.
            let uKnotsBefore = s.bsplineUKnots().count
            #expect(s.bsplineInsertUKnots([0.5], multiplicities: [1]))
            #expect(s.bsplineUKnots().count == uKnotsBefore + 1)
            #expect(s.bsplineRemoveUKnot(index: 2, multiplicity: 0, tolerance: 1.0))
            #expect(s.bsplineUKnots().count == uKnotsBefore)
        }
    }
}
