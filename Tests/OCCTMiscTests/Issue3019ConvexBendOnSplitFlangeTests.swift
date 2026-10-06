import Foundation
import Testing

@testable import OCCTSwift

/// #3019: a convex bend on a flange some other bend split came out as long as the wrong piece.
///
/// `SheetMetal.Builder.build()` splits a flange wherever a bend covers less of it than it spans,
/// then resolved each bend to the ONE piece whose range on the seam axis equalled the bend's. A
/// bend that matched no single piece fell back to the first piece, which is named after the whole
/// flange, and a bend that matched on the wrong axis took the first piece of a different row. The
/// concave path was already immune, because #2972 reads its extent off the bend's own
/// intersection and its plane tests do not depend on the piece. The convex path read its kiss
/// segment off the piece's own profile, with nothing to recover the rest.
///
/// Measured on the unfixed builder against the closed form
/// `flanges + r^2 (1 - pi/4) L per concave bend + (pi/4) t^2 L per convex bend`, each miss is
/// `(pi/4) t^2` times the length the prism did not get, to within the 0.08 of fillet run-out the
/// stepped concave bend then carried either way (gone since #3045):
///
/// | construction | what the prism got | volume miss |
/// |---|---|---|
/// | full width on a web another bend split | 10 of 45, the first piece | -110.033016 |
/// | a run spanning several pieces | 5 of 35, a piece outside the run | -94.325995 |
/// | the web split along the OTHER profile axis | 0, built inside the web | -141.375942 |
///
/// Every case reads the bend material with a point probe as well as a volume, because a volume
/// tolerance can swallow a prism built in the wrong place while a point cannot.
///
/// The concave radius is 1.5 against a thickness of 2, and the bodies only touch. A stepped
/// concave bend used to come out `isValid == false` once its radius reached the thickness, and
/// also where the two bodies interpenetrate (#3045), and a fixture standing on that failed for
/// the wrong reason: the convex bend's union onto an invalid solid ended 470 to 480 below the
/// closed form. #3045 fixed that, and these fixtures keep the smaller radius they were written
/// with.
@Suite("Issue #3019: a convex bend on a flange another bend split")
struct Issue3019ConvexBendOnSplitFlangeTests {

    /// `1 - pi/4`: `r^2` times this is the area a concave fillet of radius `r` adds per unit of seam.
    private static let quarter: Double = 1.0 - Double.pi / 4.0

    /// What a concave fillet of `radius` adds over `length` of seam.
    private static func concaveFillet(radius: Double, length: Double) -> Double {
        radius * radius * quarter * length
    }

    /// What the convex bend material adds over `length` of seam: `(pi/4) t^2` per unit, and every
    /// flange here is 2 thick, so `pi` per unit.
    private static func convexPrism(length: Double) -> Double {
        Double.pi * length
    }

