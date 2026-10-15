import Foundation
import Testing

@testable import OCCTSwift

/// A circular spine with an on-axis profile returns nil instead of crashing the process.
///
/// #3449: `BRepFill_TrimSurfaceTool::IntersectWith` compares the length of the two intersection
/// sequences with a `_Raise_if` macro, which a Release (`No_Exception`) kernel empties, and
/// then indexes the second sequence by the first's length. On a circular spine with a profile that
/// leaves the circle's axis the two lengths differ, so the kernel read past a sequence and the
/// process died with an uncatchable SIGSEGV inside the `BRepOffsetAPI_MakeEvolved` constructor.
/// Carried patch `0068` makes the check a literal throw, which the bridge's `catch (...)` turns
/// into `nil`.
@Suite("Evolved shapes on a circular spine refuse an incoherent trim")
struct EvolvedCircularSpineTests {

    private static let isLocalKernel =
        ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

    private func disk() throws -> Shape {
        let circle = try #require(Wire.circle(radius: 20))
        return try #require(Shape.face(from: circle))
    }

    /// Gated on `OCCTSWIFT_LOCAL=1` until carried patch `0068` is pinned.
    ///
    /// The fix is not in the pinned asset, and an unguarded run against it is a SIGSEGV that takes
    /// the whole `build-and-test` process down. Ungate it at the repin that pins `0068`, or the
    /// test stays skipped on every default run (#2983).
    @Test(
        "A profile leaving the circle's axis returns nil instead of crashing",
        .enabled(if: EvolvedCircularSpineTests.isLocalKernel))
    func profileFromTheAxis() throws {
        let profile = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(0, 2, 3)], closed: false))
        // Before the fix this call killed the test process.
        let result = Shape.evolvedAdvanced(
            spine: try disk(), profile: profile, axeProf: false, solid: false, volume: false)
        // Measured: nil after the fix (the kernel reports NotDone). A shape is also acceptable,
        // but never an invalid one.
        if let result {
            #expect(result.isValid)
        }
    }

    @Test("An off-axis profile on the same spine still builds")
    func offAxisControl() throws {
        let profile = try #require(
            Wire.polygon3D([SIMD3(5, 0, 0), SIMD3(5, 2, 3)], closed: false))
        let result = try #require(
            Shape.evolvedAdvanced(
                spine: try disk(), profile: profile, axeProf: false, solid: false, volume: false))
        #expect(result.isValid)
    }
}
