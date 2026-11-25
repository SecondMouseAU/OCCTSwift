import Testing

@testable import OCCTSwift

/// Regression for #3522: `ChamferBuilder.simulatedSurfaceCount(contour:)` faulted the process on a
/// contour that held no surface data.
///
/// `ChFi3d_ChBuilder::NbSurf(IC)` is `stripe->SetOfSurfData()->Length()` with no null test
/// (`ChFi3d_ChBuilder.cxx:626-638`). A stripe's sequence is null until `Build` or `Simulate` reaches
/// the stripe and null again after `Reset()`, so the read was an uncatchable SIGSEGV on a contour
/// never run, after `reset()`, and on a contour a simulation of another contour never reached.
/// `Scripts/repro/3522/occt_3522_chamfer_surfdata_matrix.mm` measured every one of these states, one
/// forked process per (state, contour), against the predicate the bridge now reads, and the count it
/// answers where `NbSurf` answers.
///
/// The fillet side was guarded by `NbComputedSurfaces(IC)` (#3519). `BRepFilletAPI_MakeChamfer` has
/// no such member, and the state cannot be tracked from outside: whether a stripe holds a sequence
/// depends on `build`, `simulate`, `reset`, `addEdge` and `removeEdge` together. Two of the states
/// below are why a flag kept beside the builder is not enough, a contour added after a build and a
/// contour renumbered by a removal.
///
/// Without the guard the first read below ends the test process, which is why this is a suite of its
/// own: `swift test --filter ChamferBuilderSimulatedSurfaceTests` runs it alone.
@Suite("ChamferBuilder simulated surface count on a contour with no surface data")
struct ChamferBuilderSimulatedSurfaceTests {

    // MARK: - States