    /// The Z-section every case shares.
    ///
    /// Every flange is 2 thick:
    ///
    ///     foot  x in [0, 30],  z in [-2, 0],  y in `foot`   concave bend from the web, radius 1.5
    ///     web   x in [28, 30], z in [0, 20],  y in [0, 45]
    ///     lip   x in [30, 60], z in [20, 22], y in `lip`    convex bend from the web
    ///     tab   optional: x in [20, 30], z in [8, 16] on the web's back edge y = 45
    ///
    /// A `foot` narrower than the web splits the web along y, and the convex bend leaves the web
    /// along y as well. A tab narrower than the web's height splits it along z instead, the other
    /// profile axis, while the convex bend still runs along y.
    private static func steppedZ(
        foot: ClosedRange<Double>, lip: ClosedRange<Double>, tab: Bool
    ) throws -> Shape {
        let x = SIMD3<Double>(1, 0, 0)
        let y = SIMD3<Double>(0, 1, 0)
        let z = SIMD3<Double>(0, 0, 1)
        let footProfile: [SIMD2<Double>] = [
            SIMD2(foot.lowerBound, 0), SIMD2(foot.upperBound, 0),
            SIMD2(foot.upperBound, 30), SIMD2(foot.lowerBound, 30),
        ]
        let footFlange = SheetMetal.Flange(
            id: "foot", profile: footProfile, origin: SIMD3<Double>(0, 0, 0),
            normal: -z, uAxis: y, vAxis: x)
        let webProfile: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 45), SIMD2(0, 45)]
        let web = SheetMetal.Flange(
            id: "web", profile: webProfile, origin: SIMD3<Double>(30, 0, 0),
            normal: -x, uAxis: z, vAxis: y)
        let lipProfile: [SIMD2<Double>] = [
            SIMD2(0, lip.lowerBound), SIMD2(30, lip.lowerBound),
            SIMD2(30, lip.upperBound), SIMD2(0, lip.upperBound),
        ]
        let lipFlange = SheetMetal.Flange(
            id: "lip", profile: lipProfile, origin: SIMD3<Double>(30, 0, 20),
            normal: z, uAxis: x, vAxis: y)
        var flanges = [footFlange, web, lipFlange]
        var bends = [
            SheetMetal.Bend(from: "web", to: "foot", radius: 1.5),
            SheetMetal.Bend(from: "web", to: "lip", radius: 1.5),
        ]
        if tab {
            let tabProfile: [SIMD2<Double>] = [
                SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 8), SIMD2(0, 8),
            ]
            flanges.append(
                SheetMetal.Flange(
                    id: "tab", profile: tabProfile, origin: SIMD3<Double>(30, 45, 8),
                    normal: y, uAxis: -x, vAxis: z))
            bends.append(SheetMetal.Bend(from: "web", to: "tab", radius: 1.5))
        }
        return try SheetMetal.Builder(thickness: 2.0).build(flanges: flanges, bends: bends)
    }

    /// A point in the quarter-disc a convex bend fills, 0.5 up and 0.5 in from the kiss line
    /// (x = 30, z = 20) at height `y` along it.
    ///
    /// Inside the arc of radius 2, outside both bodies.
    private static func bendMaterial(at y: Double) -> SIMD3<Double> {
        SIMD3<Double>(29.5, y, 20.5)
    }

    /// The case the issue named: `foot` covers y in [10, 35] of the web's [0, 45], so the web is
    /// split at 10 and 35, and the convex bend to `lip` covers the web's FULL width.
    ///
    /// The unfixed builder resolved that bend to the web's first piece, y in [0, 10], and built the
    /// prism over 10 of the 45.
    @Test("a bend covering the whole web, on a web the foot bend split, is built full length")
    func fullWidthBendOnASplitFlange() throws {
        let shape = try Self.steppedZ(foot: 10.0...35.0, lip: 0.0...45.0, tab: false)
        #expect(shape.isValid)
        let v = try #require(shape.volume)
        // Flanges 30 x 25 x 2 + 20 x 45 x 2 + 30 x 45 x 2 = 6000, which only touch, plus the
        // concave bend over its 25 and the convex bend over the web's full 45. The concave
        // bend is a prism fused to the run exactly, so there is no fillet run-out and the volume
        // is the closed form (#3045).
        let concave = Self.concaveFillet(radius: 1.5, length: 25.0)
        let convex = Self.convexPrism(length: 45.0)
        let derived: Double = 6000.0 + concave + convex
        #expect(abs(v - derived) < 1e-6, "volume \(v) against the closed form \(derived)")
        // The prism past the first piece. `outside` here is the defect, and no volume tolerance
        // has to be trusted to read it.
        #expect(shape.classifyPoint(Self.bendMaterial(at: 30)) == .inside)
        #expect(shape.classifyPoint(Self.bendMaterial(at: 5)) == .inside)
        #expect(shape.classifyPoint(Self.bendMaterial(at: 42)) == .inside)
    }

    /// The control: the convex bend is the one that splits the web, `lip` covering y in [10, 35],
    /// so the bend's range equals one piece exactly and the old lookup found it.
    ///
    /// It must come out the same before and after.
    @Test("a convex bend that does the splitting itself builds over exactly its own run")
    func convexBendDoingTheSplitting() throws {
        let shape = try Self.steppedZ(foot: 0.0...45.0, lip: 10.0...35.0, tab: false)
        #expect(shape.isValid)
        let v = try #require(shape.volume)
        // 30 x 45 x 2 + 20 x 45 x 2 + 30 x 25 x 2 = 6000, plus the concave bend over 45 and the
        // convex bend over the 25 it covers. The closed form to the last digit measured, since the
        // concave bend is full width and nothing runs out, held to 1e-3: far under a prism of the
        // wrong length (at least 18 off) and clear of the sixth-digit disagreement two builds of
        // one kernel can have in a fillet closure.
        let concave = Self.concaveFillet(radius: 1.5, length: 45.0)
        let convex = Self.convexPrism(length: 25.0)
        let derived: Double = 6000.0 + concave + convex
        #expect(abs(v - derived) < 1e-3, "volume \(v) against the closed form \(derived)")
        #expect(shape.classifyPoint(Self.bendMaterial(at: 20)) == .inside)
        #expect(shape.classifyPoint(Self.bendMaterial(at: 5)) == .outside)
        #expect(shape.classifyPoint(Self.bendMaterial(at: 40)) == .outside)
    }

    /// `foot` covers y in [10, 35] and `lip` covers y in [5, 40], so the web is cut at 5, 10, 35
    /// and 40 and the convex bend's run [5, 40] covers three pieces, none of which equals it.
    ///
    /// The unfixed builder fell back to the first piece, y in [0, 5], which lies OUTSIDE the
    /// bend's own run: the prism came out 5 long, in the wrong place, protruding past `lip`.
    @Test("a bend whose run spans several pieces is built over its run, not over the first piece")
    func convexBendSpansSeveralPieces() throws {
        let shape = try Self.steppedZ(foot: 10.0...35.0, lip: 5.0...40.0, tab: false)
        #expect(shape.isValid)
        let v = try #require(shape.volume)
        // 30 x 25 x 2 + 20 x 45 x 2 + 30 x 35 x 2 = 5400, plus the concave bend over 25 and the
        // convex bend over 35, exact now that the concave bend has no run-out (#3045).
        let concave = Self.concaveFillet(radius: 1.5, length: 25.0)
        let convex = Self.convexPrism(length: 35.0)
        let derived: Double = 5400.0 + concave + convex
        #expect(abs(v - derived) < 1e-6, "volume \(v) against the closed form \(derived)")
        #expect(shape.classifyPoint(Self.bendMaterial(at: 20)) == .inside)
        #expect(shape.classifyPoint(Self.bendMaterial(at: 7)) == .inside)
        #expect(shape.classifyPoint(Self.bendMaterial(at: 38)) == .inside)
        // Past the lip's own ends, where the unfixed prism stood.
        #expect(shape.classifyPoint(Self.bendMaterial(at: 2.5)) == .outside)
        #expect(shape.classifyPoint(Self.bendMaterial(at: 42.5)) == .outside)
    }

    /// A tab on the web's back edge, z in [8, 16] of the web's height 20, splits the web along z,
    /// its OTHER profile axis.
    ///
    /// The convex bend to `lip` runs along y and covers y in [0, 45], a range every piece shares,
    /// so the unfixed lookup matched the first piece of the first row: z in [0, 8], at the far end
    /// of the web from the bend.
    ///
    /// That prism was built inside the web body and added nothing. The Z's convex corner was not
    /// built at all: the whole `(pi/4) t^2 x 45 = 141.37` is missing, and `isValid` stays true.
    @Test("a web split along its other axis still gets its convex bend where the bend is")
    func convexBendAcrossTheSplitAxis() throws {
        let shape = try Self.steppedZ(foot: 0.0...45.0, lip: 0.0...45.0, tab: true)
        #expect(shape.isValid)
        let v = try #require(shape.volume)
        // 30 x 45 x 2 + 20 x 45 x 2 + 30 x 45 x 2 + 10 x 8 x 2 = 7360, plus the concave bends
        // over 45 and over the tab's 8, and the convex bend over 45. 0.0254 under, the tab bend's
        // two run-outs.
        let footBend = Self.concaveFillet(radius: 1.5, length: 45.0)
        let tabBend = Self.concaveFillet(radius: 1.5, length: 8.0)
        let convex = Self.convexPrism(length: 45.0)
        let derived: Double = 7360.0 + footBend + tabBend + convex
        #expect(abs(v - derived) < 0.05, "volume \(v) against the closed form \(derived)")
        // 1e-5, not 1e-6: this is the end of an iterative fillet closure, and two builds of the same
        // kernel source disagree in such a value at the sixth digit (`SheetMetalTests`'s L-bracket
        // pin needed the same). The closed form above is what guards correctness.
        #expect(abs(v - 7526.937587717613) < 1e-5 * 7526.937587717613, "volume \(v)")
        for y in [3.0, 20.0, 42.0] {
            #expect(
                shape.classifyPoint(Self.bendMaterial(at: y)) == .inside,
                "no bend material at y = \(y)")
        }
    }
}
