import Foundation
import Testing

@testable import OCCTSwift

/// #2881: a fillet blend that reaches a vertex whose neighbour face holds no edge to follow.
///
/// `ChFi3d_Builder::StartSol` marks the vertex as an obstacle and replaces its curve with an empty
/// `BRepAdaptor_Curve2d`, looks for the arc edge among the neighbour face's edges, and on finding
/// none returned `false` while leaving that empty adaptor in place with the obstacle flag still set.
/// The caller took the obstacle path with it, and `Geom2dAdaptor_Curve::D1` dereferenced a null curve:
/// an uncatchable SIGSEGV inside `BRepFilletAPI_MakeFillet::Build`. Carried kernel patch `0054`
/// clears both, so the blend reports "not done" instead.
///
/// The model is the one attached to OCCT#1568, 19 faces and 42 edges. The failing input is a single
/// radius, 1.5, on eight of those edges; one ULP either side never reached the branch.
/// `Scripts/repro/occt1568-fillet-opposite-edge/` holds the measurement.
@Suite("Issue 2881: a fillet obstacle with no edge to follow")
struct Issue2881FilletObstacleTests {

    private func loadModel() throws -> Shape {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/occt1568-fillet-obstacle-model.brep")
        return try Shape.loadBREP(from: url)
    }

    /// How many of the model's edges fillet to a shape at `radius`, one edge at a time.
    private func edgesThatFillet(_ shape: Shape, radius: Double) -> (done: Int, total: Int) {
        let edges = shape.edges()
        let done = edges.filter { shape.filleted(edges: [$0], radius: radius) != nil }.count
        return (done, edges.count)
    }

    /// The control: at a radius that never reaches the branch, 20 of the 42 edges fillet.
    ///
    /// The other 22 raise "There are no suitable edges for chamfer or fillet", which the bridge
    /// reports as nil. This runs on every kernel, so the gated test below cannot be vacuous because
    /// the fixture failed to load or fillets stopped working at all.
    @Test func controlRadiusFilletsTwentyOfFortyTwoEdges() throws {
        let model = try loadModel()
        let (done, total) = edgesThatFillet(model, radius: 1.0)
        #expect(total == 42)
        #expect(done == 20)
    }

    /// The exact-tangent radius returns for every edge instead of killing the process.
    ///
    /// Gated on `OCCTSWIFT_LOCAL=1`, the way `Issue3003OffsetOrderTests` is: the fix is carried patch
    /// `0054`, which the pinned asset does not carry, and `ci.yml`'s `build-and-test` resolves that
    /// asset. `kernel-integration.yml` builds the patches from source with `OCCTSWIFT_LOCAL=1`, which
    /// is where this runs. A skipped test and a passing one both report green, so the per-test line
    /// in the log is the only signal: read `started`, not `skipped`.
    ///
    /// Without the patch the process dies at the first of eight edges, so reaching the assertions is
    /// the regression check. The count then pins what the patched kernel does with them: 12 of the 42
    /// edges still fillet at 1.5, 8 decline, and 22 raise the same "no suitable edges" error as at 1.0.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func exactTangentRadiusDeclinesInsteadOfCrashing() throws {
        let model = try loadModel()
        let (done, total) = edgesThatFillet(model, radius: 1.5)
        #expect(total == 42)
        #expect(done == 12)
    }
}
