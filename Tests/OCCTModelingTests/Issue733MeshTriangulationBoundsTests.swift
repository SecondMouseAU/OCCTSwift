import Testing
import Foundation
@testable import OCCTSwift

// #733 (review of #724): #724's fix compares a candidate wall's `bounds.min.z` against its
// floor's Z within a 1e-4 tolerance (`AAG.defaultFloorRestsOnWallTolerance`). That comparison used
// `Face.bounds`, which calls `BRepBndLib::Add` with `useTriangulation=true` (OCCT's own default).
// OCCT's own header documents the consequence: once a face carries a triangulation, the returned
// box is enlarged by "the sum of the triangulation deflection and the face tolerance", so the
// SAME face reports a looser box after `Shape.mesh(...)` runs than before it, with nothing else
// changing.
//
// Measured directly against this branch, `BRepBndLib.cxx` read alongside to confirm the mechanism
// (`useTriangulation=true` takes the triangulation's `MinMax()` then enlarges by
// `T->Deflection() + BRep_Tool::Tolerance(F)`; `useTriangulation=false` always takes the exact
// analytic branch instead): a planar wall triangulates exactly (zero curvature, zero chordal
// deviation), so a square pocket's four planar walls never drifted, at any deflection. This defect
// is invisible on #724's own square-pocket fixtures. A CURVED wall (the cylindrical bore that is
// #724's own headline fixture) does deviate: at the library's own default deflection (0.1), the
// wall's low-Z bound drifted 0.029 units off the true floor Z, ~290x the 1e-4 tolerance; even the
// finest deflection tried (0.001) still drifted 5x past it. Every drift measured, at every
// deflection from 0.001 to 5.0, exceeded the tolerance, so meshing this shape at all, before
// calling `detectPocketsAAG()`, drops the pocket entirely (`pockets.count` 1 -> 0).
//
// Fixed by giving `AAGNode.bounds` its own bridge call, `OCCTFaceGetBoundsExact`
// (`BRepBndLib::Add(face, box, useTriangulation: false)`), so it reflects only the face's exact
// geometry and never depends on whether anything meshed the shape first. `Face.bounds` (the public
// API existing callers already use) is left unchanged; only `AAG`'s own internal bounds capture
// moved, since AAG's floor/wall matching is about the shape's geometry, never its tessellation.
@Suite("AAG bounds are unaffected by prior meshing (#733)")
struct Issue733MeshTriangulationBoundsTests {

    /// The reproducer: mesh the shape between building it and calling `detectPocketsAAG()`, the
    /// combined workflow this repo's own MCP tools invite (mesh for preview, then recognize
    /// features on the same value). Before the fix this dropped the pocket outright at every
    /// deflection tried; after the fix it must not drop at any of them.
    @Test("meshing a shape before detecting pockets does not drop a real pocket",
          arguments: [0.001, 0.01, 0.1, 0.5, 1.0, 2.0, 5.0])
    func meshingDoesNotDropTheCylindricalPocket(deflection: Double) throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.cylinder(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 4, height: 20))
        let cut = try #require(box.subtracting(tool))

        _ = cut.mesh(linearDeflection: deflection, angularDeflection: 0.5)

        let pockets = cut.detectPocketsAAG()
        #expect(pockets.count == 1, "deflection=\(deflection)")
        guard let pocket = pockets.first else { return }
        #expect(abs(pocket.zLevel - 0.0) < 1e-6, "deflection=\(deflection)")
        #expect(pocket.wallFaceIndices.count == 1, "deflection=\(deflection)")
    }

    /// Non-regression companion: the same fixture, unmeshed, must still report the pocket. A fix
    /// that special-cased "meshed" input rather than making the bounds computation itself
    /// tessellation-independent could pass the test above while being wrong for the ordinary path.
    @Test("the same fixture, never meshed, still reports the pocket")
    func unmeshedFixtureStillReportsThePocket() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.cylinder(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 4, height: 20))
        let cut = try #require(box.subtracting(tool))

        #expect(cut.detectPocketsAAG().count == 1)
    }

    /// Direct measurement of the mechanism, not just its downstream effect: a wall's own
    /// `AAGNode.bounds.min.z` must stay within the tolerance the grouping check applies, regardless
    /// of meshing. Asserts the quantity #724's comparison actually reads, rather than only the
    /// count that comparison feeds.
    @Test("a cylindrical wall's AAGNode bounds do not drift after meshing",
          arguments: [0.001, 0.1, 1.0, 5.0])
    func wallBoundsDoNotDriftAfterMeshing(deflection: Double) throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.cylinder(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 4, height: 20))
        let cut = try #require(box.subtracting(tool))

        _ = cut.mesh(linearDeflection: deflection, angularDeflection: 0.5)

        let aag = cut.buildAAG()
        var checkedAWall = false
        for (index, node) in aag.nodes.enumerated() where node.isUpward && node.isHorizontal && node.isPlanar {
            guard let floorZ = node.zLevel else { continue }
            for wallIndex in aag.concaveNeighbors(of: index) {
                let wall = aag.nodes[wallIndex]
                guard wall.isVertical else { continue }
                checkedAWall = true
                let drift = abs(wall.bounds.min.z - floorZ)
                #expect(drift < 1e-4, "deflection=\(deflection) drift=\(drift)")
            }
        }
        #expect(checkedAWall, "fixture produced no candidate wall to check, test is vacuous")
    }

    /// Direct value-level check of `Face.exactBounds` itself, not through `AAGNode.bounds` (#908).
    /// `wallBoundsDoNotDriftAfterMeshing` above only ever reads `.min.z`, so it cannot tell a
    /// min/max swap from a correct read on the other 5 of 6 min/max values `exactBounds` returns.
    /// Every face of an axis-aligned box has exactly two non-degenerate axes (spanning the box's
    /// full extent, `min < max`) and one degenerate axis (the face's own plane, `min == max`), so
    /// checking `min <= max` on all three axes of all six faces directly exercises the ordering a
    /// swap breaks, with no need to know which face is which.
    @Test("exactBounds min is never greater than max, on any axis of any face")
    func exactBoundsMinNeverExceedsMax() throws {
        let box = try #require(Shape.box(width: 20, height: 10, depth: 6))
        var checkedNonDegenerateAxis = false
        for face in box.faces() {
            let b = face.exactBounds
            for (lo, hi) in [(b.min.x, b.max.x), (b.min.y, b.max.y), (b.min.z, b.max.z)] {
                #expect(lo <= hi + 1e-9, "min=\(lo) exceeds max=\(hi)")
                if hi - lo > 1e-6 { checkedNonDegenerateAxis = true }
            }
        }
        #expect(checkedNonDegenerateAxis, "no face produced a non-degenerate axis to check, test is vacuous")
    }
}

