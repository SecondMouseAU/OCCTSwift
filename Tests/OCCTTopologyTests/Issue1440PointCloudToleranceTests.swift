import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1440 finding 3: `OCCTPointCloudCollector` (`Sources/OCCTBridge/src/OCCTBridge_Mesh.mm`,
/// backing `Shape.pointCloudByTriangulation()`/`pointCloudByDensity(_:)`) constructed its
/// `BRepLib_PointCloudShape` base with a hardcoded tolerance of `0.0`, instead of the class's own
/// documented default `Precision::Confusion()` (`BRepLib_PointCloudShape.hxx:36-37`).
///
/// `myTol` gates a degenerate/near-zero-area-face filter in `computeDensity()`
/// (`if (anArea < myTol * myTol) continue;`), reached whenever `NbPointsByDensity`'s auto-density
/// path runs (any requested density `< Precision::Confusion()`, not just exactly `0.0` --
/// `BRepLib_PointCloudShape.cxx:52`). At `myTol == 0.0` that filter never rejects any
/// non-negative area, so a genuinely near-zero-area face can win the "smallest face" search
/// `computeDensity()` runs, and poisons the auto-computed density down to (effectively) zero:
/// `NbPointsByDensity` then returns 0 points and the whole call fails, even though the shape has
/// plenty of ordinary surface area a correctly-filtered auto-density would have used instead.
///
/// **Why this test deliberately does NOT use `density: 0.0`**, the seemingly-obvious way to
/// exercise "auto-density": `NbPointsByDensity`'s per-face point count
/// (`BRepLib_PointCloudShape.cxx:63`, `std::ceil(anArea / theDensity)`) uses the caller's
/// ORIGINAL density argument, not the auto-computed one `computeDensity()` produces -- a second,
/// separate, previously-undiscovered OCCT defect this PR does not fix (filed separately, see the
/// PR notes). At an EXACT `0.0` that division is `anArea / 0.0`, which is `+Infinity`, and
/// `(int)std::ceil(+Infinity)` saturates to `INT_MAX` on this platform (confirmed directly: see
/// `Scripts/repro/1440-pointcloud-density-int-overflow/`) -- every face then requests ~2.1
/// billion points, which hangs the process. That defect is independent of Finding 3's `myTol`
/// default (it reproduces on an ORDINARY box with no near-zero-area face at all, bug or no bug),
/// so this test uses a small NON-zero density instead (still `< Precision::Confusion()`, so
/// `computeDensity()` still runs and Finding 3's fix still governs the outcome), chosen together
/// with the fixture's face areas so the per-face counts stay in the low thousands either way.
///
/// The fixture is a compound of two faces, sized (and validated against the real
/// `BRepLib_PointCloudShape`/`NbPointsByDensity` via a ground-truth reproducer, not just
/// hand-calculated) so the outcome differs cleanly between the bug and the fix:
/// - a degenerate sliver triangle, area `5e-16` -- comfortably under
///   `Precision::Confusion()^2` (`1e-14`), the shape the filter exists to exclude
/// - an ordinary small square, area `1e-4` -- large enough that once the sliver is correctly
///   excluded, `computeDensity()`'s answer (`1e-4 * 0.1 == 1e-5`) still clears
///   `Precision::Confusion()` (`1e-7`)
@Suite("Issue #1440: point-cloud auto-density tolerance default")
struct Issue1440PointCloudToleranceTests {

    /// Builds the two-face fixture described above. A `BRepBuilderAPI_MakeFace`-style planar
    /// face from an explicit polygon, not a primitive: primitives like `Shape.box` refuse
    /// dimensions this small outright (measured; see the repro notes), while a wire's vertices
    /// can be made arbitrarily close without OCCT rejecting the wire itself.
    private static func fixture() throws -> Shape {
        let sliverWire = try #require(
            Wire.polygon3D([
                SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(5, 1e-16, 0),
            ]))
        let sliverFace = try #require(Shape.face(from: sliverWire))

        let squareWire = try #require(
            Wire.polygon3D([
                SIMD3(100, 0, 0), SIMD3(100.01, 0, 0), SIMD3(100.01, 0.01, 0), SIMD3(100, 0.01, 0),
            ]))
        let squareFace = try #require(Shape.face(from: squareWire))

        return try #require(Shape.compound([sliverFace, squareFace]))
    }

    @Test("auto-density point cloud generation is not poisoned by a near-zero-area face")
    func autoDensityIgnoresNearZeroAreaFace() throws {
        let compound = try Self.fixture()

        // < Precision::Confusion() (1e-7): still routes through computeDensity() (Finding 3's
        // code path), but avoids the separate exact-0.0 overflow described above.
        let result = compound.pointCloudByDensity(2e-8)

        #expect(
            result != nil,
            "auto-density point cloud came back nil -- the near-zero-area sliver poisoned computeDensity()"
        )
        if let result {
            #expect(result.points.count > 0)
            // Sanity bound: the correctly-filtered fixture generates ~5000 points (from the
            // 1e-4-area square alone); anything wildly larger would mean the sliver's area is
            // leaking into the count after all.
            #expect(result.points.count < 20000)
        }
    }

    /// Control: the same fixture with an ORDINARY explicit density (`>= Precision::Confusion()`,
    /// bypassing `computeDensity()`/`myTol` entirely) is unaffected either way -- confirming the
    /// difference above is really about the auto-density code path, not a blanket change to
    /// point-cloud generation.
    @Test("an explicit (non-auto) density on the same fixture is unaffected")
    func explicitDensityUnaffected() throws {
        let compound = try Self.fixture()
        let result = compound.pointCloudByDensity(1e-5)
        #expect(result != nil)
        if let result {
            #expect(result.points.count > 0)
        }
    }
}
