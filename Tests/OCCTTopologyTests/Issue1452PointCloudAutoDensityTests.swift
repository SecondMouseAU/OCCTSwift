import Foundation
import Testing

@testable import OCCTSwift

// Issue #1452: `Shape.pointCloudByDensity(0.0)` did not return.
//
// `BRepLib_PointCloudShape::NbPointsByDensity` computes
//   aDensity = (theDensity < Precision::Confusion() ? computeDensity() : theDensity)
// validates `aDensity`, and then divides each face's area by `theDensity`, the caller's original
// argument, rather than by the `aDensity` it just validated. At an exact `0.0`, which is the
// documented way to request auto-density, that is `anArea / 0.0` = `+Infinity`, and
// `(int)std::ceil(+Infinity)` is undefined behaviour. Measured on arm64 macOS it saturates to
// `INT_MAX`, so every face asks `addDensityPoints` for ~2.1 billion points. Reachable on an
// ordinary box. Full writeup and ground-truth probe in
// `Scripts/repro/1440-pointcloud-density-int-overflow/`.
//
// Fixed bridge-side: `OCCTPointCloudCollector::resolveDensity` runs the kernel's own auto-density
// line (`computeDensity()` is protected and the collector is a subclass) and hands the kernel an
// explicit positive density, so `theDensity` equals `aDensity` and the divide is the one the
// author meant. Auto-density keeps working, which a plain input guard rejecting 0.0 would have
// cost.
//
// **These tests cannot be run against the unfixed bridge.** The defect is a non-terminating call,
// not a wrong answer, so the usual "inject the defect, watch the test fail" cycle would hang the
// suite rather than fail it. What was measured instead, once, by hand: the C++ probe in the repro
// directory reproduces `INT_MAX` directly, and reverting `resolveDensity` makes the first test
// below hang instead of returning. That is recorded here rather than automated, deliberately.
@Suite("Issue #1452, auto-density point clouds return instead of hanging")
struct Issue1452PointCloudAutoDensityTests {

    private func meshedBox() -> Shape? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        _ = box.mesh(linearDeflection: 0.5)
        return box
    }

    @Test("density 0.0 requests auto-density and returns a cloud")
    func autoDensityReturns() throws {
        let box = try #require(meshedBox())
        let cloud = try #require(
            box.pointCloudByDensity(0.0),
            "auto-density must produce a cloud, not hang and not refuse")
        #expect(cloud.points.count > 0)
        #expect(cloud.normals.count == cloud.points.count)
    }

    @Test("auto-density is the shape's own density, not an arbitrary substitute")
    func autoDensityMatchesComputedDensity() throws {
        let box = try #require(meshedBox())
        let auto = try #require(box.pointCloudByDensity(0.0))

        // resolveDensity returns computeDensity() for a sub-Confusion argument, so a request just
        // below Precision::Confusion() must resolve to the same density, and therefore the same
        // point count, as an exact 0.0. If the bridge ever substituted a fixed fallback density
        // instead of the shape's own, these two would diverge.
        let alsoAuto = try #require(box.pointCloudByDensity(1e-9))
        #expect(
            auto.points.count == alsoAuto.points.count,
            "0.0 and a sub-Confusion density must both resolve to computeDensity()")
    }

    @Test("an explicit density is still honoured and differs from auto")
    func explicitDensityUnaffected() throws {
        let box = try #require(meshedBox())
        let explicitCloud = try #require(box.pointCloudByDensity(1.0))
        #expect(explicitCloud.points.count > 0)

        // The fix must not have quietly routed every request through computeDensity(): a coarse
        // explicit density and a fine one have to produce different counts.
        let coarse = try #require(box.pointCloudByDensity(25.0))
        #expect(
            coarse.points.count < explicitCloud.points.count,
            "a larger area-per-point must yield fewer points: coarse \(coarse.points.count), fine \(explicitCloud.points.count)"
        )
    }

    @Test("a shape with no faces refuses rather than returning an empty cloud")
    func noFacesRefuses() throws {
        // Measured rather than assumed (probe in Scripts/repro/1452-pointcloud-auto-density/):
        // computeDensity() answers 2e+99 for a shape with no faces, NOT 0.0. It is a min-area
        // search whose accumulator starts enormous and is never reduced when the face loop finds
        // nothing. So the sub-Confusion guard in the bridge does not fire here; what happens is
        // that the face loop has nothing to iterate, zero points are produced, and
        // copyPointCloudResults refuses on a count of 0.
        //
        // Both paths end in nil, which is why this is one test and not two, but they are different
        // mechanisms and the guard is not what makes this one pass.
        let vertex = try #require(Shape.vertex(at: SIMD3(0, 0, 0)))
        #expect(vertex.pointCloudByDensity(0.0) == nil)
    }
}
