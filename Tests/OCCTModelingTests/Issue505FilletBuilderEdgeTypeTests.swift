import Foundation
import Testing

@testable import OCCTSwift

// MARK: - #505: FilletBuilder's radius laws are keyed by an Edge, and check that they are

/// `BRepFilletAPI_MakeFillet::GetBounds`, `GetLaw` and `SetLaw` all take a `const TopoDS_Edge&`, but
/// the bridge used to hand the first two a generic `OCCTShapeRef` and only the third an
/// `OCCTEdgeRef`. Every caller therefore held the wrong type for two of the three: `addEdge`,
/// `removeEdge`, `setRadius` and `contour(for:)` all speak `Edge`, so reading a law meant converting
/// that `Edge` to a `Shape` and back again to write one.
///
/// Fixing the type surfaced what the three share underneath: `ChFiDS_FilSpine::ChangeLaw(E)` resolves
/// the edge with `ChFiDS_Spine::Index(E)`, which answers `0` for an edge the contour does not hold,
/// and then indexes the spine's abscissa array with `0 - 1`. OCCT's bounds check there is compiled
/// out of the pinned Release build, so nothing rejected the request: measured on a box, asking
/// contour 1 about contour 2's edge returned contour *1*'s law and reported success, and `SetLaw`
/// with an edge in no contour at all overwrote contour 1's law instead
/// (`Scripts/repro/505-filletbuilder-edge-type/`). The bridge now rejects those pairs.
@Suite("FilletBuilder radius laws are keyed by an edge (#505)")
struct Issue505FilletBuilderEdgeTypeTests {

    private static func box() -> Shape? {
        Shape.box(width: 10, height: 10, depth: 10)
    }

    /// A contour whose radius evolves has a law; a constant one does not (see
    /// ``constantRadiusContourHasNoLaw``), so every case that needs a law starts here.
    private static func builtEvolvingContour() throws -> (
        builder: FilletBuilder, edge: Edge, box: Shape
    ) {
        let box = try #require(Self.box())
        let builder = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(builder.addEdge(edge, radius1: 0.5, radius2: 2.0))
        #expect(builder.build() != nil)
        #expect(builder.contour(for: edge) == 1)
        return (builder, edge, box)
    }

    /// The round trip the type split made impossible to write with one value: read the law's range,
    /// build a law over it, set it, read it back. All four calls take the same `Edge`.
    @Test("One Edge value threads through getBounds, setLaw and getLaw")
    func oneEdgeValueThroughAllThree() throws {
        let (builder, edge, _) = try Self.builtEvolvingContour()

        let bounds = try #require(builder.getBounds(contour: 1, edge: edge))
        #expect(bounds.first < bounds.last)

        let before = try #require(builder.getLaw(contour: 1, edge: edge))
        #expect(abs(before.value(at: bounds.first) - 0.5) < 1e-9)
        #expect(abs(before.value(at: bounds.last) - 2.0) < 1e-9)

        let replacement = try #require(
            LawFunction.linear(
                from: 4, to: 4,
                parameterRange: bounds.first...bounds.last))
        #expect(builder.setLaw(contour: 1, edge: edge, law: replacement))

