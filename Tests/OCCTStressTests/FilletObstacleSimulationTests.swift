import Foundation
import Testing

@testable import OCCTSwift

/// A fillet simulation that reaches a vertex whose neighbour face holds no edge to follow.
///
/// OCCT 8.0.2 (OCCT#1708) made `ChFi3d_Builder::StartSol` set the spine's `ChFiDS_StartsolFailure`
/// status and throw `Standard_Failure("StartSol: no matching obstacle edge")` where it used to
/// return `false`. `ChFi3d_Builder::Compute`, which `build()` runs, catches that around every stripe and
/// reports the contour as faulty, but `BRepFilletAPI_MakeFillet::Simulate` has no such catch: the
/// exception leaves OCCT and reaches the bridge. An exception that crosses the C boundary into
/// Swift-generated frames cannot be caught and ends the process, so `OCCTFilletBuilderSimulate`'s
/// function-level `catch (...)` is what keeps `simulate(contour:)` an ordinary call.
///
/// The model is the one attached to OCCT#1568, 19 faces and 42 edges, and `FilletObstacleTests`
/// pins what `build()` does with it: at radius 1.5, 12 of the 42 edges fillet and 8 are declined.
/// These are the same 8, reached through the other entry point.
///
/// This is its own suite, with one test per outcome, because the fault it guards ends the process:
/// run alone, the test that dies is the one that names the entry point.
@Suite("A fillet simulation that reaches an obstacle with no edge to follow")
struct FilletObstacleSimulationTests {

    /// `ChFiDS_StartsolFailure`, the status the throwing branch sets before it throws.
    private static let startSolFailure = 3

    private func loadModel() throws -> Shape {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/occt1568-fillet-obstacle-model.brep")
        return try Shape.loadBREP(from: url)
    }

    /// What `simulate(contour: 1)` left on the contour of one edge.
    private struct Simulated {
        /// `stripeStatus(contour: 1)`: 0 is ok, 3 `ChFiDS_StartsolFailure`, and -1 says the builder
        /// holds no contour, which is what OCCT leaves of an edge it finds unsuitable.
        let status: Int
        let surfaces: Int

        static let noContour = -1
    }

    /// The contour-1 outcome of simulating each edge of `model` alone at `radius`.
    private func simulateEachEdge(of model: Shape, radius: Double) throws -> [Simulated] {
        try model.edges().map { edge in
            let builder = try #require(FilletBuilder(shape: model))
            builder.addEdge(edge, radius: radius)
            builder.simulate(contour: 1)
            return Simulated(
                status: builder.stripeStatus(contour: 1),
                surfaces: builder.simulatedSurfaceCount(contour: 1))
        }
    }

    /// The control: at a radius that never reaches the obstacle branch, no simulation is declined,
    /// and the simulations that run each leave surface data behind.
    ///
    /// It runs on every kernel, so the test below cannot be vacuous because the model failed to load,
    /// or because simulation stopped doing anything. The 22 edges with no contour are the ones
    /// `build()` also refuses ("there are no suitable edges"); the 20 others are the ones
    /// `FilletObstacleTests` pins.
    @Test func controlRadiusDeclinesNoSimulation() throws {
        let model = try loadModel()
        let outcomes = try simulateEachEdge(of: model, radius: 1.0)
        #expect(outcomes.count == 42)
        #expect(outcomes.filter { $0.status == Simulated.noContour }.count == 22)
        #expect(outcomes.filter { $0.status == Self.startSolFailure }.isEmpty)
        #expect(
            outcomes.filter { $0.status == 0 && $0.surfaces > 0 }.count == 20,
            "every edge the builder holds a contour for simulates to completion")
    }

    /// At the exact-tangent radius the obstacle branch is reached on eight edges. Each simulation
    /// returns to its caller, and the contour says why it stopped.
    ///
    /// Without the bridge's catch the exception ends the process at the first of the eight, so
    /// reaching the assertions is the regression check. Every shipping kernel flavour holds the
    /// throwing branch OCCT#1708 wrote (ledger row F0054, absorbed in 8.0.2), so no kernel gate.
    @Test
    func simulationDeclinedAtTheObstacleReturnsAndReportsWhy() throws {
        let model = try loadModel()
        let outcomes = try simulateEachEdge(of: model, radius: 1.5)
        #expect(outcomes.count == 42)
        #expect(outcomes.filter { $0.status == Simulated.noContour }.count == 22)
        #expect(
            outcomes.filter { $0.status == Self.startSolFailure }.count == 8,
            "eight of the 42 edges reach the obstacle branch at radius 1.5")
        #expect(
            outcomes.filter { $0.status == 0 && $0.surfaces > 0 }.count == 12,
            "the other twelve still simulate to completion")
    }
}
