import Testing

@testable import OCCTSwift

/// Regression for #3516 (upstream `Open-Cascade-SAS/OCCT#1716`): `FilletBuilder.surfaceCount` read
/// `BRepFilletAPI_MakeFillet::NbSurfaces()` with no check that a build had completed.
///
/// `NbSurfaces()` is `myBuilder.Builder()->DataStructure()->NbSurfaces()`. That data structure
/// is assigned only when `ChFi3d_Builder::Compute` reaches `TopOpeBRepBuild_HBuilder::Perform`,
/// which it does only while the build is still going well, so the handle is null for a builder
/// that was never built and for one whose build was declined, and the read is an uncatchable
/// SIGSEGV (`OCC_CATCH_SIGNALS` is inert in this build).
///
/// `Scripts/repro/3516/occt_3516_nbsurfaces_matrix.mm` measured it on the pinned kernel, one forked
/// process per state: `NbSurfaces()` faults in every state where `IsDone()` is false except one,
/// and answers 2 where it is true. The exception is a build that completed and was then
/// `Reset()`: `IsDone()` is false, the stale data structure survives, and the count is the old 2.
/// Each test below is one of those states, so each is one fixture the guard has to cover.
@Suite("FilletBuilder surfaceCount before a completed build")
struct FilletBuilderSurfaceCountTests {

    /// A builder on a 10 mm box with the first edge added at `radius`.
    ///
    /// Radius 1 builds; radius 20 is far past half a face width and the builder declines it
    /// (`StartSol echec`).
    private func boxBuilder(radius: Double) throws -> FilletBuilder {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fb = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        try #require(fb.addEdge(edge, radius: radius), "the builder refused the edge outright")
        return fb
    }

    @Test("a declined build reads 0, not a crash")
    func declinedBuild() throws {
        let fb = try boxBuilder(radius: 20)
        // The fixture means what its name says: the builder itself declined it. A build that
        // came back nil because of the sanity check after a completed build would leave
        // `faultyContourCount` at 0 and read the count from a real data structure.
        #expect(fb.build() == nil)
        #expect(fb.faultyContourCount == 1)
        #expect(!fb.hasResult)
        #expect(fb.surfaceCount == 0)
    }

    @Test("a builder that was never built reads 0")
    func neverBuilt() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let empty = try #require(FilletBuilder(shape: box))
        #expect(empty.contourCount == 0)
        #expect(empty.surfaceCount == 0)

        let added = try boxBuilder(radius: 1)
        #expect(added.contourCount == 1)
        #expect(added.surfaceCount == 0)
    }

    @Test("a build with no contour is refused and reads 0")
    func buildWithNoContour() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fb = try #require(FilletBuilder(shape: box))
        #expect(fb.build() == nil)
        #expect(fb.contourCount == 0)
        #expect(fb.surfaceCount == 0)
    }

    // The control that stops a guard wired to a constant 0: the same property still answers the
    // kernel's own number after a build that completed, and only a reset takes it back to 0.
    @Test("a completed build keeps its count, and a reset clears it")
    func completedBuildAndReset() throws {
        let fb = try boxBuilder(radius: 1)
        #expect(fb.build() != nil)
        #expect(fb.surfaceCount == 2)

        // `reset()` is `NotDone()` plus a stripe reset, and the kernel keeps the old data
        // structure, so an unguarded read answers the stale 2 here instead of faulting.
        fb.reset()
        #expect(fb.surfaceCount == 0)
    }

    // The upstream report's model: a cylinder r 95 along X, x in [-70, 70], fused with three
    // cylinders r 80 along Z, z in [0, 135], patterned 120 degrees about X and cut to the same
    // slab. The concave arm-to-disc edges are the ones that are neither a line nor a circle: the
    // slab planes hold only circles and lines. R 17 is declined and R 15 builds.
    private func armsAndDisc() throws -> (shape: Shape, blendEdges: [Edge]) {
        let disc = try #require(
            Shape.cylinder(at: SIMD3(-70, 0, 0), direction: SIMD3(1, 0, 0), radius: 95, height: 140)
        )
        var solid = disc
        for k in 0..<3 {
            let arm = try #require(
                Shape.cylinder(
                    at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 80, height: 135))
            let turned = try #require(
                arm.rotated(axis: SIMD3(1, 0, 0), angle: Double(k) * 2 * .pi / 3))
            solid = try #require(solid.union(turned))
        }
        let slab = try #require(Shape.box(width: 140, height: 600, depth: 600))
        let cut = try #require(solid.intersection(slab))
        let blendEdges = cut.edges().filter { !$0.isLine && !$0.isCircle }
        return (cut, blendEdges)
    }

    @Test("the reported three-cylinder model, declined at R 17, reads 0")
    func threeCylinderModelDeclined() throws {
        let (shape, edges) = try armsAndDisc()
        #expect(!edges.isEmpty, "no arm-to-disc edge selected")
        let fb = try #require(FilletBuilder(shape: shape))
        for edge in edges {
            #expect(fb.addEdge(edge, radius: 17))
        }
        #expect(fb.build() == nil)
        #expect(fb.faultyContourCount > 0)
        #expect(fb.surfaceCount == 0)
    }

    @Test("the reported three-cylinder model, built at R 15, still counts its surfaces")
    func threeCylinderModelBuilds() throws {
        let (shape, edges) = try armsAndDisc()
        let fb = try #require(FilletBuilder(shape: shape))
        for edge in edges {
            #expect(fb.addEdge(edge, radius: 15))
        }
        #expect(fb.build() != nil)
        #expect(fb.faultyContourCount == 0)
        #expect(fb.surfaceCount > 0)
    }
}
