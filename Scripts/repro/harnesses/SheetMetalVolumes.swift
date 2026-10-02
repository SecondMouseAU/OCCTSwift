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
// `swift run Harnesses 2972-sheetmetal-volumes`

import Foundation
import OCCTSwift

// Everything here is `fileprivate`: the harnesses directory is one compilation target.
fileprivate let quarter = 1.0 - Double.pi / 4.0

/// One bend's contribution, in the form the construction is supposed to produce.
fileprivate enum BendTerm {
    /// A concave bend: the fillet fills the inside corner, adding `radius^2 (1 - pi/4)` per unit.
    case concave(radius: Double, length: Double)
    /// A convex bend: a quarter-disc prism of radius `thickness`, adding `(pi/4) t^2` per unit.
    case convex(thickness: Double, length: Double)
    /// Seam line outside the bend's own extent. Not a bend at all; the free edge there is convex,
    /// so a fillet rolled along it REMOVES `radius^2 (1 - pi/4)` per unit.
    case surplus(radius: Double, length: Double)

    var idealContribution: Double {
        switch self {
        case .concave(let r, let l): return r * r * quarter * l
        case .convex(let t, let l): return (Double.pi / 4.0) * t * t * l
        case .surplus: return 0
        }
    }

    var leakedContribution: Double {
        switch self {
        case .surplus(let r, let l): return -r * r * quarter * l
        default: return 0
        }
    }
}

fileprivate struct Fixture {
    let name: String
    /// Sum of each flange's own extruded volume, before any body-body overlap is deducted.
    let flangeSum: Double
    /// Volume counted twice by `flangeSum` because two flange bodies interpenetrate.
    let overlap: Double
    let terms: [BendTerm]
    /// The volume currently pinned in `Tests/OCCTMiscTests/OCCTMiscTests.swift`.
    let pinned: Double
    let build: () throws -> Shape
    /// A point just inside the base flange's free corner, outside every bend's extent, or nil
    /// where the fixture has no stepped seam.
    let sharpCornerProbe: SIMD3<Double>?

    var ideal: Double { flangeSum - overlap + terms.reduce(0) { $0 + $1.idealContribution } }
    var leaked: Double { ideal + terms.reduce(0) { $0 + $1.leakedContribution } }
}

fileprivate func flange(
    _ id: String, _ profile: [SIMD2<Double>], _ origin: SIMD3<Double>,
    normal: SIMD3<Double>, u: SIMD3<Double>, v: SIMD3<Double>? = nil
) -> SheetMetal.Flange {
    SheetMetal.Flange(
        id: id, profile: profile, origin: origin, normal: normal, uAxis: u, vAxis: v)
}

fileprivate func rect(_ w: Double, _ h: Double) -> [SIMD2<Double>] {
    [SIMD2(0, 0), SIMD2(w, 0), SIMD2(w, h), SIMD2(0, h)]
}

enum SheetMetalVolumes {

    fileprivate static func fixtures() -> [Fixture] {
        [
            // --- full-seam concave, the two the issue already derives ---
            Fixture(
                name: "SheetMetalTests.lBracket",
                flangeSum: 65 * 28 * 3 + 65 * 40 * 3,
                overlap: 0,
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
                sharpCornerProbe: nil),
            Fixture(
                name: "SheetMetalTests.uChannel",
                flangeSum: 40 * 20 * 2 + 2 * (20 * 15 * 2),
                overlap: 0,
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
                sharpCornerProbe: nil),

            // --- stepped seams: base 65 wide, upright 28 wide, so 37 of surplus ---
            Fixture(
                name: "SheetMetalTests.narrowUprightStepSucceeds",
                flangeSum: 65 * 28 * 3 + 28 * 40 * 3,
                overlap: 0,
                terms: [
                    .concave(radius: 1.5, length: 28),
                    .surplus(radius: 1.5, length: 65 - 28),
                ],
                pinned: 8815.654315677795,
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
                sharpCornerProbe: SIMD3(50, 27.8, 2.8)),
            Fixture(
                name: "SheetMetalTests.lBracketStepSeamCentredTab",
                flangeSum: 80 * 40 * 2 + 20 * 30 * 2,
                overlap: 0,
                terms: [
                    .concave(radius: 1.5, length: 20),
                    .surplus(radius: 1.5, length: 30),
                    .surplus(radius: 1.5, length: 30),
                ],
                pinned: 7580.685854250031,
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
                sharpCornerProbe: SIMD3(10, 39.8, 1.8)),
            Fixture(
                name: "SheetMetalTests.zBracket",
                flangeSum: 50 * 30 * 2 + 50 * 20 * 2 + 20 * 30 * 2,
                overlap: 0,
                terms: [
                    .concave(radius: 1.5, length: 50),
                    .concave(radius: 1.5, length: 20),
                    .surplus(radius: 1.5, length: 30),
                ],
                pinned: 6219.3141848384885,
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
                sharpCornerProbe: SIMD3(5, 31.8, 19.8)),
            Fixture(
                name: "SheetMetalTests.uChannelStepped",
                flangeSum: 40 * 100 * 2 + 2 * (80 * 15 * 2),
                overlap: 0,
                terms: [
                    .concave(radius: 1.5, length: 80),
                    .concave(radius: 1.5, length: 80),
                    .surplus(radius: 1.5, length: 10),
                    .surplus(radius: 1.5, length: 10),
                    .surplus(radius: 1.5, length: 10),
                    .surplus(radius: 1.5, length: 10),
                ],
                pinned: 12857.94265223678,
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
                sharpCornerProbe: SIMD3(0.2, 5, 1.8)),

            // --- convex bends ---
            Fixture(
                name: "ConvexBendIssue89.zBracketRepro",
                flangeSum: 18 * 45 * 3.2 + 25 * 45 * 3.2 + 45 * 45 * 3.2,
                overlap: 3.2 * 3.2 * 45,
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
                sharpCornerProbe: nil),
            Fixture(
                name: "ConvexBendIssue89.symmetricZ",
                flangeSum: 30 * 45 * 2 + 20 * 45 * 2 + 30 * 45 * 2,
                overlap: 2 * 2 * 45,
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
                sharpCornerProbe: nil),
            Fixture(
                name: "ConvexBendIssue89.offsetLShortWeb",
                flangeSum: 50 * 60 * 2 + 5 * 60 * 2 + 50 * 60 * 2,
                overlap: 2 * 2 * 60,
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
                sharpCornerProbe: nil),
            Fixture(
                name: "ConvexBendIssue89.channelWithFlange",
                flangeSum: 100 * 40 * 1.5 + 2 * (30 * 40 * 1.5) + 20 * 40 * 1.5,
                overlap: 2 * (1.5 * 1.5 * 40),
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
                sharpCornerProbe: nil),
        ]
    }