// #733, second finding: `floorRestsOnWallTolerance` was a `private static let`, the only
// hardcoded, non-configurable tolerance anywhere in this module (every other tolerance in
// `Curve3D`, `Surface`, `Shape`, etc., 296 occurrences total, is a caller-supplied parameter with
// a default). A shape modeled in meters or thousandths of an inch has no way to widen or narrow
// the 1e-4 default to match its own scale. Fixed by promoting it to a `tolerance:` parameter on
// both `AAG.detectPockets(tolerance:)` and `Shape.detectPocketsAAG(tolerance:)`, defaulting to the
// same 1e-4 (now `AAG.defaultFloorRestsOnWallTolerance`, a public constant), so existing call
// sites are unaffected and only a caller who explicitly wants a different value needs to know it
// exists.
@Suite("detectPocketsAAG(tolerance:) is caller-configurable (#733)")
struct Issue733ConfigurableToleranceTests {
    /// An absurdly tight tolerance (tighter than the ~1e-7 floating-point noise `exactBounds`
    /// itself carries on an exact primitive) must reject even a real, exactly-modeled pocket,
    /// proving the parameter actually reaches the comparison, not just that it type-checks.
    @Test("an absurdly tight tolerance rejects a real pocket")
    func absurdlyTightToleranceRejectsRealPocket() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let result = try #require(box.subtracting(pocketTool))

        #expect(result.detectPocketsAAG().count == 1)
        #expect(result.detectPocketsAAG(tolerance: 1e-12).count == 0)
    }

    /// The same absurdly tight tolerance reaches `AAG.detectPockets(tolerance:)` directly, not
    /// only through the `Shape` convenience wrapper: both entry points take the parameter.
    @Test("AAG.detectPockets(tolerance:) itself honors a tight tolerance")
    func aagDetectPocketsHonorsTolerance() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let result = try #require(box.subtracting(pocketTool))
        let aag = result.buildAAG()

        #expect(aag.detectPockets().count == 1)
        #expect(aag.detectPockets(tolerance: 1e-12).count == 0)
    }

    /// A caller who explicitly widens the tolerance (e.g. for a coarser model scale) must still
    /// find the pocket: the parameter is not a one-way ratchet toward stricter answers only.
    @Test("a generous tolerance still finds the pocket")
    func generousToleranceStillFindsPocket() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let result = try #require(box.subtracting(pocketTool))

        #expect(result.detectPocketsAAG(tolerance: 1.0).count == 1)
    }
}
