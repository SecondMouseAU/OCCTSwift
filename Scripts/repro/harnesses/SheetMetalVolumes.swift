// #2972: are the eight unexplained SheetMetal volumes a defect, or a naive expectation?
//
// For each of the ten pinned fixtures this prints the builder's volume next to two closed-form
// predictions, each assembled from terms declared per fixture rather than fitted afterwards:
//
//   ideal   = sum of flange body volumes
//           - the volume where two flange bodies overlap
//           + r^2 (1 - pi/4) * L for every CONCAVE bend, over its matched seam length L
//           + (pi/4) t^2 * L     for every CONVEX bend (the quarter-disc bend-material prism)
//
//   leaked  = ideal - r^2 (1 - pi/4) * L for every SURPLUS run of the seam line, meaning the part
//             of the base flange's free edge that lies outside the bend's own extent
//
// `ideal` is what the builder should produce. `leaked` is what it produces if `findSeamEdges`
// selects the collinear free edges of the outer split pieces as well as the matched piece's seam
// edge, so that a convex (material-removing) fillet is rolled along an edge that should stay
// sharp. The two differ only for the four stepped-seam fixtures; for the other six they are the
// same number, which is what makes the comparison a test rather than a fit.
//
// The second half classifies a point that sits just inside the base flange's free back corner,
// well outside every bend's extent. `inside` means that corner is sharp; `outside` means the
// surplus fillet reached it.
//
// #3019 and #3033 add eight fixtures after the ten, with a third prediction and point probes:
//
//   misbuilt = ideal - (pi/4) t^2 * (L - built) for a CONVEX bend whose prism came out `built`
//              long instead of `L`, which is what a bend resolved to the wrong flange piece (#3019)
//              or to the wrong flange's whole edge (#3033) produced
//
// `built` is declared per fixture, before the fixture is run, so a measurement that lands on
// `misbuilt` names the defect and one that lands on neither is reported `unexplained`. A probe is a
// point in the quarter-disc a convex bend fills, or just past the run it should stop at: a volume
// tolerance can swallow a prism built in the wrong place, and a point cannot.
//
// `swift run Harnesses 2972-sheetmetal-volumes`
// The measurement and the injection sweep are in `Scripts/repro/3019-3033-sheetmetal-seam-extent/`.

import Foundation
import OCCTSwift

// Everything here is `fileprivate`: the harnesses directory is one compilation target.
private let quarter = 1.0 - Double.pi / 4.0

/// One bend's contribution, in the form the construction is supposed to produce.
private enum BendTerm {
    /// A concave bend: the fillet fills the inside corner, adding `radius^2 (1 - pi/4)` per unit.
    case concave(radius: Double, length: Double)
    /// A convex bend: a quarter-disc prism of radius `thickness`, adding `(pi/4) t^2` per unit.
    ///
    /// `builtLength` is only for a fixture that exposes a defect: the length the UNFIXED builder
    /// gave the prism, so the harness can say which defect a measurement matches. Left nil, the
    /// builder is expected to build the prism over the whole `length`.
    case convex(thickness: Double, length: Double, builtLength: Double? = nil)
    /// Seam line outside the bend's own extent. Not a bend at all; the free edge there is convex,
    /// so a fillet rolled along it REMOVES `radius^2 (1 - pi/4)` per unit.
    case surplus(radius: Double, length: Double)

    var idealContribution: Double {
        switch self {
        case .concave(let r, let l): return r * r * quarter * l
        case .convex(let t, let l, _): return (Double.pi / 4.0) * t * t * l
        case .surplus: return 0
        }
    }

    /// What this term changes if the convex prism comes out `builtLength` long instead of `length`.
    var misbuiltContribution: Double {
        switch self {
        case .convex(let t, let l, let built?): return (Double.pi / 4.0) * t * t * (built - l)
        default: return 0
        }
    }

    var isMisbuilt: Bool {
        if case .convex(_, _, .some) = self { return true }
        return false
    }

    var leakedContribution: Double {
        switch self {
        case .surplus(let r, let l): return -r * r * quarter * l
        default: return 0
        }
    }
}

/// A point classified against the built solid, with the state the construction should give it.
///
/// Used where a volume tolerance could swallow the defect, or where the defect moves material
/// rather than removing it: a probe in the quarter-disc a convex bend should fill reads `outside`
/// when the prism was built over the wrong run of the seam, whatever the volume does.
private struct Probe {
    let label: String
    let point: SIMD3<Double>
    let want: Shape.PointState
}

private struct Fixture {
    let name: String
    /// Sum of each flange's own extruded volume, before any body-body overlap is deducted.
    let flangeSum: Double
    /// Volume counted twice by `flangeSum` because two flange bodies interpenetrate.
    let overlap: Double
    let terms: [BendTerm]
    /// The volume pinned in `Tests/OCCTMiscTests`, or for the #3019 and #3033 fixtures the value
    /// measured on the fixed builder, so a kernel move shows up as a NOTE line.
    let pinned: Double
    let build: () throws -> Shape
    /// A point just inside the base flange's free corner, outside every bend's extent, or nil
    /// where the fixture has no stepped seam.
    let sharpCornerProbe: SIMD3<Double>?
    /// Points inside or outside the bend material, for the fixtures that exist to expose a
    /// convex-bend defect (#3019, #3033).
    ///
    /// Empty for the rest.
    var bendProbes: [Probe] = []

    var ideal: Double { flangeSum - overlap + terms.reduce(0) { $0 + $1.idealContribution } }
    var leaked: Double { ideal + terms.reduce(0) { $0 + $1.leakedContribution } }
    var misbuilt: Double { ideal + terms.reduce(0) { $0 + $1.misbuiltContribution } }
    var hasMisbuiltTerm: Bool { terms.contains { $0.isMisbuilt } }
}

