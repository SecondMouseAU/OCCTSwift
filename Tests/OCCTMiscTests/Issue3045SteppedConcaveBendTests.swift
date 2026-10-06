import Foundation
import Testing

@testable import OCCTSwift

/// #3045: a stepped concave bend returned `isValid == false`, and a wrong volume once the radius
/// passed the thickness.
///
/// Both came from `BRepFilletAPI_MakeFillet`'s run-out at the end of a seam that stops short of
/// the flanges' own edges. The solid the fillet starts from was valid in every case, and the
/// concave bend now fuses in the fillet's material as a prism instead, so it ends flush at the
/// bend's run and adds exactly `r^2 (1 - pi/4)` per unit of seam at a right angle.
///
/// Every volume here is a closed form, flange bodies less their overlap plus the bend material,
/// never a pin of what the builder returned. The fixtures are the issue's table.
@Suite("Issue #3045: stepped concave bend validity and volume")
struct Issue3045SteppedConcaveBendTests {

    /// `1 - pi/4`: `r^2` times this is the area a 90 degree concave fillet adds per unit of seam.
    private static let quarter: Double = 1.0 - Double.pi / 4.0

    /// The foot under a wider web.
    ///
    /// The foot is y in [10, 35], x in [0, 30], below z = 0. The web is y in [0, 45], standing on
    /// it at x in [28, 30], `webHeight` high. The bodies only touch.
    private static func footAndWeb(
        webHeight: Double
    ) -> (foot: SheetMetal.Flange, web: SheetMetal.Flange) {
        let foot = SheetMetal.Flange(
            id: "foot",
            profile: [SIMD2(10, 0), SIMD2(35, 0), SIMD2(35, 30), SIMD2(10, 30)],
            origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, -1),
            uAxis: SIMD3(0, 1, 0), vAxis: SIMD3(1, 0, 0))
        let web = SheetMetal.Flange(
            id: "web",
            profile: [
                SIMD2(0, 0), SIMD2(webHeight, 0), SIMD2(webHeight, 45), SIMD2(0, 45),
            ],
            origin: SIMD3(30, 0, 0), normal: SIMD3(-1, 0, 0),
            uAxis: SIMD3(0, 0, 1), vAxis: SIMD3(0, 1, 0))
        return (foot, web)
    }

    // The radii are the issue's table: valid below the thickness (2), invalid at it, and wrong
    // in volume above it.
    private static let radii: [Double] = [0.5, 1.0, 1.5, 1.9, 2.0, 2.5, 3.0, 6.0]

    /// A single walk over the radii and both web heights rather than `@Test(arguments:)`, so a
    /// failure names the construction.
    @Test("foot under a wider web is valid and on its closed form at every radius")
    func footUnderWiderWeb() throws {
        for webHeight in [20.0, 12.0] {
            for r in Self.radii {
                let (foot, web) = Self.footAndWeb(webHeight: webHeight)
                let shape = try SheetMetal.Builder(thickness: 2).build(
                    flanges: [foot, web],
                    bends: [SheetMetal.Bend(from: "web", to: "foot", radius: r)])
                let label = "web \(webHeight) high, r = \(r)"
                #expect(shape.isValid, "\(label): not a valid solid")
                #expect(shape.subShapes(ofType: .solid).count == 1, "\(label): not one solid")
                // foot 25 x 30 x 2 = 1500, web h x 45 x 2, the bend covers the foot's 25.
                let derived = 1500.0 + webHeight * 45.0 * 2.0 + 25.0 * r * r * Self.quarter
                let v = shape.volume ?? -1
                #expect(abs(v - derived) < 1e-6, "\(label): volume \(v) against \(derived)")
                // The fillet's material fills the corner and the circle it rolls stays empty,
                // so the point probes read the shape and not only a volume tolerance.
                #expect(
                    shape.classifyPoint(SIMD3(28 - 0.05 * r, 22, 0.05 * r)) == .inside,
                    "\(label): the corner is not filled")
                #expect(
                    shape.classifyPoint(SIMD3(28 - r, 22, r)) == .outside,
                    "\(label): the rolled circle's centre is not empty")
                // The run is the foot's 25 and no more: beside the foot the web's face is flat.
                #expect(
                    shape.classifyPoint(SIMD3(28 - 0.5 * r, 5, 0.5 * r)) == .outside,
                    "\(label): material outside the bend's run")
            }
        }
    }

    /// Thickness 3 moves the threshold the issue found (r = t), so a fix keyed on 2 fails here.
    @Test("the threshold follows the thickness, not a constant")
    func thresholdFollowsThickness() throws {
        let (foot, web) = Self.footAndWeb(webHeight: 20)
        for r in [2.0, 3.0, 3.5, 5.0] {
            let shape = try SheetMetal.Builder(thickness: 3).build(
                flanges: [foot, web],
                bends: [SheetMetal.Bend(from: "web", to: "foot", radius: r)])
            #expect(shape.isValid, "r = \(r): not a valid solid")
            // At thickness 3 the web stands at x in [27, 30] and the bodies interpenetrate, so the
            // closed form is the same flanges with no bend, which is the fused volume, plus the
            // bend's added material.
            let sharp = try SheetMetal.Builder(thickness: 3).build(flanges: [foot, web])
            let v = shape.volume ?? -1
            let derived = (sharp.volume ?? -1) + 25.0 * r * r * Self.quarter
            #expect(abs(v - derived) < 1e-6, "r = \(r): volume \(v) against \(derived)")
        }
    }

    /// The mid-to-top bend of the pinned Z-bracket, built alone.
    ///
    /// The top tab is 20 wide on a full width mid of 50, so the top's seam is stepped.
    @Test("zBracket's stepped mid-to-top bend is valid and exact at r = 1.5 and 3")
    func zBracketMidToTop() throws {
        let mid = SheetMetal.Flange(
            id: "mid",
            profile: [SIMD2(0, 0), SIMD2(50, 0), SIMD2(50, 20), SIMD2(0, 20)],
            origin: SIMD3(0, 30, 0), normal: SIMD3(0, 1, 0),
            uAxis: SIMD3(1, 0, 0), vAxis: SIMD3(0, 0, 1))
        let top = SheetMetal.Flange(
            id: "top",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 30), SIMD2(0, 30)],
            origin: SIMD3(15, 30, 20), normal: SIMD3(0, 0, 1),
            uAxis: SIMD3(1, 0, 0), vAxis: SIMD3(0, 1, 0))
        for r in [1.5, 3.0] {
            let shape = try SheetMetal.Builder(thickness: 2).build(
                flanges: [mid, top],
                bends: [SheetMetal.Bend(from: "mid", to: "top", radius: r)])
            #expect(shape.isValid, "r = \(r): not a valid solid")
            // mid 50 x 20 x 2 = 2000 and top 20 x 30 x 2 = 1200 only touch; the bend covers 20.
            let derived = 3200.0 + 20.0 * r * r * Self.quarter
            let v = shape.volume ?? -1
            #expect(abs(v - derived) < 1e-6, "r = \(r): volume \(v) against \(derived)")
        }
    }

    /// A top flange running into a web it is narrower than, where the bodies interpenetrate:
    /// invalid at every radius, at both thicknesses, with the volume exact.
    @Test("a narrower top running into the web is valid at every radius")
    func narrowTopIntoWeb() throws {
        for t in [2.0, 3.0] {
            for r in [0.5, 1.0, 2.0, 3.0, 4.0] {
                let top = SheetMetal.Flange(
                    id: "top",
                    profile: [SIMD2(0, 0), SIMD2(30, 0), SIMD2(30, 30), SIMD2(0, 30)],
                    origin: SIMD3(0, 5, 0), normal: SIMD3(0, 0, 1),
                    uAxis: SIMD3(1, 0, 0), vAxis: SIMD3(0, 1, 0))
                let web = SheetMetal.Flange(
                    id: "web",
                    profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 40), SIMD2(0, 40)],
                    origin: SIMD3(30, 0, 0), normal: SIMD3(-1, 0, 0),
                    uAxis: SIMD3(0, 0, 1), vAxis: SIMD3(0, 1, 0))
                let shape = try SheetMetal.Builder(thickness: t).build(
                    flanges: [top, web],
                    bends: [SheetMetal.Bend(from: "top", to: "web", radius: r)])
                let label = "thickness \(t), r = \(r)"
                #expect(shape.isValid, "\(label): not a valid solid")
                // top 30 x 30 x t, web 20 x 40 x t, interpenetrating over t x t x 30.
                let derived =
                    900.0 * t + 800.0 * t - t * t * 30.0 + 30.0 * r * r * Self.quarter
                let v = shape.volume ?? -1
                #expect(abs(v - derived) < 1e-6, "\(label): volume \(v) against \(derived)")
            }
        }
    }

    /// A 20 wide base butting an 80 wide tab, in both declaration orders.
    ///
    /// The pinned `lBracketStepSeamCentredTab` has the widths the other way round.
    @Test("a narrow base butting a wide tab is valid in both declaration orders")
    func narrowBaseWideTab() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 40), SIMD2(0, 40)],
            origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            uAxis: SIMD3(1, 0, 0), vAxis: SIMD3(0, 1, 0))
        let tab = SheetMetal.Flange(
            id: "tab",
            profile: [SIMD2(0, 0), SIMD2(80, 0), SIMD2(80, 30), SIMD2(0, 30)],
            origin: SIMD3(-30, 40, 0), normal: SIMD3(0, 1, 0),
            uAxis: SIMD3(1, 0, 0), vAxis: SIMD3(0, 0, 1))
        let bends = [SheetMetal.Bend(from: "base", to: "tab", radius: 1.5)]
        // base 20 x 40 x 2 = 1600 and tab 80 x 30 x 2 = 4800 only touch; the bend covers 20.
        let derived = 6400.0 + 20.0 * 1.5 * 1.5 * Self.quarter
        for flanges in [[base, tab], [tab, base]] {
            let shape = try SheetMetal.Builder(thickness: 2).build(flanges: flanges, bends: bends)
            let order = flanges.map(\.id).joined(separator: ", ")
            #expect(shape.isValid, "[\(order)]: not a valid solid")
            let v = shape.volume ?? -1
            #expect(abs(v - derived) < 1e-6, "[\(order)]: volume \(v) against \(derived)")
        }
    }

    /// A radius that reaches past a flange's face is refused by name.
    ///
    /// There is no fillet to be had, since the tangent line would leave the metal, and the
    /// fillet always refused it. It is not returned as a solid.
    @Test("a radius reaching past a flange's face is refused, not returned")
    func radiusPastTheFaceIsRefused() {
        // The foot's top face reaches 1 from the corner (x in [27, 28]).
        let foot = SheetMetal.Flange(
            id: "foot",
            profile: [SIMD2(10, 27), SIMD2(35, 27), SIMD2(35, 30), SIMD2(10, 30)],
            origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, -1),
            uAxis: SIMD3(0, 1, 0), vAxis: SIMD3(1, 0, 0))
        let web = Self.footAndWeb(webHeight: 20).web
        let error = #expect(throws: SheetMetal.BuildError.self) {
            try SheetMetal.Builder(thickness: 2).build(
                flanges: [foot, web],
                bends: [SheetMetal.Bend(from: "web", to: "foot", radius: 5)])
        }
        guard case .filletFailed? = error else {
            Issue.record("expected filletFailed, got \(String(describing: error))")
            return
        }
    }

    /// The prism is built from the wedge between the two faces, not from a right angle, so a wall
    /// leaning out or in gets the fillet of its own opening `alpha`, which adds
    /// `r^2 / tan(alpha / 2) - r^2 (pi - alpha) / 2` per unit of seam.
    ///
    /// The wall's inner face meets the foot's top face on x = 28 at every lean, and the wall is
    /// extended 3 below that line so its bottom is buried in the foot and the bodies overlap
    /// rather than touching along a line.
    @Test("a wall leaning out or in is rounded for its own opening angle")
    func leaningWall() throws {
        let t = 2.0
        let foot = Self.footAndWeb(webHeight: 20).foot
        for lean in [30.0, -30.0, 60.0, -60.0] {
            for r in [0.5, 1.5, 3.0] {
                let lam = lean * Double.pi / 180
                let up = SIMD3<Double>(sin(lam), 0, cos(lam))
                let normal = SIMD3<Double>(-cos(lam), 0, sin(lam))
                let wall = SheetMetal.Flange(
                    id: "web",
                    profile: [SIMD2(-3, 0), SIMD2(20, 0), SIMD2(20, 45), SIMD2(-3, 45)],
                    origin: SIMD3(28, 0, 0) - t * normal, normal: normal,
                    uAxis: up, vAxis: SIMD3(0, 1, 0))
                let builder = SheetMetal.Builder(thickness: t)
                let sharp = try builder.build(flanges: [foot, wall])
                let shape = try builder.build(
                    flanges: [foot, wall],
                    bends: [SheetMetal.Bend(from: "web", to: "foot", radius: r)])
                let label = "lean \(lean), r = \(r)"
                #expect(shape.isValid, "\(label): not a valid solid")
                // The wedge between the foot's top face (towards -x) and the wall's inner face
                // (up the wall) opens by 90 degrees plus the lean.
                let alpha = Double.pi / 2 + lam
                let area = r * r / tan(alpha / 2) - r * r * (Double.pi - alpha) / 2
                let derived = (sharp.volume ?? -1) + 25.0 * area
                let v = shape.volume ?? -1
                #expect(abs(v - derived) < 1e-6, "\(label): volume \(v) against \(derived)")
                // The corner is filled and the rolled circle's centre, on the bisector, is not.
                let bisector = try #require(Vector3DMath.normalize(SIMD3(-1, 0, 0) + up))
                let corner = SIMD3<Double>(28, 22, 0)
                // Half way from the corner to the arc's nearest point.
                let gap = r / sin(alpha / 2) - r
                #expect(
                    shape.classifyPoint(corner + 0.5 * gap * bisector) == .inside,
                    "\(label): the corner is not filled")
                #expect(
                    shape.classifyPoint(corner + (r / sin(alpha / 2)) * bisector) == .outside,
                    "\(label): the rolled circle's centre is not empty")
            }
        }
    }
}