        let after = try #require(builder.getLaw(contour: 1, edge: edge))
        #expect(abs(after.value(at: bounds.first) - 4.0) < 1e-9)
        #expect(abs(after.value(at: bounds.last) - 4.0) < 1e-9)
    }

    /// The guard, on the read side: contour 1 knows nothing about contour 2's edge. Before #505 both
    /// calls answered with contour 1's own bounds and law, and reported success while doing it.
    @Test("An edge from another contour is rejected, not answered about")
    func edgeFromAnotherContourIsRejected() throws {
        let box = try #require(Self.box())
        let builder = try #require(FilletBuilder(shape: box))
        let edges = box.edges()
        #expect(edges.count == 12)
        let first = try #require(edges.first)
        let other = try #require(edges.last)

        #expect(builder.addEdge(first, radius1: 0.5, radius2: 2.0))
        #expect(builder.addEdge(other, radius1: 1.0, radius2: 3.0))
        #expect(builder.build() != nil)
        #expect(builder.contourCount == 2)

        let firstContour = builder.contour(for: first)
        let otherContour = builder.contour(for: other)
        #expect(firstContour != 0)
        #expect(otherContour != 0)
        #expect(firstContour != otherContour)

        // Each contour answers about its own edge...
        #expect(builder.getBounds(contour: firstContour, edge: first) != nil)
        #expect(builder.getLaw(contour: otherContour, edge: other) != nil)

        // ...and about no other.
        #expect(builder.getBounds(contour: firstContour, edge: other) == nil)
        #expect(builder.getLaw(contour: firstContour, edge: other) == nil)
        #expect(builder.getBounds(contour: otherContour, edge: first) == nil)
        #expect(builder.getLaw(contour: otherContour, edge: first) == nil)
    }

    /// The guard on the write side, which is the one that did damage: `SetLaw` with an edge the
    /// contour does not hold used to overwrite that contour's law and report nothing.
    @Test("setLaw with an edge the contour does not hold leaves the contour's law alone")
    func setLawWithForeignEdgeChangesNothing() throws {
        let (builder, edge, box) = try Self.builtEvolvingContour()
        let foreign = try #require(box.edges().last)
        #expect(builder.contour(for: foreign) == 0)  // in no contour at all

        let bounds = try #require(builder.getBounds(contour: 1, edge: edge))
        let intruder = try #require(
            LawFunction.linear(
                from: 4, to: 4,
                parameterRange: bounds.first...bounds.last))
        #expect(builder.setLaw(contour: 1, edge: foreign, law: intruder) == false)

        // Contour 1 still reports the radii it was added with.
        let law = try #require(builder.getLaw(contour: 1, edge: edge))
        #expect(abs(law.value(at: bounds.first) - 0.5) < 1e-9)
        #expect(abs(law.value(at: bounds.last) - 2.0) < 1e-9)

        // And the foreign edge is not readable either.
        #expect(builder.getBounds(contour: 1, edge: foreign) == nil)
        #expect(builder.getLaw(contour: 1, edge: foreign) == nil)
    }

    /// OCCT checks the top of the contour range (`IC <= NbElements()`) but not the bottom, so `0`
    /// and `-1` used to answer about contour 1.
    @Test("A contour index outside 1...contourCount is rejected at both ends")
    func contourIndexOutsideRangeIsRejected() throws {
        let (builder, edge, _) = try Self.builtEvolvingContour()
        #expect(builder.contourCount == 1)

        let bounds = try #require(builder.getBounds(contour: 1, edge: edge))
        let law = try #require(
            LawFunction.linear(
                from: 4, to: 4,
                parameterRange: bounds.first...bounds.last))

        for contour in [0, -1, 2, 99] {
            #expect(builder.getBounds(contour: contour, edge: edge) == nil, "contour \(contour)")
            #expect(builder.getLaw(contour: contour, edge: edge) == nil, "contour \(contour)")
            #expect(
                builder.setLaw(contour: contour, edge: edge, law: law) == false,
                "contour \(contour)")
        }

        // The law contour 1 holds is still its own.
        let unchanged = try #require(builder.getLaw(contour: 1, edge: edge))
        #expect(abs(unchanged.value(at: bounds.first) - 0.5) < 1e-9)
    }

    /// A constant radius is not stored as a flat law: `ChFiDS_FilSpine::ChangeLaw` throws
    /// "no law on constant edges" for it, which all three calls report as no law.
    @Test("A constant-radius contour has no law to read or replace")
    func constantRadiusContourHasNoLaw() throws {
        let box = try #require(Self.box())
        let builder = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(builder.addEdge(edge, radius: 1.0))
        #expect(builder.build() != nil)
        #expect(builder.isConstant(contour: 1))

        #expect(builder.getBounds(contour: 1, edge: edge) == nil)
        #expect(builder.getLaw(contour: 1, edge: edge) == nil)
        let law = try #require(LawFunction.linear(from: 2, to: 3, parameterRange: 0...10))
        #expect(builder.setLaw(contour: 1, edge: edge, law: law) == false)
    }

    /// The law exists only once the contour's spine has been split, which `build()` does and
    /// `simulate(contour:)` also does without building the blend surfaces. Note that the range
    /// differs between the two: after `simulate` it is the spine's own `[0, 10]`, and after `build`
    /// it runs past both ends of the edge.
    @Test("The law is unreachable before build, and reachable after simulate")
    func lawNeedsASpineSplit() throws {
        let box = try #require(Self.box())
        let builder = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(builder.addEdge(edge, radius1: 0.5, radius2: 2.0))

        #expect(builder.getBounds(contour: 1, edge: edge) == nil)
        #expect(builder.getLaw(contour: 1, edge: edge) == nil)

        builder.simulate(contour: 1)
        let simulated = try #require(builder.getBounds(contour: 1, edge: edge))
        #expect(simulated.first < simulated.last)
        #expect(builder.getLaw(contour: 1, edge: edge) != nil)

        #expect(builder.build() != nil)
        let built = try #require(builder.getBounds(contour: 1, edge: edge))
        #expect(built.first <= simulated.first)
        #expect(built.last >= simulated.last)
    }
}