private func flange(
    _ id: String, _ profile: [SIMD2<Double>], _ origin: SIMD3<Double>,
    normal: SIMD3<Double>, u: SIMD3<Double>, v: SIMD3<Double>? = nil
) -> SheetMetal.Flange {
    SheetMetal.Flange(
        id: id, profile: profile, origin: origin, normal: normal, uAxis: u, vAxis: v)
}

private func rect(_ w: Double, _ h: Double) -> [SIMD2<Double>] {
    [SIMD2(0, 0), SIMD2(w, 0), SIMD2(w, h), SIMD2(0, h)]
}

/// A span of a flange's seam-parallel axis as a rectangle `width` wide in the other axis.
private func spanProfile(_ width: Double, _ span: ClosedRange<Double>) -> [SIMD2<Double>] {
    let lo = span.lowerBound
    let hi = span.upperBound
    return [SIMD2(0, lo), SIMD2(width, lo), SIMD2(width, hi), SIMD2(0, hi)]
}

/// The Z-section the #3019 fixtures share.
///
/// Every flange is 2 thick:
///
///     foot  x in [0, 30],  z in [-2, 0],  y in `foot`   concave bend from the web, radius 1.5
///     web   x in [28, 30], z in [0, 20],  y in [0, 45]
///     lip   x in [30, 60], z in [20, 22], y in `lip`    convex bend from the web
///     tab   optional: x in [20, 30], z in [8, 16] on the web's back edge y = 45, radius 1.5
///
/// A `foot` narrower than the web splits the web along y, and the convex bend leaves the web along
/// y as well. A tab narrower than the web's height splits it along z, the OTHER profile axis,
/// while the convex bend still runs along y.
///
/// The concave radius is below the thickness and the bodies only touch, on purpose. A stepped
/// concave bend came out `isValid == false` once its radius reached the thickness, and also where
/// the two bodies interpenetrate (#3045). That is a separate limitation and these fixtures stay
/// clear of it, so they read #3019 and nothing else.
private func steppedZ(
    foot: ClosedRange<Double>, lip: ClosedRange<Double>, tab: Bool
) throws -> Shape {
    let x = SIMD3<Double>(1, 0, 0)
    let y = SIMD3<Double>(0, 1, 0)
    let z = SIMD3<Double>(0, 0, 1)
    let footProfile: [SIMD2<Double>] = [
        SIMD2(foot.lowerBound, 0), SIMD2(foot.upperBound, 0),
        SIMD2(foot.upperBound, 30), SIMD2(foot.lowerBound, 30),
    ]
    let footFlange = flange("foot", footProfile, SIMD3(0, 0, 0), normal: -z, u: y, v: x)
    let web = flange("web", rect(20, 45), SIMD3(30, 0, 0), normal: -x, u: z, v: y)
    let lipFlange = flange(
        "lip", spanProfile(30.0, lip), SIMD3(30, 0, 20), normal: z, u: x, v: y)
    var flanges = [footFlange, web, lipFlange]
    var bends = [
        SheetMetal.Bend(from: "web", to: "foot", radius: 1.5),
        SheetMetal.Bend(from: "web", to: "lip", radius: 1.5),
    ]
    if tab {
        flanges.append(flange("tab", rect(10, 8), SIMD3(30, 45, 8), normal: y, u: -x, v: z))
        bends.append(SheetMetal.Bend(from: "web", to: "tab", radius: 1.5))
    }
    return try SheetMetal.Builder(thickness: 2.0).build(flanges: flanges, bends: bends)
}

/// A 20 x 20 base with a chamfered corner, and an upright standing on the 11.31 chamfer edge,
/// which is diagonal to the base's own axes (#3033).
///
/// Thickness 2, radius 1.5.
///
/// `start` and `width` place the upright along the edge from its (20, 12) end. `down` hangs it
/// below the base instead of standing it on top, which makes the bend convex. `uprightFirst`
/// declares the bend from the upright to the base.
private func diagonalUpright(
    start: Double, width: Double, down: Bool, uprightFirst: Bool, declareBend: Bool = true
) throws -> Shape {
    let s: Double = 1.0 / 2.0.squareRoot()
    let seam = SIMD3<Double>(-s, s, 0)
    let base = flange(
        "base", [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 12), SIMD2(12, 20), SIMD2(0, 20)],
        SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
    let upright = flange(
        "upright", rect(width, 10), SIMD3<Double>(20, 12, 0) + start * seam,
        normal: SIMD3(s, s, 0), u: seam, v: SIMD3(0, 0, down ? -1 : 1))
    let bend =
        uprightFirst
        ? SheetMetal.Bend(from: "upright", to: "base", radius: 1.5)
        : SheetMetal.Bend(from: "base", to: "upright", radius: 1.5)
    let bends = declareBend ? [bend] : []
    return try SheetMetal.Builder(thickness: 2.0).build(flanges: [base, upright], bends: bends)
}

enum SheetMetalVolumes {

