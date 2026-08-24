import Foundation
import Testing

@testable import OCCTSwift

/// #520: the five `BRepFilletAPI_MakeFillet` edge-list entry points now agree on what an edge index
/// means, on what an unresolvable one does, and on what a radius law may contain.
///
/// Ground truth for the pinned kernel is in `Scripts/repro/520-fillet-edge-index-contracts/`. Three
/// measurements shaped this suite:
///
/// 1. `SetRadius(radius, param, 1)` has no `(Real, Real, Integer)` overload, so the curve parameter
///    `OCCTShapeFilletVariable` computed was truncated to an `int` and used as the *contour* index.
///    A 20mm box filleted with `[(0, 1.0), (1, 3.0)]` measured 7995.707963, which is exactly the
///    constant-1.0 result; the profile OCCT was asked for gives 7981.047467.
/// 2. A contour added by `Add(edge)` that never receives a radius makes `Build()` SIGSEGV, not a
///    `Standard_Failure`, so no `catch (...)` in the bridge can turn it into `nil`.
/// 3. A negative radius inside a `UandR` profile does *not* fail `IsDone()` the way
///    `Add(radius, edge)` does (#489). It reports success and hands back a shape
///    `BRepCheck_Analyzer` rejects.
@Suite("Fillet Edge-Index And Radius-Law Contracts (#520)")
struct Issue520FilletContractTests {

    // MARK: - The radius law is applied, not silently collapsed to a constant

