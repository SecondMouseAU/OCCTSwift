import Testing

@testable import OCCTSwift

@Suite("GeomFill, Gordon Surface")
struct GeomFillGordonTests {

    // #2983: the setup guards were `else { return }` escapes, so a nil curve passed having
    // asserted nothing. They are required now.
    @Test func gordonFromLineNetwork() throws {
        // Non-rational control: a flat interpolated grid. Kept to show the builder gets
        // a simple network's corners right, but see
        // gordonRationalQuarterCylinderNetworkMatchesReference below -- this fixture
        // cannot distinguish the p1/8.0.1 kernel difference #645 is actually about,
        // because none of its curves are rational.
        let p1 = try #require(
            Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(5, 0, 0), SIMD3(10, 0, 0)]))
        let p2 = try #require(
            Curve3D.interpolate(points: [SIMD3(0, 10, 0), SIMD3(5, 10, 0), SIMD3(10, 10, 0)]))
        let g1 = try #require(
            Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(0, 5, 0), SIMD3(0, 10, 0)]))
        let g2 = try #require(
            Curve3D.interpolate(points: [SIMD3(10, 0, 0), SIMD3(10, 5, 0), SIMD3(10, 10, 0)]))
        let surf = try #require(
            Surface.gordon(profiles: [p1, p2], guides: [g1, g2], tolerance: 1e-3),
            "gordon surface nil")
        let bounds = surf.parameterBounds
        let corners = [
            surf.point(atU: bounds.uMin, v: bounds.vMin),
            surf.point(atU: bounds.uMax, v: bounds.vMin),
            surf.point(atU: bounds.uMin, v: bounds.vMax),
            surf.point(atU: bounds.uMax, v: bounds.vMax),
        ]
        let expectedCorners: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(0, 10, 0), SIMD3(10, 10, 0),
        ]
        for (got, want) in zip(corners, expectedCorners) {
            #expect(abs(got.x - want.x) < 1e-6)
            #expect(abs(got.y - want.y) < 1e-6)
            #expect(abs(got.z - want.z) < 1e-6)
        }
        // Measured: the flat grid's centre is (5, 5, 0), and the surface is non-rational in both
        // directions. That is the control for the quarter-cylinder test below, which reads both
        // flags true, so a constant-true rationality getter fails here.
        let centre = surf.point(
            atU: (bounds.uMin + bounds.uMax) / 2, v: (bounds.vMin + bounds.vMax) / 2)
        #expect(vectorLength(centre - SIMD3(5, 5, 0)) < 1e-9)
        #expect(!surf.bsplineSurface.isURational)
        #expect(!surf.bsplineSurface.isVRational)
    }

    @Test func gordonTooFewCurves() throws {
        let p1 = try #require(Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]))
        let p2 = try #require(Curve3D.interpolate(points: [SIMD3(0, 10, 0), SIMD3(10, 10, 0)]))
        // Need at least 2 of each; one short in either family is refused (the sibling tests build
        // from two of each, so the refusal is the count and not the curves).
        #expect(Surface.gordon(profiles: [p1], guides: [p1]) == nil)
        #expect(Surface.gordon(profiles: [p1, p2], guides: [p1]) == nil)
        #expect(Surface.gordon(profiles: [p1], guides: [p1, p2]) == nil)
    }

    @Test func gordonRationalQuarterCylinderNetworkMatchesReference() throws {
        // The crux of #645: a rational network's Gordon build checked against a known
        // exact answer, not just non-nil-ness. This is the fixture that would have
        // failed on OCCT 8.0.0p1 (see the module-level comment above).
        let network = try #require(
            makeQuarterCylinderGordonNetwork(), "quarter-cylinder network fixture failed to build")
        let surf = try #require(
            Surface.gordon(profiles: network.profiles, guides: network.guides, tolerance: 1e-6),
            "gordon surface nil for quarter-cylinder network")
        let bsp = surf.bsplineSurface
        #expect(bsp.isURational)
        #expect(bsp.isVRational)
        assertMatchesQuarterCylinder(surf)

        // The reference check reads three points; the whole surface is the cylinder: a 5 by 5
        // grid of samples is 5 from the axis, and its height runs 0 to 10 across the V range.
        let b = surf.parameterBounds
        for i in 0...4 {
            for j in 0...4 {
                let u = b.uMin + (b.uMax - b.uMin) * Double(i) / 4
                let v = b.vMin + (b.vMax - b.vMin) * Double(j) / 4
                let p = surf.point(atU: u, v: v)
                #expect(abs((p.x * p.x + p.y * p.y).squareRoot() - 5) < 1e-6, "(\(i), \(j)): \(p)")
                #expect(p.x > -1e-9 && p.y > -1e-9, "first quadrant at (\(i), \(j)): \(p)")
            }
        }
    }
}
