import Foundation
import Testing

@testable import OCCTSwift

/// A stepped seam diagonal to the flange's axes builds, and each bend covers the run of the seam
/// both flanges share and no more (#3033, found reviewing #2972's fix).
///
/// #2972 stopped a stepped seam from filleting the wider flange's free edge, and it could only do
/// that where it knew the run of the seam the bend occupies. That run came from the bend
/// intersection, which exists only when the seam runs along a profile axis of both flanges. A seam
/// diagonal to the flange's axes got `intersect`'s "no split" fallback, so there was no run to
/// filter on, and a review asked whether that re-opened the defect: an upright narrower than the
/// chamfer edge it stands on, with free edge left over on the seam line.
///
/// It did not re-open it, and the measurement then found something worse. On `origin/main`, before
/// and after #2972, with a 20 x 20 base, a chamfered corner and an upright standing on the 11.31
/// chamfer edge, thickness 2, radius 1.5:
///
/// * **Concave**, the upright 4 wide on the 11.31 edge: `BuildError.filletFailed`. The unfiltered
///   selection was three collinear edges, the bend and the chamfer's free edge on either side of
///   it, and one fillet over all three failed. It failed loudly.
/// * **Convex**, the same upright hung below the base: it built, silently. The prism was cut to
///   the length of the FROM flange's own seam edge whatever the other flange covered, so declared
///   base-first it came out 11.31 long (+22.976693 over its closed form) and declared
///   upright-first it came out right, and a 17.31-wide upright declared upright-first came out
///   17.31 long over a base edge of 11.31 (+18.849556).
///
/// Both come from one missing quantity, the run of the seam the two flanges' own profile edges
/// share. It is now read from those edges when the seam is not along a profile axis, which needs
/// no flange split: the fused solid already holds the chamfer's top edge as separate edges at the
/// contact boundary (`[0, 3] [3, 7] [7, 11.31]` for the narrow upright), so the extent filter
/// selects the bend exactly.
@Suite("Issue #2972, #3033: a stepped seam diagonal to the flange's axes")
struct Issue2972DiagonalSteppedSeamTests {

    /// `1 - pi/4`: `r^2` times this is what a concave fillet of radius `r` adds per unit of seam.
    private static let quarter: Double = 1.0 - Double.pi / 4.0

    /// The chamfer edge, from (20, 12) to (12, 20).
    private static let edge: Double = 8.0 * 2.0.squareRoot()

