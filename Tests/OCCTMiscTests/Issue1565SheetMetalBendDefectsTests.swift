import Foundation
import Testing

@testable import OCCTSwift

/// #1565: three doc/behavior mismatches found in `SheetMetal.swift` by the Swift-layer Pass 1
/// correctness sweep (Wave 2).
///
/// 1. `Bend.angle`'s documented sign convention (positive = concave, negative = convex) was never
///    read anywhere; only `bend.direction` controlled `resolvedDirection`. Fixed: `angle`'s sign
///    now overrides geometric inference when `direction == .auto`.
/// 2. `Bend.outsideRadius`/`materialThicknessAtBend` were documented as functional but never read
///    in `Builder.build()`. Judgment call: corrected the docs to disclose the gap (matching the
///    file's own "Limitations" section) rather than implementing dual-radius/thinned-bend
///    modeling, which is a substantial new geometric construction, not a defect fix. No behavior
///    change, so no new test for this one; see the updated doc comments in `SheetMetal.swift`.
/// 3. `intersect(bend:a:b:)`'s doc claimed a "falls back to no split" case for a seam misaligned
///    to both flanges' u/v axes, but only u-alignment was checked (v was assumed by elimination).
///    Fixed: both axes are now checked per flange, and a genuinely misaligned flange side falls
///    back to its full (unsplit) extent instead of projecting onto an axis the seam isn't actually
///    parallel to.
@Suite("Issue1565 SheetMetal bend defects")
struct Issue1565SheetMetalBendDefectsTests {

    // MARK: - Finding 1: angle's sign overrides auto-inferred direction

    /// Builds the shared L-bracket geometry the angle-sign tests below build variants of.
    ///
    /// Same as the pre-existing `SheetMetalTests.lBracket`: auto-inference picks `.concave` for
    /// this arrangement, but the `.convex` bend-material construction is independently buildable
    /// for the identical flanges too (confirmed empirically), which is what lets a single
    /// geometry isolate `angle`'s sign as the only variable under test.
    private static func buildLBracket(
        _ bend: (_ from: String, _ to: String) -> SheetMetal.Bend
    ) throws -> Shape {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 28), SIMD2(0, 28)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "upright",
            profile: [SIMD2(0, 0), SIMD2(65, 0), SIMD2(65, 40), SIMD2(0, 40)],
            origin: SIMD3<Double>(0, 28, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        return try SheetMetal.Builder(thickness: 3).build(
            flanges: [base, upright],
            bends: [bend("base", "upright")])
    }