    /// The headline defect: `filletedVariable` produced the constant-radius shape for the first
    /// profile point and discarded the rest.
    @Test("A variable profile removes more material than its smallest radius alone")
    func variableProfileIsNotConstant() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("no edge 0")
            return
        }

        let tapered = box.filletedVariable(edgeIndex: 0, radiusProfile: [(0.0, 1.0), (1.0, 3.0)])
        let constantSmall = box.filleted(edges: [edge], radius: 1.0)
        let constantLarge = box.filleted(edges: [edge], radius: 3.0)

        #expect(tapered != nil)
        #expect(constantSmall != nil)
        #expect(constantLarge != nil)
        guard let taperedVolume = tapered?.volume,
            let smallVolume = constantSmall?.volume,
            let largeVolume = constantLarge?.volume
        else {
            Issue.record("a fillet produced no volume")
            return
        }
        // A radius growing 1 -> 3 along the edge removes strictly more than a constant 1 and
        // strictly less than a constant 3. Before the fix the first of these was an equality.
        #expect(taperedVolume < smallVolume)
        #expect(taperedVolume > largeVolume)
    }

    /// Three points, so OCCT's two-point shortcut is not taken and the interior point matters.
    @Test("An interior profile point changes the result")
    func variableProfileInteriorPointHonoured() {
        let box = Shape.box(width: 30, height: 30, depth: 30)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("no edge 0")
            return
        }

        let bulged = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.0, 1.0), (0.5, 4.0), (1.0, 1.0)])
        let constantSmall = box.filleted(edges: [edge], radius: 1.0)

        #expect(bulged != nil)
        guard let bulgedVolume = bulged?.volume, let smallVolume = constantSmall?.volume else {
            Issue.record("a fillet produced no volume")
            return
        }
        #expect(bulgedVolume < smallVolume)
    }

    /// The two radius-law entry points reach the same OCCT overload with the same profile, so the
    /// same request must give the same shape through either one.
    @Test("Both radius-law entry points agree on the same profile")
    func radiusLawEntryPointsAgree() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("no edge 0")
            return
        }

        let viaVariable = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.0, 1.0), (1.0, 3.0)])
        let viaEvolving = box.filletEvolving([
            EvolvingFilletEdge(edge: edge, radiusPoints: [(0.0, 1.0), (1.0, 3.0)])
        ])

        #expect(viaVariable != nil)
        #expect(viaEvolving != nil)
        if let a = viaVariable?.volume, let b = viaEvolving?.volume {
            #expect(abs(a - b) < 1e-6)
        }
    }

    // MARK: - Index base (item 1): 0-based everywhere

    /// A single-point radius law is a constant radius, so filleting edge *i* through the evolving
    /// entry point must produce exactly what filleting edge *i* through the per-edge one does.
    /// While `EvolvingFilletEdge` was 1-based this comparison was off by one edge.
    @Test("The evolving entry point fillets the same edge the per-edge one does")
    func evolvingUsesTheSameEdgeIndexAsBlend() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("no edge 0")
            return
        }

        let viaBlend = box.blendedEdges([(edgeIndex: 0, radius: 2.0)])
        let viaEvolving = box.filletEvolving([
            EvolvingFilletEdge(edge: edge, radiusPoints: [(0.5, 2.0)])
        ])

        #expect(viaBlend != nil)
        #expect(viaEvolving != nil)
        if let a = viaBlend?.volume, let b = viaEvolving?.volume {
            #expect(abs(a - b) < 1e-6)
        }
    }

    /// Index 0 is a real edge now. Under the 1-based contract it named nothing and the call failed.
    @Test("Edge index 0 is accepted by the evolving entry point")
    func evolvingAcceptsIndexZero() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("no edge 0")
            return
        }
        #expect(edge.index == 0)
        #expect(
            box.filletEvolving([
                EvolvingFilletEdge(edge: edge, radiusPoints: [(0.0, 1.0), (1.0, 2.0)])
            ]) != nil)
    }

    // MARK: - An unresolvable index rejects the call (item 2)

    @Test("Per-edge blend rejects an out-of-range index")
    func blendRejectsOutOfRangeIndex() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.edges().count < 99_999)
        #expect(box.blendedEdges([(0, 2.0), (99_999, 2.0)]) == nil)
        #expect(box.blendedEdges([(-1, 2.0)]) == nil)
    }

    /// `filleted(edges:radius:)` takes `Edge` objects, so the way to hand it an index that does not
    /// resolve is to pass an edge belonging to a different, larger shape.
    @Test("Uniform fillet rejects an edge that is not this shape's")
    func uniformFilletRejectsForeignEdge() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let cut = box.subtracting(
            Shape.box(width: 20, height: 20, depth: 20)!
                .translated(by: SIMD3(10, 10, 10))!)
        guard let cut, cut.edges().count > box.edges().count else {
            Issue.record("cut did not produce more edges than the box")
            return
        }
        guard let ownEdge = box.edge(at: 0),
            let foreignEdge = cut.edge(at: cut.edges().count - 1)
        else {
            Issue.record("could not select edges")
            return
        }
        #expect(foreignEdge.index >= box.edges().count)
        #expect(box.filleted(edges: [ownEdge, foreignEdge], radius: 1.0) == nil)
        #expect(
            box.filleted(
                edges: [ownEdge, foreignEdge],
                startRadius: 1.0, endRadius: 2.0) == nil)
    }

    @Test("History fillet rejects an out-of-range index")
    func historyFilletRejectsOutOfRangeIndex() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.filletedWithFullHistory(radius: 1.0, edges: [0, 99_999]) == nil)
    }

    @Test("Both radius-law entry points reject an out-of-range index")
    func radiusLawEntryPointsRejectOutOfRangeIndex() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("no edge 0")
            return
        }
        #expect(
            box.filletedVariable(
                edgeIndex: 99_999,
                radiusProfile: [(0.0, 1.0), (1.0, 2.0)]) == nil)
        #expect(
            box.filletedVariable(
                edgeIndex: -1,
                radiusProfile: [(0.0, 1.0), (1.0, 2.0)]) == nil)

        var outOfRange = EvolvingFilletEdge(edge: edge, radiusPoints: [(0.0, 1.0), (1.0, 2.0)])
        outOfRange.edgeIndex = 99_999
        #expect(box.filletEvolving([outOfRange]) == nil)
    }

    // MARK: - Radius validation on the radius-law entry points (item 3)

    @Test("Variable fillet rejects a non-positive radius anywhere in the profile")
    func variableRejectsNonPositiveRadius() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        #expect(box.filletedVariable(edgeIndex: 0, radiusProfile: [(0.0, 1.0), (1.0, 0.0)]) == nil)
        #expect(
            box.filletedVariable(edgeIndex: 0, radiusProfile: [(0.0, 1.0), (1.0, -3.0)]) == nil)
        #expect(
            box.filletedVariable(
                edgeIndex: 0,
                radiusProfile: [(0.0, Double.nan), (1.0, 2.0)]) == nil)
    }

    /// The measurement that makes this more than hygiene: through the profile overload a negative
    /// radius reported `IsDone() == 1` and handed back a shape `BRepCheck_Analyzer` rejects, so the
    /// caller received an invalid shape presented as success.
    @Test("Evolving fillet rejects a non-positive radius anywhere in the profile")
    func evolvingRejectsNonPositiveRadius() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("no edge 0")
            return
        }
        #expect(
            box.filletEvolving([
                EvolvingFilletEdge(edge: edge, radiusPoints: [(0.0, 1.0), (1.0, -3.0)])
            ]) == nil)
        #expect(
            box.filletEvolving([
                EvolvingFilletEdge(edge: edge, radiusPoints: [(0.0, 1.0), (1.0, 0.0)])
            ]) == nil)
        #expect(
            box.filletEvolving([
                EvolvingFilletEdge(edge: edge, radiusPoints: [(0.0, Double.nan), (1.0, 2.0)])
            ]) == nil)
    }

    // MARK: - Parameter validation on the radius-law entry points (item 3)

    @Test("A profile parameter outside 0...1 rejects the call")
    func parametersOutsideUnitRangeRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("no edge 0")
            return
        }
        #expect(
            box.filletedVariable(
                edgeIndex: 0,
                radiusProfile: [(-5.0, 1.0), (1.0, 3.0)]) == nil)
        #expect(
            box.filletedVariable(
                edgeIndex: 0,
                radiusProfile: [(0.0, 1.0), (7.0, 3.0)]) == nil)
        #expect(
            box.filletedVariable(
                edgeIndex: 0,
                radiusProfile: [(Double.nan, 1.0), (1.0, 3.0)]) == nil)
        #expect(
            box.filletEvolving([
                EvolvingFilletEdge(edge: edge, radiusPoints: [(-5.0, 1.0), (0.0, 4.0), (7.0, 1.0)])
            ]) == nil)
    }

    /// OCCT renormalises a 3+ point profile with `(U - Uf) / (Ul - Uf)`, which divides by zero when
    /// every parameter is equal and silently reverses the law when they descend. Neither is what
    /// the caller wrote, so both are rejected.
    @Test("Profile parameters must strictly increase")
    func nonIncreasingParametersRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("no edge 0")
            return
        }
        #expect(
            box.filletedVariable(
                edgeIndex: 0,
                radiusProfile: [(0.5, 1.0), (0.5, 4.0), (0.5, 1.0)]) == nil)
        #expect(
            box.filletedVariable(
                edgeIndex: 0,
                radiusProfile: [(1.0, 1.0), (0.5, 4.0), (0.0, 2.0)]) == nil)
        #expect(
            box.filletEvolving([
                EvolvingFilletEdge(edge: edge, radiusPoints: [(1.0, 1.0), (0.0, 3.0)])
            ]) == nil)
    }

    // MARK: - Contours that never receive a radius (the SIGSEGV paths)

    /// An empty radius law left the contour without one, and `Build()` then SIGSEGV'd. The crash is
    /// an OS signal, so the bridge's `catch (...)` never saw it: this test used to take the whole
    /// test process down rather than fail.
    @Test("An empty radius law is rejected rather than crashing the build")
    func emptyRadiusLawRejected() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        guard let edge = box.edge(at: 0) else {
            Issue.record("no edge 0")
            return
        }
        #expect(box.filletEvolving([EvolvingFilletEdge(edge: edge, radiusPoints: [])]) == nil)
        #expect(box.filletEvolving([]) == nil)
    }

    /// The other route to a radius-less contour: `filletedVariable` mapped its parameters onto the
    /// edge's own curve range and passed them where OCCT wanted a contour index, so every
    /// `SetRadius` was dropped for any edge whose range does not start at 0. Box edges all start at
    /// 0, which is why this went unnoticed; the edges a boolean cut produces do not.
    @Test("A variable fillet on a re-parameterised edge does not crash")
    func variableFilletOnReparameterisedEdge() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let offset = Shape.box(width: 20, height: 20, depth: 20)!.translated(by: SIMD3(10, 10, 10))!
        guard let cut = box.subtracting(offset) else {
            Issue.record("cut failed")
            return
        }
        // Edge 8 of this cut measured a curve range of [5, 15]; scan rather than hard-code it,
        // since edge ordering is not guaranteed.
        var checked = 0
        for edge in cut.edges() {
            guard let range = edge.parameterBounds, range.first != 0 else { continue }
            checked += 1
            // Whatever OCCT makes of this edge, the call must return rather than SIGSEGV, and any
            // shape it hands back must be a real one.
            if let filleted = cut.filletedVariable(
                edgeIndex: edge.index,
                radiusProfile: [(0.0, 0.5), (1.0, 1.0)])
            {
                #expect(filleted.isValid)
            }
        }
        #expect(checked > 0, "no re-parameterised edge in the cut result")
    }
}