    static func run() {
        print("#2972: SheetMetal volumes against a term-by-term prediction")
        print(String(repeating: "=", count: 108))
        print(
            "ideal  = flanges - overlap + concave r^2(1-pi/4)L + convex (pi/4)t^2 L")
        print(
            "leaked = ideal - r^2(1-pi/4)L over every seam run OUTSIDE the bend's own extent")
        print("")
        print(
            pad("fixture", 42) + pad("measured", 22) + pad("ideal", 14) + pad("leaked", 14)
                + "verdict")
        print(String(repeating: "-", count: 108))

        var defects = 0
        for f in fixtures() {
            guard let shape = try? f.build(), let v = shape.volume else {
                print(pad(f.name, 42) + "BUILD FAILED")
                continue
            }
            let dIdeal = v - f.ideal
            let dLeaked = v - f.leaked
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
            } else {
                verdict = "unexplained"
            }
            print(
                pad(f.name, 42) + pad(fmt(v), 22) + pad(fmt6(dIdeal), 14) + pad(fmt6(dLeaked), 14)
                    + verdict)
            if abs(v - f.pinned) > 1e-9 * max(1.0, f.pinned) {
                print(
                    "    NOTE: differs from the pinned value \(fmt(f.pinned)) by "
                        + fmt6(v - f.pinned))
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
        print("Fillet run-out at the step boundary (narrowUprightStepSucceeds, r = 1.5, step x = 28)")
        print(String(repeating: "-", count: 108))
        // The void the bend fills is the quadrant y < 28, z > 3 (the upright runs the full height,
        // so the material is y > 28 everywhere plus the base at y < 28, z < 3). The ideal fillet is
        // a prism: at every x in [0, 28] that quadrant is filled out to the cylinder of radius 1.5
        // about (x, 26.5, 4.5). Points are chosen on both sides of that cylinder and at several
        // distances from the step, so a taper or a spill shows up as a classification that changes
        // with x rather than with the radius.
        if let shape = try? fixtures()[2].build() {
            print("    x        (27.7, 3.3) d=1.697 > r, want inside   (27.5, 3.5) d=1.414 < r, want outside")
            for x in [1.0, 14.0, 26.0, 27.5, 27.9, 27.99, 28.01, 28.1, 28.5, 30.0] {
                let filled = shape.classifyPoint(SIMD3(x, 27.7, 3.3))
                let hollow = shape.classifyPoint(SIMD3(x, 27.5, 3.5))
                print("    " + pad(String(format: "%.2f", x), 9) + pad("\(filled)", 44) + "\(hollow)")
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
            let cIdeal = 28 * 28 * 3 + 28 * 40 * 3 + 1.5 * 1.5 * quarter * 28
            print("    measured " + fmt(cv) + "   ideal " + fmt(cIdeal) + "   delta " + fmt6(cv - cIdeal))
        } else {
            print("    control build FAILED")
        }

        print("")
        print(
            defects == 0
                ? "No fixture needs the surplus term to explain its volume."
                : "\(defects) fixture(s) match only once the surplus fillet is subtracted.")
    }

    fileprivate static func pad(_ s: String, _ n: Int) -> String {
        s.count >= n ? s + " " : s + String(repeating: " ", count: n - s.count)
    }
    fileprivate static func fmt(_ d: Double) -> String { String(format: "%.12f", d) }
    fileprivate static func fmt6(_ d: Double) -> String { String(format: "%+.6f", d) }
}
