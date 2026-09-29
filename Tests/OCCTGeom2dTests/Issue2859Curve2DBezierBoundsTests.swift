import Testing
import simd

@testable import OCCTSwift

/// #2859: `Geom2d_BezierCurve` writes every index and degree precondition as a
/// `Standard_*_Raise_if` in its `.cxx`, which the pinned Release kernel compiles to nothing, so an
/// out-of-range argument from Swift indexed `NCollection_Array1` out of bounds. `Geom_BezierCurve`,
/// the same class in 3D, writes the identical guards as literal `throw`s and so always refused.
///
/// Every assertion below is on a **refusal value**, never on the absence of a crash: the worst mode
/// aborted in only 5 of 20 identical runs, so a clean run proves nothing about whether the input was
/// rejected. Each test also asserts the in-range behaviour, so a guard that refuses everything fails
/// too.
@Suite("#2859 — Curve2D Bezier index and degree bounds")
struct Issue2859Curve2DBezierBoundsTests {

    /// A 4-pole cubic whose poles are all non-zero, so a fabricated `SIMD2(0, 0)` cannot be mistaken
    /// for one of them.
    private func cubic() -> Curve2D? {
        Curve2D.bezier(poles: [SIMD2(1, 1), SIMD2(2, 4), SIMD2(5, 4), SIMD2(7, 1)])
    }

    @Test("pole(at:) returns the pole in range and SIMD2(0, 0) out of it")
    func poleBounds() {
        guard let c = cubic() else {
            Issue.record("Curve2D.bezier returned nil")
            return
        }
        let bp = c.bezierProperties
        #expect(bp.poleCount == 4)
        #expect(bp.pole(at: 1) == SIMD2(1, 1))
        #expect(bp.pole(at: 4) == SIMD2(7, 1))
        // Written as one test walking a list rather than @Test(arguments:), because an argument
        // element pairing a String with a SIMD3<Double> corrupts the Swift task allocator
        // (swiftlang/swift#91639, see CLAUDE.md), and the workaround otherwise reads as a style
        // choice. Index 1000000 SIGSEGVed before the guard; the others returned heap garbage such
        // as (7.29e-304, 0).
        for index in [-3, 0, 5, 7, 1_000_000] {
            #expect(bp.pole(at: index) == SIMD2(0, 0), "pole(at: \(index)) fabricated a value")
        }
    }

    @Test("setPole(at:point:) accepts an in-range index and refuses every other")
    func setPoleBounds() {
        guard let c = cubic() else {
            Issue.record("Curve2D.bezier returned nil")
            return
        }
        let bp = c.bezierProperties
        #expect(bp.setPole(at: 2, point: SIMD2(3, 9)))
        #expect(bp.pole(at: 2) == SIMD2(3, 9))
        // Each of these returned true before the guard, after writing past the pole array.
        for index in [-1, 0, 5, 6, 1_000_000] {
            #expect(!bp.setPole(at: index, point: SIMD2(42, 43)), "setPole(at: \(index)) accepted")
        }
        // The in-range pole is still the one we set, so the refusals changed nothing.
        #expect(bp.pole(at: 2) == SIMD2(3, 9))
    }

    @Test("setWeight(at:weight:) refuses an out-of-range index and a non-positive weight")
    func setWeightBounds() {
        guard let c = cubic() else {
            Issue.record("Curve2D.bezier returned nil")
            return
        }
        let bp = c.bezierProperties
        #expect(bp.setWeight(at: 2, weight: 2.5))
        #expect(bp.isRational)
        for index in [-1, 0, 5, 1_000_000] {
            #expect(!bp.setWeight(at: index, weight: 2.0), "setWeight(at: \(index)) accepted")
        }
        // Geom2d_BezierCurve requires weight > gp::Resolution(). A zero or negative weight used to
        // stick, after which point(at:) returned a finite point off the curve's own convex hull.
        for weight in [0.0, -5.0, Double.nan] {
            #expect(!bp.setWeight(at: 2, weight: weight), "setWeight(weight: \(weight)) accepted")
        }
    }

    @Test("bezierInsertPoleAfter refuses an index outside 0...poleCount")
    func insertPoleAfterBounds() {
        guard let c = cubic() else {
            Issue.record("Curve2D.bezier returned nil")
            return
        }
        #expect(c.bezierInsertPoleAfter(0, point: SIMD2(0.5, 0.5)))
        #expect(c.bezierProperties.poleCount == 5)
        #expect(c.bezierInsertPoleAfter(5, point: SIMD2(8, 0.5)))
        #expect(c.bezierProperties.poleCount == 6)
        // Index 9 on a 4-pole curve returned true while writing npoles(6..10) into a 5-slot array,
        // with no signal in 20 of 20 runs. Index 1000000 SIGBUSed.
        for index in [-1, 9, 1_000_000] {
            #expect(
                !c.bezierInsertPoleAfter(index, point: SIMD2(1, 1)),
                "bezierInsertPoleAfter(\(index)) accepted")
        }
        #expect(c.bezierProperties.poleCount == 6)
    }

    @Test("bezierRemovePole refuses an out-of-range index and never leaves a 1-pole curve")
    func removePoleBounds() {
        guard let c = cubic() else {
            Issue.record("Curve2D.bezier returned nil")
            return
        }
        for index in [-1, 0, 5, 1_000_000] {
            #expect(!c.bezierRemovePole(index), "bezierRemovePole(\(index)) accepted")
        }
        #expect(c.bezierProperties.poleCount == 4)
        #expect(c.bezierRemovePole(2))
        #expect(c.bezierProperties.poleCount == 3)
        #expect(c.bezierRemovePole(2))
        #expect(c.bezierProperties.poleCount == 2)
        // A Bezier needs at least 2 poles. Before the guard this succeeded and left a 1-pole
        // degree-0 curve, which the kernel's own constructor forbids, and whose next removal
        // SIGSEGVed.
        #expect(!c.bezierRemovePole(1))
        #expect(!c.bezierRemovePole(2))
        #expect(c.bezierProperties.poleCount == 2)
    }

    @Test("bezierIncreaseDegree refuses a lower degree and one above the maximum")
    func increaseDegreeBounds() {
        guard let c = cubic() else {
            Issue.record("Curve2D.bezier returned nil")
            return
        }
        #expect(c.bezierProperties.degree == 3)
        let before = c.point(at: 0.5)
        #expect(c.bezierIncreaseDegree(5))
        #expect(c.bezierProperties.degree == 5)
        // Elevation is exact, so the curve is unchanged.
        let after = c.point(at: 0.5)
        #expect(abs(after.x - before.x) < 1e-9)
        #expect(abs(after.y - before.y) < 1e-9)
        // Equal degree is a documented no-op: Geom2d_BezierCurve::Increase returns before its own
        // precondition, so this reports success without changing anything.
        #expect(c.bezierIncreaseDegree(5))
        #expect(c.bezierProperties.degree == 5)
        // Increase(2) on a degree-5 curve aborted in libmalloc in 5 of 20 identical runs, and in the
        // other 15 silently lowered the degree to 2. Increase(-5) SIGSEGVed. Increase(75) against a
        // maximum of 25 reported success and produced a degree-75 curve.
        for degree in [-5, 0, 2, 4, Curve2D.bezierMaxDegree + 1, 75] {
            #expect(!c.bezierIncreaseDegree(degree), "bezierIncreaseDegree(\(degree)) accepted")
        }
        #expect(c.bezierProperties.degree == 5)
    }
}
