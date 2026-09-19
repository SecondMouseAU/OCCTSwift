import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Contap Contour Analysis")
struct ContapContourTests {
    @Test("Sphere contour with direction")
    func sphereContourDir() {
        let result = Shape.contourSphereDir(
            center: SIMD3(0, 0, 0), radius: 10,
            direction: SIMD3(0, 0, 1))
        if let result = result {
            #expect(result.count > 0)
            #expect(result.type == .circle)
            // Contour circle radius should be ~10 for Z-aligned view
            #expect(abs(result.data[3] - 10.0) < 0.1)
        }
    }

    @Test("Cylinder contour with direction")
    func cylinderContourDir() {
        let result = Shape.contourCylinderDir(
            origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            radius: 5, direction: SIMD3(1, 0, 0))
        if let result = result {
            #expect(result.count > 0)
            #expect(result.type == .line)
        }
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

    @Test("Sphere contour with eye point")
    func sphereContourEye() {
        let result = Shape.contourSphereEye(
            center: SIMD3(0, 0, 0), radius: 10,
            eye: SIMD3(100, 0, 0))
        if let result = result {
            #expect(result.count > 0)
        }
    }
}
