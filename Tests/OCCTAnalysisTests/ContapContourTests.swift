import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Contap Contour Analysis")
struct ContapContourTests {
    /// Values in this suite are `Contap_ContAna`'s on the pinned kernel
    /// (`Scripts/repro/766-contap-contour/`). Each test requires a result: the old `if let` forms
    /// passed when the bridge returned nil.
    @Test("Sphere contour with direction")
    func sphereContourDir() throws {
        let result = try #require(
            Shape.contourSphereDir(
                center: SIMD3(0, 0, 0), radius: 10,
                direction: SIMD3(0, 0, 1)))
        #expect(result.count == 1)
        #expect(result.type == .circle)
        // A view along the axis sees the equator: centre at the origin, radius 10.
        #expect(simd_length(SIMD3(result.data[0], result.data[1], result.data[2])) < 1e-12)
        #expect(abs(result.data[3] - 10.0) < 1e-12)
    }

    @Test("Cylinder contour with direction")
    func cylinderContourDir() throws {
        let result = try #require(
            Shape.contourCylinderDir(
                origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
                radius: 5, direction: SIMD3(1, 0, 0)))
        #expect(result.count == 2)
        #expect(result.type == .line)
        // The two rulings at y = +5 and y = -5, both along the axis.
        let loc1 = SIMD3(result.data[0], result.data[1], result.data[2])
        let loc2 = SIMD3(result.data[6], result.data[7], result.data[8])
        #expect(simd_length(loc1 - SIMD3(0, 5, 0)) < 1e-12, "line 1 at \(loc1)")
        #expect(simd_length(loc2 - SIMD3(0, -5, 0)) < 1e-12, "line 2 at \(loc2)")
    }

    /// #1416: `Contap_ContAna::Perform(gp_Cylinder, gp_Dir)` (`Contap_ContAna.cxx`) sets `nbSol`
    /// to exactly 0 or 2 on its only success path, never 1 -- a cylinder's silhouette against a
    /// non-axis-parallel view direction is always the *pair* of tangent rulings either side of
    /// the axis. `OCCTContapCylinderDir` used to read only `Line(1)`, silently discarding
    /// `Line(2)` while still reporting `count == 2`. This test asserts both lines' actual
    /// geometry, computed independently of the bridge, so the pre-fix bridge (which left
    /// `data[6...11]` at its zero-initialized default, since it never wrote past index 5) fails
    /// this exact assertion: `loc2` would read as the origin, not the true second tangent line.
    @Test("Cylinder contour with non-axis-parallel direction returns both tangent lines")
    func cylinderContourDirBothLines() {
        let origin = SIMD3<Double>(0, 0, 0)
        let axis = SIMD3<Double>(0, 0, 1)
        let radius = 5.0
        // Oblique (not axis-parallel, not axis-perpendicular) view direction so the fixture
        // isn't a symmetric special case.
        let direction = SIMD3<Double>(2, 1, 0.5).normalized

        guard
            let result = Shape.contourCylinderDir(
                origin: origin, axis: axis, radius: radius, direction: direction)
        else {
            Issue.record("expected a contour result for a non-degenerate cylinder view direction")
            return
        }

        #expect(result.type == .line)
        #expect(result.count == 2)
        #expect(result.data.count == 12)

        // Expected geometry: both tangent lines run parallel to the axis, offset from the
        // origin by +/- radius along normalize(axis x direction) (the OCCT kernel's own
        // construction, re-derived here rather than copied, per Contap_ContAna.cxx).
        let normale = simd_cross(axis, direction).normalized
        let expectedLoc1 = origin + radius * normale
        let expectedLoc2 = origin - radius * normale

        let loc1 = SIMD3(result.data[0], result.data[1], result.data[2])
        let dir1 = SIMD3(result.data[3], result.data[4], result.data[5])
        let loc2 = SIMD3(result.data[6], result.data[7], result.data[8])
        let dir2 = SIMD3(result.data[9], result.data[10], result.data[11])

        let tol = 1e-9
        #expect(simd_length(loc1 - expectedLoc1) < tol)
        #expect(simd_length(dir1 - axis) < tol)
        #expect(simd_length(loc2 - expectedLoc2) < tol)
        #expect(simd_length(dir2 - axis) < tol)

        // The two lines are genuinely distinct: mirror-image locations either side of the axis.
        #expect(simd_length(loc2) > 1.0)
        #expect(simd_length(loc1 - loc2) > 1.0)
    }

    /// From an eye at distance d = 100 a sphere of radius r = 10 shows a circle centred r^2/d = 1
    /// along the view axis, of radius r * sqrt(1 - (r/d)^2) = 9.9498743710662.
    @Test("Sphere contour with eye point")
    func sphereContourEye() throws {
        let result = try #require(
            Shape.contourSphereEye(
                center: SIMD3(0, 0, 0), radius: 10,
                eye: SIMD3(100, 0, 0)))
        #expect(result.count == 1)
        #expect(result.type == .circle)
        let centre = SIMD3(result.data[0], result.data[1], result.data[2])
        #expect(simd_length(centre - SIMD3(1, 0, 0)) < 1e-12, "centre \(centre)")
        #expect(abs(result.data[3] - 10 * (0.99).squareRoot()) < 1e-12, "radius \(result.data[3])")
    }
}
