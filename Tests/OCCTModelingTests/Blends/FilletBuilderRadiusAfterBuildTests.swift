import Testing

@testable import OCCTSwift

/// Regression for #3524: `FilletBuilder.setRadius(_:contour:vertex:)`, `setTwoRadii` and
/// `addEdge(_:radius:)` for an edge that is already in a contour faulted the process, with a valid
/// contour and edge index, once the contour held a `build()` or a `simulate(contour:)` result.
///
/// `ChFiDS_FilSpine::SetRadius(UandR, IinC)` inserts the radius and then, when the spine is already
/// split, replays the radius law on the spine's elementary spines: it reads the first one through
/// an iterator with no emptiness test. For an analytic blend (a box edge, a cylinder's rim) there
/// are none, so the read is a null dereference. The four public setters that end in that function
/// are the three above and `addEdge(_:radius1:radius2:)`; `setRadius(_:contour:edge:)` clears the
/// split first and never reaches it. `Scripts/repro/3524/occt_3524_setradius_after_build.mm`
/// measured every one of them in ten builder states on three fixtures.
///
/// `IsDone()` is not the predicate, and two of the states below are why: a `simulate(contour:)`
/// leaves it false and faults the same way, and so does contour 1 of a build that completed it and
/// declined contour 2. The refusal reads the contour's own computed surfaces as well.
///
/// Without the refusal the first setter below ends the test process, which is why this is a suite
/// of its own: `swift test --filter FilletBuilderRadiusAfterBuildTests` runs it alone.
@Suite("FilletBuilder radius changes on a contour that holds a result")
struct FilletBuilderRadiusAfterBuildTests {

    // MARK: - States

