import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill, Gordon Surface")
struct GeomFillGordonTests {

    @Test func gordonFromLineNetwork() {
        // Non-rational control: a flat interpolated grid. Kept to show the builder gets
        // a simple network's corners right, but see
        // gordonRationalQuarterCylinderNetworkMatchesReference below -- this fixture
        // cannot distinguish the p1/8.0.1 kernel difference #645 is actually about,
        // because none of its curves are rational.
        guard
            let p1 = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(5, 0, 0), SIMD3(10, 0, 0)]),
            let p2 = Curve3D.interpolate(points: [
                SIMD3(0, 10, 0), SIMD3(5, 10, 0), SIMD3(10, 10, 0),
            ]),
            let g1 = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(0, 5, 0), SIMD3(0, 10, 0)]),
            let g2 = Curve3D.interpolate(points: [
                SIMD3(10, 0, 0), SIMD3(10, 5, 0), SIMD3(10, 10, 0),
            ])
        else { return }

        guard let surf = Surface.gordon(profiles: [p1, p2], guides: [g1, g2], tolerance: 1e-3)
        else {
            Issue.record("gordon surface nil")
            return
        }
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
    }

    @Test func gordonTooFewCurves() {
        guard let p1 = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]) else {
            return
        }
        let surf = Surface.gordon(profiles: [p1], guides: [p1])
        #expect(surf == nil)  // need at least 2 each
    }

    @Test func gordonRationalQuarterCylinderNetworkMatchesReference() {
        // The crux of #645: a rational network's Gordon build checked against a known
        // exact answer, not just non-nil-ness. This is the fixture that would have
        // failed on OCCT 8.0.0p1 (see the module-level comment above).
        guard let network = makeQuarterCylinderGordonNetwork() else {
            Issue.record("quarter-cylinder network fixture failed to build")
            return
        }
        guard
            let surf = Surface.gordon(
                profiles: network.profiles, guides: network.guides, tolerance: 1e-6)
        else {
            Issue.record("gordon surface nil for quarter-cylinder network")
            return
        }
        let bsp = surf.bsplineSurface
        #expect(bsp.isURational)
        #expect(bsp.isVRational)
        assertMatchesQuarterCylinder(surf)
    }
}