    /// Regression test for #1565 finding 1.
    ///
    /// Before the fix, `angle`'s sign was never read, so `angle: -1` (documented convex) with
    /// `direction` left at its default `.auto` silently built the geometry-inferred `.concave`
    /// shape instead, identical to the plain default. Proven to fail against the pre-fix code:
    /// reverting the `resolvedDirection` change makes both assertions below fail, since the
    /// angle-driven build then matches the `.concave` volume (13315.796...) instead of the
    /// `.convex` one (13259.999...).
    @Test("negative angle overrides auto direction to convex")
    func negativeAngleOverridesAutoToConvex() throws {
        let viaAngle = try Self.buildLBracket { from, to in
            SheetMetal.Bend(from: from, to: to, angle: -1.0, insideRadius: 2.0)
        }
        let viaExplicitConvex = try Self.buildLBracket { from, to in
            SheetMetal.Bend(from: from, to: to, insideRadius: 2.0, direction: .convex)
        }
        let viaExplicitConcave = try Self.buildLBracket { from, to in
            SheetMetal.Bend(from: from, to: to, insideRadius: 2.0, direction: .concave)
        }

        #expect(viaAngle.isValid && viaExplicitConvex.isValid && viaExplicitConcave.isValid)
        let vAngle = viaAngle.volume ?? -1
        let vConvex = viaExplicitConvex.volume ?? -2
        let vConcave = viaExplicitConcave.volume ?? -3

        #expect(
            abs(vAngle - vConvex) < 1e-3,
            "angle=-1 volume \(vAngle) should match explicit .convex volume \(vConvex)")
        #expect(
            abs(vAngle - vConcave) > 1.0,
            "angle=-1 volume \(vAngle) should NOT match explicit .concave volume \(vConcave), matching would mean the sign was silently ignored"
        )
    }

    /// The positive-sign half of the same contract.
    ///
    /// `angle: +1` (documented concave) with `direction` left `.auto` matches the
    /// geometry-inferred default (which is already `.concave` for this arrangement). This
    /// direction doesn't distinguish pre-/post-fix on its own (both ignore-angle and honor-angle
    /// code paths land on `.concave` here), so it is not the regression proof;
    /// `negativeAngleOverridesAutoToConvex` above is.
    @Test("positive angle matches the geometric default")
    func positiveAngleMatchesGeometricDefault() throws {
        let viaAngle = try Self.buildLBracket { from, to in
            SheetMetal.Bend(from: from, to: to, angle: 1.0, insideRadius: 2.0)
        }
        let viaDefault = try Self.buildLBracket { from, to in
            SheetMetal.Bend(from: from, to: to, radius: 2.0)
        }
        #expect(viaAngle.isValid && viaDefault.isValid)
        let vAngle = viaAngle.volume ?? -1
        let vDefault = viaDefault.volume ?? -2
        #expect(abs(vAngle - vDefault) < 1e-3)
    }

    // MARK: - Finding 3: seam diagonal to both u and v falls back to "no split"

    /// Regression test for #1565 finding 3.
    ///
    /// A seam direction diagonal to flange `a`'s u/v axes (misaligned with both), paired with a
    /// non-rectangular (5-vertex) profile on `a` so the divergence is externally observable: the
    /// pre-fix code assumed "not u-aligned" meant "v-aligned", computed a bogus truncated
    /// intersection range from that wrong assumption, and attempted to split `a`'s profile,
    /// immediately hitting `BuildError.nonRectangularStepFlange`, even though `a` has no real
    /// stepped seam at all (its full extent already overlaps `b`). Fixed, `intersect` now checks
    /// both axes and falls back to `a`'s full (unsplit) extent, so `splitFlange` is never called
    /// and the build proceeds via the ordinary single-fillet path.
    ///
    /// Proven to fail against the pre-fix code: reverting the `intersect(bend:a:b:)` axis check
    /// makes this throw `SheetMetal.BuildError.nonRectangularStepFlange` instead of succeeding.
    @Test("diagonal seam falls back to no-split instead of throwing")
    func diagonalSeamFallsBackToNoSplitInsteadOfThrowing() throws {
        let s = 1.0 / 2.0.squareRoot()
        // Flange a: standard XY-plane axes, 5-vertex profile (rectangle with one corner
        // chamfered), so `isAxisAlignedRect`'s 4-vertex check would reject any real split
        // attempt.
        let a = SheetMetal.Flange(
            id: "a",
            profile: [
                SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 7), SIMD2(7, 10), SIMD2(0, 10),
            ],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        // Flange b: normal (1,-1,0)/sqrt(2), uAxis literally the seam direction
        // (cross(a.normal, b.normal)), so b is well-aligned and only a is the misaligned side.
        // Translated along the seam direction so the overlap window is a genuine subset of a's
        // full v-range rather than coincidentally spanning it.
        let b = SheetMetal.Flange(
            id: "b",
            profile: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(3 * s, 3 * s, 0),
            normal: SIMD3<Double>(s, -s, 0),
            uAxis: SIMD3<Double>(s, s, 0),
            vAxis: SIMD3<Double>(0, 0, 1))

        let shape = try SheetMetal.Builder(thickness: 2).build(
            flanges: [a, b],
            bends: [SheetMetal.Bend(from: "a", to: "b", radius: 1.0)])
        #expect(shape.isValid)
        if let v = shape.volume { #expect(v > 0) }
    }
}