    /// A 20 x 20 base with a chamfered corner, and an upright standing on the chamfer edge.
    ///
    /// The chamfer edge runs from (20, 12) to (12, 20), so it is diagonal to the base's own axes,
    /// which is what puts the seam in `intersect`'s no-split fallback. `start` and `width` place
    /// the upright along the edge from its (20, 12) end. `down` hangs the upright below the base,
    /// which makes the bend convex; `uprightFirst` declares the bend from the upright to the base.
    private func build(
        start: Double, width: Double, down: Bool = false, uprightFirst: Bool = false
    ) throws -> Shape {
        let s = 1.0 / 2.0.squareRoot()
        let seam = SIMD3<Double>(-s, s, 0)
        let base = SheetMetal.Flange(
            id: "a",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 12), SIMD2(12, 20), SIMD2(0, 20)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "b",
            profile: [SIMD2(0, 0), SIMD2(width, 0), SIMD2(width, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(20, 12, 0) + start * seam,
            normal: SIMD3<Double>(s, s, 0),
            uAxis: seam,
            vAxis: SIMD3<Double>(0, 0, down ? -1 : 1))
        let bend =
            uprightFirst
            ? SheetMetal.Bend(from: "b", to: "a", radius: 1.5)
            : SheetMetal.Bend(from: "a", to: "b", radius: 1.5)
        return try SheetMetal.Builder(thickness: 2).build(flanges: [base, upright], bends: [bend])
    }

    /// A point in the quarter-disc a convex bend fills, 0.5 up and 0.5 out from a kiss point that
    /// lies `along` the chamfer edge from its (20, 12) end.
    ///
    /// Inside the arc of radius 2, and outside both bodies.
    private func bendMaterial(along: Double) -> SIMD3<Double> {
        let s = 1.0 / 2.0.squareRoot()
        let x: Double = 20.0 - (along - 0.5) * s
        let y: Double = 12.0 + (along + 0.5) * s
        return SIMD3<Double>(x, y, 0.5)
    }

    @Test("the upright spanning the whole chamfer edge builds, so the geometry is a legal bend")
    func controlBuilds() throws {
        let shape = try build(start: 0, width: 8 * 2.0.squareRoot())
        #expect(shape.isValid)
        let volume = try #require(shape.volume)
        // Measured on origin/main and on the #2972 branch alike. A change here means the diagonal
        // path moved, not that this number was wrong.
        #expect(abs(volume - 968.0606173278654) < 1e-6, "measured \(volume)")
    }

    /// The case that threw.
    ///
    /// It builds now, and fills only the 4 it stands on.
    @Test("the upright narrower than the chamfer edge builds and bends only the run it stands on")
    func steppedBuilds() throws {
        let shape = try build(start: 3, width: 4)
        #expect(shape.isValid)
        let volume = try #require(shape.volume)
        // The base is 400 less the 8 x 8 / 2 chamfer corner, 368, and 2 thick: 736. The upright is
        // 4 x 10 x 2 = 80. The bodies only touch, along a face. A 90 degree concave bend of radius
        // r adds r^2 (1 - pi/4) per unit of seam, over the 4 the upright covers.
        let fillet: Double = 1.5 * 1.5 * Self.quarter * 4.0
        let derived: Double = 816.0 + fillet
        // Measured on the fixed builder: 817.931416529423, which is the closed form to the last
        // digit printed. The axis-aligned stepped fixtures sit 0.01 to 0.4 under theirs, where
        // OCCT closes the fillet off past the step; this one shows no run-out, and a surplus fillet
        // along the free chamfer edge would move it by about 3.5.
        #expect(abs(volume - derived) < 1e-3, "volume \(volume) against the closed form \(derived)")
        // 1e-5 relative, as for the other fillet closures: two builds of one kernel can differ at
        // the sixth digit.
        #expect(abs(volume - 817.931416529423) < 1e-5 * 817.931416529423, "measured \(volume)")
        // The base's free chamfer corner, 1.5 along the edge from its (20, 12) end where the
        // upright does not reach, is sharp. 0.2 inside it on both faces: `outside` here is the
        // surplus fillet #2972 fixed for the axis-aligned seam, which this seam had no run to
        // filter and so could not build at all.
        let s = 1.0 / 2.0.squareRoot()
        let free = SIMD3<Double>(20.0 - 1.7 * s, 12.0 + 1.3 * s, 1.8)
        #expect(shape.classifyPoint(free) == .inside)
    }

    /// The upright wider than the chamfer edge always built, and its volume must not move: the
    /// run the bend occupies is the whole chamfer edge, which is what the unfiltered selection
    /// took.
    ///
    /// Measured on origin/main.
    @Test("the upright wider than the chamfer edge builds exactly as it did")
    func wideUprightIsUnchanged() throws {
        let shape = try build(start: -3, width: Self.edge + 6.0)
        #expect(shape.isValid)
        let volume = try #require(shape.volume)
        #expect(abs(volume - 1088.060616237176) < 1e-5 * 1088.060616237176, "measured \(volume)")
    }

    /// A convex bend's prism was cut to the length of the FROM flange's own edge.
    ///
    /// For the narrow upright that made the two declaration orders disagree by
    /// `(pi/4) 2^2 (11.31 - 4) = 22.98`.
    @Test(
        "a narrow upright hung below the base gets bend material only over its own 4, either order")
    func convexSteppedIsTheSameEitherWay() throws {
        let baseFirst = try build(start: 3, width: 4, down: true, uprightFirst: false)
        let uprightFirst = try build(start: 3, width: 4, down: true, uprightFirst: true)
        // 736 + 80, the bodies only kiss along a line, plus (pi/4) 2^2 per unit over the 4.
        let derived: Double = 816.0 + Double.pi * 4.0
        for (label, shape) in [("base first", baseFirst), ("upright first", uprightFirst)] {
            #expect(shape.isValid, "\(label)")
            let volume = shape.volume ?? Double.nan
            #expect(abs(volume - derived) < 1e-3, "\(label): \(volume) against \(derived)")
            #expect(shape.classifyPoint(bendMaterial(along: 5)) == .inside, "\(label), mid run")
            // Past the upright's run [3, 7], where the unfixed base-first prism stood.
            #expect(
                shape.classifyPoint(bendMaterial(along: 9)) == .outside, "\(label), past the run")
        }
    }

    /// The same prism, cut to the FROM flange's edge, overshot the other way for a wide upright
    /// declared upright-first: 17.31 long over a base edge of 11.31, by `(pi/4) 2^2 x 6 = 18.85`.
    @Test("a wide upright hung below the base gets bend material only over the base's edge")
    func convexWideStopsAtTheBase() throws {
        let baseFirst = try build(start: -3, width: Self.edge + 6.0, down: true)
        let uprightFirst = try build(
            start: -3, width: Self.edge + 6.0, down: true, uprightFirst: true)
        // 736 + 10 x 2 x 17.31, plus (pi/4) 2^2 per unit over the base's own 11.31.
        let flanges: Double = 736.0 + 20.0 * (Self.edge + 6.0)
        let derived: Double = flanges + Double.pi * Self.edge
        for (label, shape) in [("base first", baseFirst), ("upright first", uprightFirst)] {
            #expect(shape.isValid, "\(label)")
            let volume = shape.volume ?? Double.nan
            #expect(abs(volume - derived) < 1e-3, "\(label): \(volume) against \(derived)")
            #expect(shape.classifyPoint(bendMaterial(along: 5)) == .inside, "\(label), mid run")
            // Before the base's edge begins, under the part of the upright that overhangs it.
            #expect(
                shape.classifyPoint(bendMaterial(along: -2)) == .outside,
                "\(label), before the edge")
        }
    }
}