    /// A 10 mm box and the first two edges `addEdge` puts in contours of their own.
    private func boxAndEdges() throws -> (box: Shape, first: Edge, second: Edge) {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        let probe = try #require(ChamferBuilder(shape: box))
        let first = try #require(edges.first)
        try #require(probe.addEdge(first, distance: 1))
        let second = try #require(
            edges.dropFirst().first {
                probe.addEdge($0, distance: 1) && probe.contourCount == 2
            }, "no second edge opened a second contour")
        return (box, first, second)
    }

    private func fresh(_ box: Shape) throws -> ChamferBuilder {
        try #require(ChamferBuilder(shape: box))
    }

    /// Indices that name no contour of any state below.
    ///
    /// A corner stripe, which is past `contourCount` and has no spine, is the one place OCCT
    /// answers for such an index, and it has its own test.
    private let outOfRange = [0, -1, 99, 100_000, Int.max, Int.min]

    // MARK: - Reads that used to fault

    @Test("a contour that was never built or simulated has no surfaces")
    func neverRun() throws {
        let (box, first, second) = try boxAndEdges()
        let one = try fresh(box)
        try #require(one.addEdge(first, distance: 1))
        #expect(one.simulatedSurfaceCount(contour: 1) == 0)

        let two = try fresh(box)
        try #require(two.addEdge(first, distance: 1))
        try #require(two.addEdge(second, distance: 1))
        #expect(two.simulatedSurfaceCount(contour: 1) == 0)
        #expect(two.simulatedSurfaceCount(contour: 2) == 0)
    }

    @Test("after reset the surfaces a simulation or a build made are gone")
    func afterReset() throws {
        let (box, first, _) = try boxAndEdges()

        let simulated = try fresh(box)
        try #require(simulated.addEdge(first, distance: 1))
        try #require(simulated.simulate(contour: 1))
        try #require(simulated.simulatedSurfaceCount(contour: 1) == 1)
        simulated.reset()
        #expect(simulated.simulatedSurfaceCount(contour: 1) == 0)

        let built = try fresh(box)
        try #require(built.addEdge(first, distance: 1))
        try #require(built.build() != nil)
        try #require(built.simulatedSurfaceCount(contour: 1) == 1)
        built.reset()
        #expect(built.simulatedSurfaceCount(contour: 1) == 0)

        // A reset is not a one-way door: the contour answers again once it is simulated again.
        simulated.simulate(contour: 1)
        #expect(simulated.simulatedSurfaceCount(contour: 1) == 1)
    }

    @Test("a contour that a simulation of another contour never reached has no surfaces")
    func otherContourSimulated() throws {
        let (box, first, second) = try boxAndEdges()
        let cb = try fresh(box)
        try #require(cb.addEdge(first, distance: 1))
        try #require(cb.addEdge(second, distance: 1))
        try #require(cb.simulate(contour: 1))
        #expect(cb.simulatedSurfaceCount(contour: 1) == 1)
        #expect(cb.simulatedSurfaceCount(contour: 2) == 0)
    }

    @Test("a contour added after a build has no surfaces, and the built one keeps its count")
    func addedAfterBuild() throws {
        // The state a flag kept beside the builder gets wrong: the build made surface data for
        // contour 1, and the contour added afterwards has none.
        let (box, first, second) = try boxAndEdges()
        let cb = try fresh(box)
        try #require(cb.addEdge(first, distance: 1))
        try #require(cb.build() != nil)
        try #require(cb.addEdge(second, distance: 1))
        try #require(cb.contourCount == 2)
        #expect(cb.simulatedSurfaceCount(contour: 1) == 1)
        #expect(cb.simulatedSurfaceCount(contour: 2) == 0)
    }

    @Test("contours renumbered by a removal keep the count of the stripe they now name")
    func renumberedByRemoval() throws {
        let (box, first, second) = try boxAndEdges()
        let cb = try fresh(box)
        try #require(cb.addEdge(first, distance: 1))
        try #require(cb.addEdge(second, distance: 1))
        try #require(cb.build() != nil)
        try #require(cb.removeEdge(first))
        // Contour 2 is contour 1 now, and it still holds what the build made for it.
        try #require(cb.contourCount == 1)
        #expect(cb.simulatedSurfaceCount(contour: 1) == 1)
        #expect(cb.simulatedSurfaceCount(contour: 2) == 0)
    }

    @Test("a builder with no contour has no surfaces, built or not")
    func noContour() throws {
        let (box, _, _) = try boxAndEdges()
        let cb = try fresh(box)
        #expect(cb.simulatedSurfaceCount(contour: 1) == 0)
        #expect(cb.build() == nil, "a build with nothing added must be refused")
        #expect(cb.simulatedSurfaceCount(contour: 1) == 0)
    }

    @Test("a contour whose build or simulation was declined has no surfaces")
    func declined() throws {
        let (box, first, _) = try boxAndEdges()

        let build = try fresh(box)
        try #require(build.addEdge(first, distance: 20))
        try #require(build.build() == nil, "a distance of twice the box must be declined")
        #expect(build.simulatedSurfaceCount(contour: 1) == 0)

        let simulation = try fresh(box)
        try #require(simulation.addEdge(first, distance: 20))
        #expect(!simulation.simulate(contour: 1), "the simulation must be declined too")
        #expect(simulation.simulatedSurfaceCount(contour: 1) == 0)
    }

    @Test("an index that names no contour answers 0 in every state, and 0 outside Int32 too")
    func outsideTheRange() throws {
        let (box, first, second) = try boxAndEdges()
        let never = try fresh(box)
        try #require(never.addEdge(first, distance: 1))

        let simulated = try fresh(box)
        try #require(simulated.addEdge(first, distance: 1))
        try #require(simulated.addEdge(second, distance: 1))
        try #require(simulated.simulate(contour: 1))

        let built = try fresh(box)
        try #require(built.addEdge(first, distance: 1))
        try #require(built.build() != nil)

        for cb in [never, simulated, built, try fresh(box)] {
            for i in outOfRange {
                #expect(cb.simulatedSurfaceCount(contour: i) == 0, "contour \(i)")
            }
        }
    }

    @Test("a corner stripe past the last contour is not a contour")
    func cornerStripe() throws {
        // Three chamfers meeting at one vertex leave a stripe with no spine after the three
        // contours. NbSurf(4) reads it as a contour; it is not one.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let corner = SIMD3<Double>(-5, -5, -5)
        let atCorner = box.edges().filter {
            let ends = $0.endpoints
            return vectorDistance(ends.start, corner) < 1e-6
                || vectorDistance(ends.end, corner) < 1e-6
        }
        try #require(atCorner.count == 3, "a box corner has three edges")
        let cb = try fresh(box)
        for edge in atCorner { try #require(cb.addEdge(edge, distance: 1)) }
        try #require(cb.contourCount == 3)
        try #require(cb.build() != nil)
        for c in 1...3 {
            #expect(cb.simulatedSurfaceCount(contour: c) == 1, "contour \(c)")
        }
        #expect(cb.simulatedSurfaceCount(contour: 4) == 0)
    }

    // MARK: - The matching fillet cases

    /// `FilletBuilder.simulatedSurfaceCount(contour:)`, guarded by #3519.
    ///
    /// It reads `NbComputedSurfaces`, which has the null test OCCT ships. The two states that made a flag
    /// beside the builder unreliable for the chamfer are checked on it too, so the pair stays a
    /// pair: a contour added after a build, and a corner stripe past the last contour.
    @Test("the fillet answers 0 for a contour added after a build and for a corner stripe")
    func filletCounterpart() throws {
        let (box, first, second) = try boxAndEdges()
        let added = try #require(FilletBuilder(shape: box))
        try #require(added.addEdge(first, radius: 1))
        try #require(added.build() != nil)
        try #require(added.addEdge(second, radius: 1))
        try #require(added.contourCount == 2)
        #expect(added.simulatedSurfaceCount(contour: 1) == 1)
        #expect(added.simulatedSurfaceCount(contour: 2) == 0)

        let corner = SIMD3<Double>(-5, -5, -5)
        let atCorner = box.edges().filter {
            let ends = $0.endpoints
            return vectorDistance(ends.start, corner) < 1e-6
                || vectorDistance(ends.end, corner) < 1e-6
        }
        try #require(atCorner.count == 3, "a box corner has three edges")
        let cornered = try #require(FilletBuilder(shape: box))
        for edge in atCorner { try #require(cornered.addEdge(edge, radius: 1)) }
        try #require(cornered.contourCount == 3)
        try #require(cornered.build() != nil)
        #expect(cornered.simulatedSurfaceCount(contour: 4) == 0)
        for i in outOfRange {
            #expect(cornered.simulatedSurfaceCount(contour: i) == 0, "contour \(i)")
        }
    }

    // MARK: - Controls: a contour that holds surfaces still answers what it did

    /// Stops a guard wired to answer 0 for everything.
    @Test("a simulated or built contour answers its count")
    func holdingContourStillAnswers() throws {
        let (box, first, second) = try boxAndEdges()

        let simulated = try fresh(box)
        try #require(simulated.addEdge(first, distance: 1))
        try #require(simulated.simulate(contour: 1))
        #expect(simulated.simulatedSurfaceCount(contour: 1) == 1)

        let built = try fresh(box)
        try #require(built.addEdge(first, distance: 1))
        try #require(built.build() != nil)
        #expect(built.simulatedSurfaceCount(contour: 1) == 1)

        let simulatedThenBuilt = try fresh(box)
        try #require(simulatedThenBuilt.addEdge(first, distance: 1))
        try #require(simulatedThenBuilt.simulate(contour: 1))
        try #require(simulatedThenBuilt.build() != nil)
        #expect(simulatedThenBuilt.simulatedSurfaceCount(contour: 1) == 1)

        let builtThenSimulated = try fresh(box)
        try #require(builtThenSimulated.addEdge(first, distance: 1))
        try #require(builtThenSimulated.build() != nil)
        builtThenSimulated.simulate(contour: 1)
        #expect(builtThenSimulated.simulatedSurfaceCount(contour: 1) == 1)

        let twoBuilt = try fresh(box)
        try #require(twoBuilt.addEdge(first, distance: 1))
        try #require(twoBuilt.addEdge(second, distance: 1))
        try #require(twoBuilt.build() != nil)
        #expect(twoBuilt.simulatedSurfaceCount(contour: 1) == 1)
        #expect(twoBuilt.simulatedSurfaceCount(contour: 2) == 1)
    }
}