    fileprivate static func fixtures() -> [Fixture] {
        // One `append` per fixture, never one array literal over all ten. Each `Fixture` carries
        // integer-literal arithmetic (`65 * 28 * 3 + 65 * 40 * 3`), so a ten-element literal is one
        // constraint system over the whole expression and the type checker gives up: CI reported
        // "unable to type-check this expression in reasonable time" at the literal's line.
        //
        // Splitting it into `all += [ ...ten... ]` looked like a fix and was not: it compiled in 39 s
        // on a fast machine and timed out on the CI runner, moving the failure from line 91 to line
        // 97. A literal's cost is a property of its size, not of what it is assigned to, so the only
        // repair is for no single expression to contain more than one fixture.
        var all: [Fixture] = []
        // --- full-seam concave, the two the issue already derives ---
        all.append(
            Fixture(
                name: "SheetMetalTests.lBracket",
                flangeSum: 65.0 * 28.0 * 3.0 + 65.0 * 40.0 * 3.0,
                overlap: 0.0,
                terms: [.concave(radius: 2.0, length: 65)],
                pinned: 13315.796477516664,
                build: {
                    let base = flange(
                        "base", rect(65, 28), SIMD3(0, 0, 0),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    let upright = flange(
                        "upright", rect(65, 40), SIMD3(0, 28, 0),
                        normal: SIMD3(0, 1, 0), u: SIMD3(1, 0, 0), v: SIMD3(0, 0, 1))
                    return try SheetMetal.Builder(thickness: 3).build(
                        flanges: [base, upright],
                        bends: [SheetMetal.Bend(from: "base", to: "upright", radius: 2.0)])
                },
                sharpCornerProbe: nil))
        all.append(
            Fixture(
                name: "SheetMetalTests.uChannel",
                flangeSum: 40.0 * 20.0 * 2.0 + 2.0 * (20.0 * 15.0 * 2.0),
                overlap: 0.0,
                terms: [
                    .concave(radius: 1.5, length: 20),
                    .concave(radius: 1.5, length: 20),
                ],
                pinned: 2819.3141652942295,
                build: {
                    let bottom = flange(
                        "bottom", rect(40, 20), SIMD3(0, 0, 0),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    let left = flange(
                        "left", rect(20, 15), SIMD3(0, 0, 0),
                        normal: SIMD3(-1, 0, 0), u: SIMD3(0, 1, 0), v: SIMD3(0, 0, 1))
                    let right = flange(
                        "right", rect(20, 15), SIMD3(40, 0, 0),
                        normal: SIMD3(1, 0, 0), u: SIMD3(0, 1, 0), v: SIMD3(0, 0, 1))
                    return try SheetMetal.Builder(thickness: 2).build(
                        flanges: [bottom, left, right],
                        bends: [
                            SheetMetal.Bend(from: "bottom", to: "left", radius: 1.5),
                            SheetMetal.Bend(from: "bottom", to: "right", radius: 1.5),
                        ])
                },
                sharpCornerProbe: nil))

        // --- stepped seams: base 65 wide, upright 28 wide, so 37 of surplus ---
        all.append(
            Fixture(
                name: "SheetMetalTests.narrowUprightStepSucceeds",
                flangeSum: 65.0 * 28.0 * 3.0 + 28.0 * 40.0 * 3.0,
                overlap: 0.0,
                terms: [
                    .concave(radius: 1.5, length: 28),
                    .surplus(radius: 1.5, length: 65.0 - 28.0),
                ],
                pinned: 8833.505966569946,
                build: {
                    let base = flange(
                        "base", rect(65, 28), SIMD3(0, 0, 0),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    let upright = flange(
                        "vertical", rect(28, 40), SIMD3(0, 28, 0),
                        normal: SIMD3(0, 1, 0), u: SIMD3(1, 0, 0), v: SIMD3(0, 0, 1))
                    return try SheetMetal.Builder(thickness: 3).build(
                        flanges: [base, upright],
                        bends: [SheetMetal.Bend(from: "base", to: "vertical", radius: 1.5)])
                },
                // x = 50 is 22 clear of the upright's x <= 28 extent; the corner at y = 28, z = 3
                // is the base's own free edge. 0.2 in from it on both faces.
                sharpCornerProbe: SIMD3(50, 27.8, 2.8)))
        all.append(
            Fixture(
                name: "SheetMetalTests.lBracketStepSeamCentredTab",
                flangeSum: 80.0 * 40.0 * 2.0 + 20.0 * 30.0 * 2.0,
                overlap: 0.0,
                terms: [
                    .concave(radius: 1.5, length: 20),
                    .surplus(radius: 1.5, length: 30),
                    .surplus(radius: 1.5, length: 30),
                ],
                pinned: 7609.603645881255,
                build: {
                    let base = flange(
                        "base", rect(80, 40), SIMD3(0, 0, 0),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    let tab = flange(
                        "tab", rect(20, 30), SIMD3(30, 40, 0),
                        normal: SIMD3(0, 1, 0), u: SIMD3(1, 0, 0), v: SIMD3(0, 0, 1))
                    return try SheetMetal.Builder(thickness: 2).build(
                        flanges: [base, tab],
                        bends: [SheetMetal.Bend(from: "base", to: "tab", radius: 1.5)])
                },
                sharpCornerProbe: SIMD3(10, 39.8, 1.8)))
        all.append(
            Fixture(
                name: "SheetMetalTests.zBracket",
                flangeSum: 50.0 * 30.0 * 2.0 + 50.0 * 20.0 * 2.0 + 20.0 * 30.0 * 2.0,
                overlap: 0.0,
                terms: [
                    .concave(radius: 1.5, length: 50),
                    .concave(radius: 1.5, length: 20),
                    .surplus(radius: 1.5, length: 30),
                ],
                pinned: 6233.76158899466,
                build: {
                    let base = flange(
                        "base", rect(50, 30), SIMD3(0, 0, 0),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    let mid = flange(
                        "mid", rect(50, 20), SIMD3(0, 30, 0),
                        normal: SIMD3(0, 1, 0), u: SIMD3(1, 0, 0), v: SIMD3(0, 0, 1))
                    let top = flange(
                        "top", rect(20, 30), SIMD3(15, 30, 20),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    return try SheetMetal.Builder(thickness: 2).build(
                        flanges: [base, mid, top],
                        bends: [
                            SheetMetal.Bend(from: "base", to: "mid", radius: 1.5),
                            SheetMetal.Bend(from: "mid", to: "top", radius: 1.5),
                        ])
                },
                // The mid riser's free top edge, outside the top tab's x in [15, 35]. The seam
                // plane on the mid is its OUTER face y = 32 (the one the tab sits beside), not
                // y = 30, so the corner under test is (y = 32, z = 20).
                sharpCornerProbe: SIMD3(5, 31.8, 19.8)))
        all.append(
            Fixture(
                name: "SheetMetalTests.uChannelStepped",
                flangeSum: 40.0 * 100.0 * 2.0 + 2.0 * (80.0 * 15.0 * 2.0),
                overlap: 0.0,
                terms: [
                    .concave(radius: 1.5, length: 80),
                    .concave(radius: 1.5, length: 80),
                    .surplus(radius: 1.5, length: 10),
                    .surplus(radius: 1.5, length: 10),
                    .surplus(radius: 1.5, length: 10),
                    .surplus(radius: 1.5, length: 10),
                ],
                pinned: 12876.881759332367,
                build: {
                    let spine = flange(
                        "spine", rect(40, 100), SIMD3(0, 0, 0),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    let left = flange(
                        "left", rect(80, 15), SIMD3(0, 10, 0),
                        normal: SIMD3(-1, 0, 0), u: SIMD3(0, 1, 0), v: SIMD3(0, 0, 1))
                    let right = flange(
                        "right", rect(80, 15), SIMD3(40, 10, 0),
                        normal: SIMD3(1, 0, 0), u: SIMD3(0, 1, 0), v: SIMD3(0, 0, 1))
                    return try SheetMetal.Builder(thickness: 2).build(
                        flanges: [spine, left, right],
                        bends: [
                            SheetMetal.Bend(from: "spine", to: "left", radius: 1.5),
                            SheetMetal.Bend(from: "spine", to: "right", radius: 1.5),
                        ])
                },
                // y = 5 is below the walls' y in [10, 90]; the spine's own free edge at x = 0,
                // z = 2.
                sharpCornerProbe: SIMD3(0.2, 5, 1.8)))

        // --- convex bends ---
        all.append(
            Fixture(
                name: "ConvexBendIssue89.zBracketRepro",
                flangeSum: 18.0 * 45.0 * 3.2 + 25.0 * 45.0 * 3.2 + 45.0 * 45.0 * 3.2,
                overlap: 3.2 * 3.2 * 45.0,
                terms: [
                    .concave(radius: 3.2, length: 45),
                    .convex(thickness: 3.2, length: 45),
                ],
                pinned: 12671.999999999995,
                build: {
                    let top = flange(
                        "top", rect(18, 45), SIMD3(0, 0, 0),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    let web = flange(
                        "web", rect(25, 45), SIMD3(18, 0, 0),
                        normal: SIMD3(-1, 0, 0), u: SIMD3(0, 0, 1), v: SIMD3(0, 1, 0))
                    let bottom = flange(
                        "bottom", rect(45, 45), SIMD3(18, 0, 25),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    return try SheetMetal.Builder(thickness: 3.2).build(
                        flanges: [top, web, bottom],
                        bends: [
                            SheetMetal.Bend(from: "top", to: "web", radius: 3.2),
                            SheetMetal.Bend(from: "web", to: "bottom", radius: 3.2),
                        ])
                },
                sharpCornerProbe: nil))
        all.append(
            Fixture(
                name: "ConvexBendIssue89.symmetricZ",
                flangeSum: 30.0 * 45.0 * 2.0 + 20.0 * 45.0 * 2.0 + 30.0 * 45.0 * 2.0,
                overlap: 2.0 * 2.0 * 45.0,
                terms: [
                    .concave(radius: 3, length: 45),
                    .convex(thickness: 2, length: 45),
                ],
                pinned: 7248.285413235574,
                build: {
                    let top = flange(
                        "top", rect(30, 45), SIMD3(0, 0, 0),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    let web = flange(
                        "web", rect(20, 45), SIMD3(30, 0, 0),
                        normal: SIMD3(-1, 0, 0), u: SIMD3(0, 0, 1), v: SIMD3(0, 1, 0))
                    let bottom = flange(
                        "bottom", rect(30, 45), SIMD3(30, 0, 20),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    return try SheetMetal.Builder(thickness: 2).build(
                        flanges: [top, web, bottom],
                        bends: [
                            SheetMetal.Bend(from: "top", to: "web", radius: 3),
                            SheetMetal.Bend(from: "web", to: "bottom", radius: 3),
                        ])
                },
                sharpCornerProbe: nil))
        all.append(
            Fixture(
                name: "ConvexBendIssue89.offsetLShortWeb",
                flangeSum: 50.0 * 60.0 * 2.0 + 5.0 * 60.0 * 2.0 + 50.0 * 60.0 * 2.0,
                overlap: 2.0 * 2.0 * 60.0,
                terms: [
                    .concave(radius: 1.5, length: 60),
                    .convex(thickness: 2, length: 60),
                ],
                pinned: 12577.466807156732,
                build: {
                    let top = flange(
                        "top", rect(50, 60), SIMD3(0, 0, 0),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    let web = flange(
                        "web", rect(5, 60), SIMD3(50, 0, 0),
                        normal: SIMD3(-1, 0, 0), u: SIMD3(0, 0, 1), v: SIMD3(0, 1, 0))
                    let bottom = flange(
                        "bottom", rect(50, 60), SIMD3(50, 0, 5),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    return try SheetMetal.Builder(thickness: 2).build(
                        flanges: [top, web, bottom],
                        bends: [
                            SheetMetal.Bend(from: "top", to: "web", radius: 1.5),
                            SheetMetal.Bend(from: "web", to: "bottom", radius: 1.5),
                        ])
                },
                sharpCornerProbe: nil))
        all.append(
            Fixture(
                name: "ConvexBendIssue89.channelWithFlange",
                flangeSum: 100.0 * 40.0 * 1.5 + 2.0 * (30.0 * 40.0 * 1.5) + 20.0 * 40.0 * 1.5,
                overlap: 2.0 * (1.5 * 1.5 * 40.0),
                terms: [
                    .concave(radius: 2, length: 40),
                    .concave(radius: 2, length: 40),
                    .convex(thickness: 1.5, length: 40),
                ],
                pinned: 10759.358422418583,
                build: {
                    let spine = flange(
                        "spine", rect(100, 40), SIMD3(0, 0, 0),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    let leftWall = flange(
                        "left", rect(30, 40), SIMD3(0, 0, 0),
                        normal: SIMD3(1, 0, 0), u: SIMD3(0, 0, 1), v: SIMD3(0, 1, 0))
                    let rightWall = flange(
                        "right", rect(30, 40), SIMD3(100, 0, 0),
                        normal: SIMD3(-1, 0, 0), u: SIMD3(0, 0, 1), v: SIMD3(0, 1, 0))
                    let tab = flange(
                        "tab", rect(20, 40), SIMD3(100, 0, 30),
                        normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
                    return try SheetMetal.Builder(thickness: 1.5).build(
                        flanges: [spine, leftWall, rightWall, tab],
                        bends: [
                            SheetMetal.Bend(from: "spine", to: "left", radius: 2),
                            SheetMetal.Bend(from: "spine", to: "right", radius: 2),
                            SheetMetal.Bend(from: "right", to: "tab", radius: 2),
                        ])
                },
                sharpCornerProbe: nil))

        // --- #3019: a convex bend on a flange some OTHER bend split ---
        //
        // The unfixed builder resolved a bend to the one flange piece whose range on the seam axis
        // equalled the bend's, and to the FIRST piece when none did. The convex path read its kiss
        // segment off that piece's own profile, so the quarter-disc prism came out as long as the
        // piece. `builtLength` is what that produced, so the harness can name the defect.
        let webSpan: Double = 45.0
        let steppedWebSum: Double = 30.0 * 25.0 * 2.0 + 20.0 * 45.0 * 2.0 + 30.0 * 45.0 * 2.0
        all.append(
            Fixture(
                name: "Issue3019.steppedWebZ",
                flangeSum: steppedWebSum,
                overlap: 0.0,
                terms: [
                    .concave(radius: 1.5, length: 25.0),
                    .convex(thickness: 2.0, length: webSpan, builtLength: 10.0),
                ],
                pinned: 6153.364427799075,
                build: { try steppedZ(foot: 10.0...35.0, lip: 0.0...45.0, tab: false) },
                sharpCornerProbe: nil,
                bendProbes: [
                    Probe(
                        label: "bend material, y = 30", point: SIMD3<Double>(29.5, 30.0, 20.5),
                        want: .inside),
                    Probe(
                        label: "bend material, y = 5", point: SIMD3<Double>(29.5, 5.0, 20.5),
                        want: .inside),
                ]))
        let doingTheSplitSum: Double = 30.0 * 45.0 * 2.0 + 20.0 * 45.0 * 2.0 + 30.0 * 25.0 * 2.0
        all.append(
            Fixture(
                name: "Issue3019.convexBendDoesTheSplitting",
                flangeSum: doingTheSplitSum,
                overlap: 0.0,
                terms: [
                    .concave(radius: 1.5, length: 45.0),
                    .convex(thickness: 2.0, length: 25.0),
                ],
                pinned: 6100.268252295755,
                build: { try steppedZ(foot: 0.0...45.0, lip: 10.0...35.0, tab: false) },
                sharpCornerProbe: nil,
                bendProbes: [
                    Probe(
                        label: "bend material, y = 20", point: SIMD3<Double>(29.5, 20.0, 20.5),
                        want: .inside),
                    Probe(
                        label: "no bend material, y = 5", point: SIMD3<Double>(29.5, 5.0, 20.5),
                        want: .outside),
                ]))
        let severalCellsSum: Double = 30.0 * 25.0 * 2.0 + 20.0 * 45.0 * 2.0 + 30.0 * 35.0 * 2.0
        all.append(
            Fixture(
                name: "Issue3019.convexBendSpansSeveralCells",
                flangeSum: severalCellsSum,
                overlap: 0.0,
                terms: [
                    .concave(radius: 1.5, length: 25.0),
                    .convex(thickness: 2.0, length: 35.0, builtLength: 5.0),
                ],
                pinned: 5521.948704796732,
                build: { try steppedZ(foot: 10.0...35.0, lip: 5.0...40.0, tab: false) },
                sharpCornerProbe: nil,
                bendProbes: [
                    Probe(
                        label: "bend material, y = 20", point: SIMD3<Double>(29.5, 20.0, 20.5),
                        want: .inside),
                    Probe(
                        label: "no bend material, y = 2.5", point: SIMD3<Double>(29.5, 2.5, 20.5),
                        want: .outside),
                ]))
        let acrossSum: Double = 30.0 * 45.0 * 2.0 + 20.0 * 45.0 * 2.0 + 30.0 * 45.0 * 2.0
        all.append(
            Fixture(
                name: "Issue3019.convexBendAcrossTheSplitAxis",
                flangeSum: acrossSum + 10.0 * 8.0 * 2.0,
                overlap: 0.0,
                terms: [
                    .concave(radius: 1.5, length: 45.0),
                    .convex(thickness: 2.0, length: webSpan, builtLength: 0.0),
                    .concave(radius: 1.5, length: 8.0),
                ],
                pinned: 7526.937587717613,
                build: { try steppedZ(foot: 0.0...45.0, lip: 0.0...45.0, tab: true) },
                sharpCornerProbe: nil,
                bendProbes: [
                    Probe(
                        label: "bend material, y = 20", point: SIMD3<Double>(29.5, 20.0, 20.5),
                        want: .inside)
                ]))

        // --- #3033: a stepped seam diagonal to the flange's axes ---
        let edge: Double = 8.0 * 2.0.squareRoot()
        let root: Double = 1.0 / 2.0.squareRoot()
        let narrowFlange: Double = 368.0 * 2.0 + 4.0 * 10.0 * 2.0
        let wideRun: Double = edge + 6.0
        let wideFlange: Double = 368.0 * 2.0 + wideRun * 10.0 * 2.0
        // 0.2 inside the base's free chamfer corner, on the run 1.5 along the edge from its (20, 12)
        // end, which the 4-wide upright standing 3 along the edge does not reach.
        let freeX: Double = 20.0 - 1.7 * root
        let freeY: Double = 12.0 + 1.3 * root
        let freeCorner = SIMD3<Double>(freeX, freeY, 1.8)
        // A point in the quarter-disc of a convex bend, 0.5 up and 0.5 out from a kiss point that
        // lies `along` the chamfer edge from its (20, 12) end.
        let midX: Double = 20.0 - 4.5 * root
        let midY: Double = 12.0 + 5.5 * root
        let kissMid = SIMD3<Double>(midX, midY, 0.5)
        let beyondX: Double = 20.0 - 8.5 * root
        let beyondY: Double = 12.0 + 9.5 * root
        let kissBeyond = SIMD3<Double>(beyondX, beyondY, 0.5)
        let beforeX: Double = 20.0 + 2.0 * root
        let beforeY: Double = 12.0 - 1.0 * root
        let kissBefore = SIMD3<Double>(beforeX, beforeY, 0.5)
        all.append(
            Fixture(
                name: "Issue3033.diagonalSteppedConcave",
                flangeSum: narrowFlange,
                overlap: 0.0,
                terms: [.concave(radius: 1.5, length: 4.0)],
                pinned: 817.931416529423,
                build: {
                    try diagonalUpright(start: 3.0, width: 4.0, down: false, uprightFirst: false)
                },
                sharpCornerProbe: freeCorner))
        all.append(
            Fixture(
                name: "Issue3033.diagonalSteppedConvexBaseFirst",
                flangeSum: narrowFlange,
                overlap: 0.0,
                terms: [.convex(thickness: 2.0, length: 4.0, builtLength: edge)],
                pinned: 828.566370614359,
                build: {
                    try diagonalUpright(start: 3.0, width: 4.0, down: true, uprightFirst: false)
                },
                sharpCornerProbe: nil,
                bendProbes: [
                    Probe(label: "bend material, mid run", point: kissMid, want: .inside),
                    Probe(
                        label: "no bend material, past the upright", point: kissBeyond,
                        want: .outside),
                ]))
        all.append(
            Fixture(
                name: "Issue3033.diagonalSteppedConvexUprightFirst",
                flangeSum: narrowFlange,
                overlap: 0.0,
                terms: [.convex(thickness: 2.0, length: 4.0)],
                pinned: 828.566370614359,
                build: {
                    try diagonalUpright(start: 3.0, width: 4.0, down: true, uprightFirst: true)
                },
                sharpCornerProbe: nil,
                bendProbes: [
                    Probe(label: "bend material, mid run", point: kissMid, want: .inside),
                    Probe(
                        label: "no bend material, past the upright", point: kissBeyond,
                        want: .outside),
                ]))
        all.append(
            Fixture(
                name: "Issue3033.diagonalWideConvexUprightFirst",
                flangeSum: wideFlange,
                overlap: 0.0,
                terms: [.convex(thickness: 2.0, length: edge, builtLength: wideRun)],
                pinned: 1117.817233484962,
                build: {
                    try diagonalUpright(start: -3.0, width: wideRun, down: true, uprightFirst: true)
                },
                sharpCornerProbe: nil,
                bendProbes: [
                    Probe(label: "bend material, mid run", point: kissMid, want: .inside),
                    Probe(
                        label: "no bend material, before the base's edge", point: kissBefore,
                        want: .outside),
                ]))

        return all
    }

    static func run() {
        let ruleWidth = 122
        print("#2972, #3019, #3033: SheetMetal volumes against a term-by-term prediction")
        print(String(repeating: "=", count: ruleWidth))
        print("ideal    = flanges - overlap + concave r^2(1-pi/4)L + convex (pi/4)t^2 L")
        print(
            "leaked   = ideal - r^2(1-pi/4)L over every seam run OUTSIDE the bend's own extent (#2972)"
        )
        print(
            "misbuilt = ideal - (pi/4)t^2 (L - built) where a convex prism came out `built` long (#3019, #3033)"
        )
        print("")
        var header = pad("fixture", 42)
        header += pad("measured", 22)
        header += pad("ideal", 14)
        header += pad("leaked", 14)
        header += pad("misbuilt", 14)
        header += "verdict"
        print(header)
        print(String(repeating: "-", count: ruleWidth))

        var defects = 0
        var probeFailures = 0
        for f in fixtures() {
            let shape: Shape
            do {
                shape = try f.build()
            } catch {
                print(pad(f.name, 42), "THREW", error)
                continue
            }
            guard let v = shape.volume else {
                print(pad(f.name, 42), "NO VOLUME")
                continue
            }
            let dIdeal = v - f.ideal
            let dLeaked = v - f.leaked
            let dMisbuilt = v - f.misbuilt
            let hasSurplus = f.terms.contains {
                if case .surplus = $0 { return true } else { return false }
            }
            // 1e-4 relative. The closed form is exact along the bend and does not model how OCCT
            // closes the fillet off where the seam line runs on into a flat neighbour: measured,
            // the cross-section is full to within 0.01 of the step and the surface stops about
            // 0.1 past it. The control below removes the step and nothing else, and lands on
            // `ideal` to 1e-12, which is what attributes the residual to the run-out rather than
            // to the prediction. Largest observed: 0.375 on uChannelStepped, four run-outs, 2.9e-5
            // relative.
            let tol = 1e-4 * max(1.0, v)
            let verdict: String
            if abs(dIdeal) < tol {
                verdict = "ideal"
            } else if abs(dLeaked) < tol {
                verdict = hasSurplus ? "LEAKED (surplus fillet)" : "leaked (== ideal)"
                if hasSurplus { defects += 1 }
            } else if f.hasMisbuiltTerm && abs(dMisbuilt) < tol {
                verdict = "MISBUILT (convex prism over the wrong run)"
                defects += 1
            } else {
                verdict = "unexplained"
            }
            var line = pad(f.name, 42)
            line += pad(fmt(v), 22)
            line += pad(fmt6(dIdeal), 14)
            line += pad(fmt6(dLeaked), 14)
            line += pad(f.hasMisbuiltTerm ? fmt6(dMisbuilt) : "-", 14)
            line += verdict
            print(line)
            if abs(v - f.pinned) > 1e-9 * max(1.0, f.pinned) {
                print(
                    "    NOTE: differs from the pinned value \(fmt(f.pinned)) by "
                        + fmt6(v - f.pinned))
            }
            for probe in f.bendProbes {
                let got = shape.classifyPoint(probe.point)
                let ok = got == probe.want
                if !ok { probeFailures += 1 }
                let mark = ok ? "ok  " : "FAIL"
                print("    probe", mark, probe.label, "want", probe.want, "got", got)
            }
        }

        print("")
        print("Point classification at the base flange's free corner, outside every bend extent")
        print(String(repeating: "-", count: 108))
        for f in fixtures() {
            guard let probe = f.sharpCornerProbe else { continue }
            guard let shape = try? f.build() else { continue }
            let state = shape.classifyPoint(probe)
            print(
                pad(f.name, 42) + pad("\(probe)", 32)
                    + "\(state)  (inside = sharp, outside = rounded away)")
        }

        print("")
        print("Pre-fillet seam line, as the fused solid holds it (narrowUprightStepSucceeds)")
        print(String(repeating: "-", count: 108))
        // The same base/upright, with the base handed in ALREADY SPLIT at the upright's x = 28 and
        // no bends declared, which is exactly the solid `build()` fillets. Listing every line edge
        // along x that lies on y = 28 and z = 3 says whether the seam line is one edge spanning the
        // whole base or two, which decides whether an extent filter can select the matched run.
        let basePieceA = flange(
            "baseA", rect(28, 28), SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
        let basePieceB = SheetMetal.Flange(
            id: "baseB",
            profile: [SIMD2(28, 0), SIMD2(65, 0), SIMD2(65, 28), SIMD2(28, 28)],
            origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            uAxis: SIMD3(1, 0, 0), vAxis: SIMD3(0, 1, 0))
        let upright = flange(
            "vertical", rect(28, 40), SIMD3(0, 28, 0),
            normal: SIMD3(0, 1, 0), u: SIMD3(1, 0, 0), v: SIMD3(0, 0, 1))
        if let fused = try? SheetMetal.Builder(thickness: 3).build(
            flanges: [basePieceA, basePieceB, upright])
        {
            var found = 0
            for e in fused.edges() where e.isLine {
                let (s0, s1) = e.endpoints
                guard abs(s0.y - 28) < 1e-9, abs(s1.y - 28) < 1e-9 else { continue }
                guard abs(s0.z - 3) < 1e-9, abs(s1.z - 3) < 1e-9 else { continue }
                guard abs(s0.x - s1.x) > 1e-9 else { continue }
                found += 1
                print(
                    "    seam-plane edge: x from " + fmt(min(s0.x, s1.x)) + " to "
                        + fmt(max(s0.x, s1.x)))
            }
            print("    \(found) edge(s) on the seam planes y = 28, z = 3")
            print("    fused volume (no bends) " + fmt(fused.volume ?? -1) + ", expected 8820")
        } else {
            print("    pre-split fuse FAILED")
        }

        print("")
        print("Pre-fillet seam line, diagonal geometry (Issue3033.diagonalSteppedConcave)")
        print(String(repeating: "-", count: 108))
        // The same base and upright with no bend declared, which is exactly the solid `build()`
        // fillets. The seam is diagonal to the base's axes, so `build()` does not split the base,
        // yet the fused solid already holds the chamfer's top edge as separate edges at the
        // contact boundary. That is what lets an extent filter select the bend alone (#3033).
        // Positions are along the chamfer edge from its (20, 12) end; the upright covers 3 to 7.
        let diagRoot: Double = 1.0 / 2.0.squareRoot()
        for (label, start, width) in [("narrow", 3.0, 4.0), ("wide", -3.0, 17.31)] {
            guard
                let bare = try? diagonalUpright(
                    start: start, width: width, down: false, uprightFirst: false,
                    declareBend: false)
            else {
                print("    \(label): fuse FAILED")
                continue
            }
            var runs: [String] = []
            for e in bare.edges() where e.isLine {
                let (p0, p1) = e.endpoints
                guard abs(p0.x + p0.y - 32) < 1e-6, abs(p1.x + p1.y - 32) < 1e-6 else { continue }
                guard abs(p0.z - 2) < 1e-6, abs(p1.z - 2) < 1e-6 else { continue }
                let c0 = (20.0 - p0.x) / diagRoot
                let c1 = (20.0 - p1.x) / diagRoot
                runs.append(String(format: "[%.6f, %.6f]", min(c0, c1), max(c0, c1)))
            }
            print(
                "    \(label) upright: \(runs.count) edge(s) on the chamfer's top line:",
                runs.joined(separator: " "))
        }

        print("")
        print("Diagonal stepped seam survey (#3033): volume over the flange sum")
        print(String(repeating: "-", count: 108))
        // The 20 x 20 base with a chamfered corner and an upright on its 11.31 chamfer edge, every
        // upright width, both bends, both declaration orders. The upright's flange sum is
        // `736 + 20 * width`, so the number printed is what the bend added.
        //
        // Expected on the fixed builder: a concave bend adds r^2 (1 - pi/4) over the run the two
        // share, plus 0.161787 at each end of that run that falls on the base's own corner (where
        // the chamfer meets the base's side faces at 135 degrees); a convex bend adds pi per unit
        // of the shared run; and the two declaration orders agree. A concave bend declared
        // upright first is read as convex by `.auto`, because the base sits on the upright's
        // -normal side, so it adds nothing: that is the documented inference and not a result.
        let surveyEdge: Double = 8.0 * 2.0.squareRoot()
        let flushStart: Double = surveyEdge - 4.0
        let wideWidth: Double = surveyEdge + 6.0
        let wideShort: Double = surveyEdge + 3.0
        var uprights: [(String, Double, Double)] = []
        uprights.append(("spans the edge", 0.0, surveyEdge))
        uprights.append(("narrow, centred", 3.0, 4.0))
        uprights.append(("narrow, flush at the start", 0.0, 4.0))
        uprights.append(("narrow, flush at the end", flushStart, 4.0))
        uprights.append(("wide, centred", -3.0, wideWidth))
        uprights.append(("wide, past the start", -3.0, wideShort))
        uprights.append(("staggered", -3.0, 8.0))
        for down in [false, true] {
            for uprightFirst in [false, true] {
                let kind = down ? "convex, upright hung below" : "concave, upright on top"
                let order = uprightFirst ? "declared upright first" : "declared base first"
                print("  \(kind), \(order)")
                for (name, start, width) in uprights {
                    let flat: Double = 736.0 + 20.0 * width
                    do {
                        let built = try diagonalUpright(
                            start: start, width: width, down: down, uprightFirst: uprightFirst)
                        let v = built.volume ?? Double.nan
                        let added = fmt6(v - flat)
                        print("    \(pad(name, 30)) adds \(added)  valid \(built.isValid)")
                    } catch {
                        print("    \(pad(name, 30)) THREW \(error)")
                    }
                }
            }
        }

        print("")
        print(
            "Fillet run-out at the step boundary (narrowUprightStepSucceeds, r = 1.5, step x = 28)")
        print(String(repeating: "-", count: 108))
        // The void the bend fills is the quadrant y < 28, z > 3 (the upright runs the full height,
        // so the material is y > 28 everywhere plus the base at y < 28, z < 3). The ideal fillet is
        // a prism: at every x in [0, 28] that quadrant is filled out to the cylinder of radius 1.5
        // about (x, 26.5, 4.5). Points are chosen on both sides of that cylinder and at several
        // distances from the step, so a taper or a spill shows up as a classification that changes
        // with x rather than with the radius.
        if let shape = try? fixtures()[2].build() {
            print(
                "    x        (27.7, 3.3) d=1.697 > r, want inside   (27.5, 3.5) d=1.414 < r, want outside"
            )
            for x in [1.0, 14.0, 26.0, 27.5, 27.9, 27.99, 28.01, 28.1, 28.5, 30.0] {
                let filled = shape.classifyPoint(SIMD3(x, 27.7, 3.3))
                let hollow = shape.classifyPoint(SIMD3(x, 27.5, 3.5))
                print(
                    "    " + pad(String(format: "%.2f", x), 9) + pad("\(filled)", 44) + "\(hollow)")
            }
        }

        print("")
        print("Control: the same bend with the step removed (base trimmed to the upright's width)")
        print(String(repeating: "-", count: 108))
        // narrowUprightStepSucceeds with the base 28 wide instead of 65. Same thickness, same
        // radius, same seam length, same flange planes; the ONLY difference is that the seam line
        // now ends at the base's own side faces rather than running on into a flat neighbour, so
        // the fillet has no run-out to close off. If the residual on the stepped fixtures is the
        // run-out, this one lands on `ideal` exactly.
        let narrowBase = flange(
            "base", rect(28, 28), SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0))
        let sameUpright = flange(
            "vertical", rect(28, 40), SIMD3(0, 28, 0),
            normal: SIMD3(0, 1, 0), u: SIMD3(1, 0, 0), v: SIMD3(0, 0, 1))
        if let control = try? SheetMetal.Builder(thickness: 3).build(
            flanges: [narrowBase, sameUpright],
            bends: [SheetMetal.Bend(from: "base", to: "vertical", radius: 1.5)]),
            let cv = control.volume
        {
            let cIdeal: Double = 28.0 * 28.0 * 3.0 + 28.0 * 40.0 * 3.0 + 1.5 * 1.5 * quarter * 28.0
            print(
                "    measured " + fmt(cv) + "   ideal " + fmt(cIdeal) + "   delta "
                    + fmt6(cv - cIdeal))
        } else {
            print("    control build FAILED")
        }

        print("")
        if defects == 0 && probeFailures == 0 {
            print(
                "No fixture matches a defect model, and every probe reads as the construction says."
            )
        } else {
            print(
                "\(defects) fixture(s) match only a defect model, \(probeFailures) probe(s) read wrongly."
            )
        }
    }

    fileprivate static func pad(_ s: String, _ n: Int) -> String {
        s.count >= n ? s + " " : s + String(repeating: " ", count: n - s.count)
    }
    fileprivate static func fmt(_ d: Double) -> String { String(format: "%.12f", d) }
    fileprivate static func fmt6(_ d: Double) -> String { String(format: "%+.6f", d) }
}
