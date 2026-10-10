import Foundation
import Testing

@testable import OCCTSwift

/// #3207: two fillets whose radii sum to the width of the face between them are built, not refused.
///
/// On a 4 x 10 x 6 box, fillets on the two top edges that run along Y give `IsDone() == false` at
/// r = 2 (half the 4 wide face) and valid solids at 1.99999999, on `v4.0.0-kernel.4` and `.5` alike
/// (OCCT#1177, and OCCT's own `tests/bugs/modalg_7/bug25478_1`, whose TODO expects the failure).
/// `ChFi3d_Builder::PerformOneCorner` and `ChFi3d_StripeEdgeInter` throw "fillets have too big
/// radiuses" because the end caps touch at a point and the contact curves on the top face coincide.
/// Carried kernel patch `0059` lets an exact meeting through and removes the face of no width
/// between the two fillets, so the top is the semicircle of two quarter cylinders.
///
/// A radius above half the width is still refused: the fillet surfaces cross, which the stripe
/// builder cannot trim (see `Scripts/repro/fillet-exact-meeting-fix/README.md`).
///
/// The oracle is the section area. Looking along Y the removed area at r <= w/2 is
/// 2 (1 - pi/4) r^2 and the volume is `w * h * L - L * area`.
@Suite("Issue 3207: fillets that meet exactly")
struct Issue3207FilletMeetingTests {

    /// The two edges of the box that run along Y on its top face, found by where they are.
    private func topEdgesAlongY(_ box: Shape, width: Double, height: Double, length: Double)
        -> [Edge]
    {
        box.edges().filter { edge in
            let (a, b) = edge.endpoints
            let onTop = abs(a.z - height) < 1e-9 && abs(b.z - height) < 1e-9
            let alongY = abs(a.x - b.x) < 1e-9 && abs(abs(a.y - b.y) - length) < 1e-9
            return onTop && alongY
        }
    }

    private func volumeOfRoundedTop(width: Double, height: Double, length: Double, radius: Double)
        -> Double
    {
        width * height * length - length * 2 * (1 - Double.pi / 4) * radius * radius
    }

    /// The control: a radius just under half the width fillets, on every kernel.
    ///
    /// This runs on the pinned asset, so the gated test below cannot be vacuous because the box or
    /// the edge selection was wrong: the same two edges, one ulp-scale step apart.
    @Test func justUnderHalfTheWidthFilletsToTheOracleVolume() throws {
        let box = try #require(Shape.box(origin: .zero, width: 4, height: 10, depth: 6))
        let edges = topEdgesAlongY(box, width: 4, height: 6, length: 10)
        #expect(edges.count == 2)
        let r = 1.9999
        let result = try #require(box.filleted(edges: edges, radius: r))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        let oracle = volumeOfRoundedTop(width: 4, height: 6, length: 10, radius: r)
        #expect(abs(volume - oracle) < 1e-6)
    }

    /// A radius above half the width is declined, not returned as an invalid shape.
    ///
    /// The arcs would cross, and the stripe builder has no way to trim two fillet surfaces at the
    /// curve where they cross. 2.2 gave a clean `nil` before the patch and must keep giving one:
    /// with the two checks lifted unconditionally it returned a "done" solid of volume 330 for a
    /// 240 box. Runs on every kernel.
    @Test func aRadiusAboveHalfTheWidthStillDeclines() throws {
        let box = try #require(Shape.box(origin: .zero, width: 4, height: 10, depth: 6))
        let edges = topEdgesAlongY(box, width: 4, height: 6, length: 10)
        #expect(edges.count == 2)
        for r in [2.0000001, 2.0001, 2.2, 3.0] {
            if let result = box.filleted(edges: edges, radius: r) {
                // Declining is the contract; if a later kernel builds these, they must be right.
                #expect(result.isValid, "r = \(r) returned an invalid shape")
            }
        }
    }

    /// Radius exactly half the width: the top is a semicircle and the solid is valid.
    ///
    /// Gated on `OCCTSWIFT_LOCAL=1`, the way `Issue3003OffsetOrderTests` was: the fix is carried
    /// patch `0059`, which the pinned asset does not carry, and `ci.yml`'s `build-and-test`
    /// resolves that asset. `kernel-integration.yml` builds the patches from source with
    /// `OCCTSWIFT_LOCAL=1`, which is where this runs. A skipped test and a passing one both report
    /// green, so the per-test line in the log is the only signal: read `started`, not `skipped`.
    ///
    /// Seven faces, not eight: the top face, which would have no width, is removed and the two
    /// quarter cylinders share the edge where it was.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func radiusOfHalfTheWidthGivesASemicircle() throws {
        let box = try #require(Shape.box(origin: .zero, width: 4, height: 10, depth: 6))
        let edges = topEdgesAlongY(box, width: 4, height: 6, length: 10)
        #expect(edges.count == 2)

        // 222.8318530718
        let oracle = volumeOfRoundedTop(width: 4, height: 6, length: 10, radius: 2)
        var faceCounts = Set<Int>()
        var volumes = [Double]()
        // Three runs: the result must be deterministic.
        for _ in 0..<3 {
            let result = try #require(box.filleted(edges: edges, radius: 2))
            #expect(result.isValid, "BRepCheck must accept the exactly-meeting result")
            #expect(result.solidCount == 1)
            #expect(result.shellCount == 1)
            faceCounts.insert(result.faces().count)
            volumes.append(try #require(result.volume))
            let mesh = try #require(
                result.mesh(linearDeflection: 0.01), "the result must tessellate")
            #expect(mesh.triangleCount > 0)
        }
        #expect(faceCounts == [7])
        for volume in volumes { #expect(abs(volume - oracle) < 1e-6) }
        #expect(Set(volumes).count == 1)
    }

    /// OCCT#1177's second sample: a 10 cube with a fillet of 5 on each of two opposite edges.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"))
    func tenCubeWithTwoFilletsOfFiveMeets() throws {
        let cube = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 10))
        let edges = topEdgesAlongY(cube, width: 10, height: 10, length: 10)
        #expect(edges.count == 2)
        let result = try #require(cube.filleted(edges: edges, radius: 5))
        #expect(result.isValid)
        let oracle = volumeOfRoundedTop(width: 10, height: 10, length: 10, radius: 5)
        let volume = try #require(result.volume)
        #expect(abs(volume - oracle) < 1e-6)
        #expect(result.faces().count == 7)
    }
}
