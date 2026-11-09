import Testing

@testable import OCCTSwift

/// Regression for #3519: `FilletBuilder.simulatedSurfaceCount(contour:)` read
/// `BRepFilletAPI_MakeFillet::NbSurf(IC)` with no check that the contour held any surface data.
///
/// `NbSurf(IC)` is `stripe->SetOfSurfData()->Length()`. A stripe's `SetOfSurfData()` is a handle
/// that is null until `Build` or `Simulate` reaches the stripe, and `ChFiDS_Stripe::Reset` makes it
/// null again, so the read is an uncatchable SIGSEGV (`OCC_CATCH_SIGNALS` is inert in this build)
/// on a builder that was never built or simulated, on one that was `reset()` since, and on a
/// contour that a `simulate(contour:)` of another contour never reached.
///
/// `Scripts/repro/3519/occt_3519_simulated_surf_matrix.mm` measured it on the pinned kernel, one
/// forked process per state. Each fault below is one of those states, and each is its own test
/// because a fault ends the process: run alone, a test that faults is the one that names the state.
/// The bridge now asks `NbComputedSurfaces(IC)`, which reads the same length behind a null test,
/// and answers 0 where that is 0.
@Suite("FilletBuilder simulatedSurfaceCount without surface data")
struct FilletBuilderSimulatedSurfaceTests {

    private func boxAndEdges() throws -> (box: Shape, first: Edge, apart: Edge) {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        let first = try #require(edges.first)
        // An edge sharing no vertex with the first, so adding both makes two separate contours.
        func differ(_ p: SIMD3<Double>, _ q: SIMD3<Double>) -> Bool {
            max(abs(p.x - q.x), abs(p.y - q.y), abs(p.z - q.z)) > 1e-6
        }
        let apart = try #require(
            edges.first { candidate in
                let a = first.endpoints
                let b = candidate.endpoints
                return [b.start, b.end].allSatisfy { p in differ(p, a.start) && differ(p, a.end) }
            })
        return (box, first, apart)
    }

    /// A builder on `box` with each of `edges` added at `radius`.
    ///
    /// Radius 1 builds and simulates; radius 20 is far past half a face width and is declined
    /// (`StartSol echec`).
    private func builder(on box: Shape, adding edges: [Edge], radius: Double = 1) throws
        -> FilletBuilder
    {
        let fb = try #require(FilletBuilder(shape: box))
        for edge in edges {
            try #require(fb.addEdge(edge, radius: radius), "the builder refused the edge outright")
        }
        return fb
    }

    @Test("a builder holding a contour that was never built or simulated reads 0")
    func neverSimulated() throws {
        let (box, first, _) = try boxAndEdges()

        // No contour at all: OCCT finds no stripe and already answered 0.
        let empty = try #require(FilletBuilder(shape: box))
        #expect(empty.contourCount == 0)
        #expect(empty.simulatedSurfaceCount(contour: 1) == 0)

        // A contour with no surface data yet: the stripe exists, its sequence is null.
        let added = try builder(on: box, adding: [first])
        #expect(added.contourCount == 1)
        #expect(added.simulatedSurfaceCount(contour: 1) == 0)
    }

    @Test("a simulated builder reads 0 once it has been reset, and counts again when re-simulated")
    func simulatedThenReset() throws {
        let (box, first, _) = try boxAndEdges()
        let fb = try builder(on: box, adding: [first])

        fb.simulate(contour: 1)
        #expect(fb.simulatedSurfaceCount(contour: 1) == 1)

        // `reset()` nulls every stripe's surface data and keeps the stripe.
        fb.reset()
        #expect(fb.contourCount == 1)
        #expect(fb.simulatedSurfaceCount(contour: 1) == 0)

        // The control that stops a guard stuck at 0: the reset left the contour simulable.
        fb.simulate(contour: 1)
        #expect(fb.simulatedSurfaceCount(contour: 1) == 1)
    }

    @Test("a built builder reads 0 once it has been reset")
    func builtThenReset() throws {
        let (box, first, _) = try boxAndEdges()
        let fb = try builder(on: box, adding: [first])
        #expect(fb.build() != nil)

        fb.reset()
        #expect(fb.contourCount == 1)
        #expect(fb.simulatedSurfaceCount(contour: 1) == 0)
    }

    @Test("a contour that simulate never reached reads 0 while its sibling counts")
    func contourNotReachedBySimulate() throws {
        let (box, first, apart) = try boxAndEdges()
        let fb = try builder(on: box, adding: [first, apart])
        #expect(fb.contourCount == 2)

        // `simulate(contour:)` fills one stripe; the other keeps a null sequence.
        fb.simulate(contour: 1)
        #expect(fb.simulatedSurfaceCount(contour: 1) == 1)
        #expect(fb.simulatedSurfaceCount(contour: 2) == 0)

        fb.simulate(contour: 2)
        #expect(fb.simulatedSurfaceCount(contour: 2) == 1)
    }

    // These answered 0 before the fix: a build or a simulation gives the stripe an empty sequence
    // before it declines, and a builder with no contour has no stripe to read. They pin that the
    // guard keeps answering it.
    @Test("a declined build and a declined simulation read 0")
    func declined() throws {
        let (box, first, _) = try boxAndEdges()

        let declinedBuild = try builder(on: box, adding: [first], radius: 20)
        #expect(declinedBuild.build() == nil)
        #expect(declinedBuild.faultyContourCount == 1)
        #expect(declinedBuild.simulatedSurfaceCount(contour: 1) == 0)

        // `simulate(contour:)` throws inside the bridge and is caught there.
        let declinedSimulation = try builder(on: box, adding: [first], radius: 20)
        declinedSimulation.simulate(contour: 1)
        #expect(declinedSimulation.simulatedSurfaceCount(contour: 1) == 0)

        // A build with nothing to build is refused before any stripe exists.
        let noContour = try #require(FilletBuilder(shape: box))
        #expect(noContour.build() == nil)
        #expect(noContour.simulatedSurfaceCount(contour: 1) == 0)
    }

    // The control. A guard that answers 0 for every builder whose `build()` has not completed (the
    // `IsDone()` test #3516 put on `surfaceCount`) reads 0 here, since a simulation never sets
    // `IsDone()`; so does one wired to a constant 0. A real simulation of a box edge is one fillet
    // face.
    @Test("a real simulation still answers its real count")
    func realSimulationCounts() throws {
        let (box, first, _) = try boxAndEdges()
        let fb = try builder(on: box, adding: [first])

        fb.simulate(contour: 1)
        #expect(!fb.hasResult, "a simulation is not a build")
        #expect(fb.simulatedSurfaceCount(contour: 1) == 1)
    }
}