    /// A 10 mm box and the first two of its edges that `addEdge` puts in contours of their own.
    private func boxAndEdges() throws -> (box: Shape, first: Edge, second: Edge) {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        let probe = try #require(FilletBuilder(shape: box))
        let first = try #require(edges.first)
        try #require(probe.addEdge(first, radius: 1))
        let second = try #require(
            edges.dropFirst().first {
                probe.addEdge($0, radius: 1) && probe.contourCount == 2
            }, "no second edge opened a second contour")
        return (box, first, second)
    }

    /// A builder state, and the contours of it that hold a result.
    private struct State {
        let name: String
        let builder: FilletBuilder
        /// The contours that hold a build or a simulation, each with the edge it was made from.
        let holding: [(contour: Int, edge: Edge)]
    }

    /// The states in which a contour holds a result, each asserted to be the state it names.
    private func holdingStates() throws -> [State] {
        let (box, first, second) = try boxAndEdges()
        func fresh() throws -> FilletBuilder { try #require(FilletBuilder(shape: box)) }

        let built = try fresh()
        #expect(built.addEdge(first, radius: 1))
        #expect(built.build() != nil)
        #expect(built.computedSurfaceCount(contour: 1) == 1)

        let simulated = try fresh()
        #expect(simulated.addEdge(first, radius: 1))
        simulated.simulate(contour: 1)
        #expect(simulated.computedSurfaceCount(contour: 1) == 1)

        let builtTwo = try fresh()
        #expect(builtTwo.addEdge(first, radius: 1))
        #expect(builtTwo.addEdge(second, radius: 1))
        #expect(builtTwo.build() != nil)
        #expect(builtTwo.computedSurfaceCount(contour: 1) == 1)
        #expect(builtTwo.computedSurfaceCount(contour: 2) == 1)

        // Contour 1 completes and contour 2 is declined: `IsDone()` is false, and contour 1 still
        // holds its split spine.
        let partlyDeclined = try fresh()
        #expect(partlyDeclined.addEdge(first, radius: 1))
        #expect(partlyDeclined.addEdge(second, radius: 20))
        #expect(partlyDeclined.build() == nil)
        #expect(partlyDeclined.faultyContourCount == 1, "the builder itself must have declined it")
        #expect(partlyDeclined.computedSurfaceCount(contour: 1) == 1)

        // Only contour 1 is simulated.
        let simulatedFirst = try fresh()
        #expect(simulatedFirst.addEdge(first, radius: 1))
        #expect(simulatedFirst.addEdge(second, radius: 1))
        simulatedFirst.simulate(contour: 1)
        #expect(simulatedFirst.computedSurfaceCount(contour: 1) == 1)
        #expect(simulatedFirst.computedSurfaceCount(contour: 2) == 0)

        return [
            State(name: "built", builder: built, holding: [(1, first)]),
            State(name: "simulated", builder: simulated, holding: [(1, first)]),
            State(
                name: "two contours, built", builder: builtTwo, holding: [(1, first), (2, second)]),
            State(
                name: "contour 1 built, contour 2 declined", builder: partlyDeclined,
                holding: [(1, first)]),
            State(
                name: "contour 1 simulated, contour 2 not", builder: simulatedFirst,
                holding: [(1, first)]),
        ]
    }

    // MARK: - The refusals

    @Test("setRadius at a vertex is refused on a contour that holds a result, and changes nothing")
    func setRadiusAtVertex() throws {
        for state in try holdingStates() {
            let fb = state.builder
            for (contour, _) in state.holding {
                let vertex = try #require(fb.firstVertex(contour: contour), "\(state.name)")
                let before = fb.radius(contour: contour)
                #expect(
                    !fb.setRadius(7, contour: contour, vertex: vertex),
                    "\(state.name), contour \(contour)")
                #expect(fb.radius(contour: contour) == before, "\(state.name): radius changed")
            }
        }
    }

    @Test("setTwoRadii is refused on a contour that holds a result, and changes nothing")
    func setTwoRadii() throws {
        for state in try holdingStates() {
            let fb = state.builder
            for (contour, _) in state.holding {
                let before = fb.radius(contour: contour)
                #expect(
                    !fb.setTwoRadii(7, 9, contour: contour, edgeInContour: 1),
                    "\(state.name), contour \(contour)")
                #expect(fb.isConstant(contour: contour), "\(state.name): the law was changed")
                #expect(fb.radius(contour: contour) == before, "\(state.name): radius changed")
            }
        }
    }

    @Test("addEdge for an edge already in a contour that holds a result is refused")
    func addEdgeAlreadyInContour() throws {
        for state in try holdingStates() {
            let fb = state.builder
            let count = fb.contourCount
            for (contour, edge) in state.holding {
                let before = fb.radius(contour: contour)
                #expect(!fb.addEdge(edge, radius: 7), "\(state.name), contour \(contour)")
                #expect(
                    !fb.addEdge(edge, radius1: 7, radius2: 9), "\(state.name), contour \(contour)")
                #expect(fb.radius(contour: contour) == before, "\(state.name): radius changed")
            }
            #expect(fb.contourCount == count, "\(state.name): a contour appeared")
        }
    }

    // MARK: - Controls: what was allowed is still allowed

    /// Stops a refusal wired to say no to everything.
    @Test("a contour that holds nothing still takes the same changes")
    func untouchedContourStillAccepts() throws {
        let (box, first, second) = try boxAndEdges()

        // Never built, never simulated.
        let fresh = try #require(FilletBuilder(shape: box))
        try #require(fresh.addEdge(first, radius: 1))
        let vertex = try #require(fresh.firstVertex(contour: 1))
        #expect(fresh.setRadius(2, contour: 1, vertex: vertex))
        #expect(fresh.setTwoRadii(1, 3, contour: 1, edgeInContour: 1))
        #expect(fresh.addEdge(first, radius: 4))
        #expect(fresh.addEdge(first, radius1: 1, radius2: 2))

        // The contour a simulation of another contour never reached.
        let twoSimulatedFirst = try #require(FilletBuilder(shape: box))
        try #require(twoSimulatedFirst.addEdge(first, radius: 1))
        try #require(twoSimulatedFirst.addEdge(second, radius: 1))
        twoSimulatedFirst.simulate(contour: 1)
        let secondVertex = try #require(twoSimulatedFirst.firstVertex(contour: 2))
        #expect(twoSimulatedFirst.setRadius(2, contour: 2, vertex: secondVertex))
        #expect(twoSimulatedFirst.setTwoRadii(1, 3, contour: 2, edgeInContour: 1))
        #expect(twoSimulatedFirst.addEdge(second, radius: 4))

        // A contour whose build was declined holds no result: its radii can still be changed, so
        // the usual retry (a smaller radius, then build again) keeps working.
        let declined = try #require(FilletBuilder(shape: box))
        try #require(declined.addEdge(first, radius: 20))
        try #require(declined.build() == nil)
        try #require(declined.computedSurfaceCount(contour: 1) == 0)
        let declinedVertex = try #require(declined.firstVertex(contour: 1))
        #expect(declined.setRadius(1, contour: 1, vertex: declinedVertex))
        #expect(declined.addEdge(first, radius: 1))
    }

    @Test("reset lifts the refusal")
    func resetLiftsIt() throws {
        for state in try holdingStates() {
            let fb = state.builder
            fb.reset()
            for (contour, edge) in state.holding {
                let vertex = try #require(fb.firstVertex(contour: contour), "\(state.name)")
                #expect(
                    fb.setRadius(2, contour: contour, vertex: vertex),
                    "\(state.name), contour \(contour)")
                #expect(fb.setTwoRadii(1, 3, contour: contour, edgeInContour: 1), "\(state.name)")
                #expect(fb.addEdge(edge, radius: 4), "\(state.name)")
            }
        }
    }

    @Test("the edge form still sets a radius after a build, and a new edge still joins")
    func unchangedPaths() throws {
        let (box, first, second) = try boxAndEdges()
        let fb = try #require(FilletBuilder(shape: box))
        try #require(fb.addEdge(first, radius: 1))
        try #require(fb.build() != nil)

        // Clears the split before it replays anything, so it never faulted and is not refused.
        #expect(fb.setRadius(2, contour: 1, edge: first))

        // An edge that belongs to no contour opens a new one, whose spine is not split.
        #expect(fb.addEdge(second, radius: 1))
        #expect(fb.contourCount == 2)
    }
}
