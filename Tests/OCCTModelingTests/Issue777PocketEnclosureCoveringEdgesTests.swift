import Foundation
import Testing

@testable import OCCTSwift

// #777: `PocketFeature.isOpen`'s enclosure test used to ask `Edge.adjacentFaces(in:)`, per floor
// boundary edge, which faces bound that edge in the whole shape, and then match those against the
// covering set. `OCCTEdgeGetAdjacentFaces` rebuilds a whole-shape `TopExp::MapShapesAndAncestors`
// edge-to-face map on every call, so the cost scaled with the shape rather than with the pocket.
//
// The predicate is now evaluated from the other end, over `CoveringEdges`: a floor's boundary edge
// borders one of the covering faces exactly when it is one of that face's own edges, resolved once
// per pocket. `Scripts/repro/777-pocket-isopen/` holds the measurement, including the sweep showing
// that the face set the old construction saw is always a SUBSET of the one this sees, never the
// other way round, so the replacement can only ever move a verdict from open to enclosed.
//
// The cases below pin the membership rule through `CoveringEdges` itself rather than only through
// a pocket verdict, because a verdict is a lossy view of it. The pre-PR review found that the
// orientation case originally stopped at measuring the fixture and never called `CoveringEdges`,
// so it could not fail when the identity rule was swapped; it now does both, and the removal
// matrix in the PR body records which injection each case catches.
@Suite("The pocket enclosure test reads the covering faces' own edges (#777)")
struct Issue777PocketEnclosureCoveringEdgesTests {

    /// The square pocket `Issue735PocketEnclosureTests.squarePocketIsEnclosed` uses, resolved down
    /// to the pieces the enclosure test itself works on.
    ///
    /// `orientedFaces()` rather than the graph's own cached `faceOccurrences` (which is private):
    /// `AAG.buildGraph()` builds that cache from this same call and documents the two as
    /// index-for-index aligned, and `nodes.count == orientedFaces().count` is asserted below so a
    /// future divergence shows up here rather than as a silently mismatched index.
    private struct Fixture {
        let pocket: PocketFeature
        let occurrences: [Face]
        let floorBoundaryEdges: [Edge]
    }

    private static func squarePocket() throws -> Fixture {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let tool = try #require(
            Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let cut = try #require(box.subtracting(tool))
        let graph = cut.buildAAG()
        let occurrences = cut.orientedFaces()
        #expect(graph.nodes.count == occurrences.count)
        let pocket = try #require(graph.detectPockets().first)
        #expect(pocket.wallFaceIndices.count == 4)
        let outer = try #require(occurrences[pocket.floorFaceIndex].outerWire)
        let edges = outer.edges()
        #expect(edges.count == 4)
        return Fixture(pocket: pocket, occurrences: occurrences, floorBoundaryEdges: edges)
    }

    // MARK: - The membership rule itself

    /// Every one of the floor's own boundary edges is an edge of one of the pocket's walls. This is
    /// the whole enclosure test, stated over the construction that now evaluates it.
    @Test("every floor boundary edge is a member of the walls' own edge set")
    func floorBoundaryEdgesAreMembersOfTheWallEdgeSet() throws {
        let fixture = try Self.squarePocket()
        let covering = CoveringEdges(
            facesAt: fixture.pocket.wallFaceIndices, in: fixture.occurrences)
        for edge in fixture.floorBoundaryEdges {
            #expect(covering.contains(edge))
        }
    }

    /// The scope half: an edge of a face that is NOT in the covering set must not be a member.
    ///
    /// The box's own bottom face is used rather than its top: this pocket opens through the top, so
    /// the top face genuinely shares the walls' upper edges and would be a member for a correct
    /// reason, which is exactly the fixture-that-stopped-meaning-its-name failure
    /// `okf/policies/measure-dont-assume.md` describes. The bottom face's four edges are shared
    /// only with the box's outer sides, none of which is a pocket wall.
    @Test("an edge of a face outside the covering set is not a member")
    func edgeOfANonCoveringFaceIsNotAMember() throws {
        let fixture = try Self.squarePocket()
        let bottomIndex = try #require(
            fixture.occurrences.indices.first { index in
                let face = fixture.occurrences[index]
                return face.isDownwardFacing() && face.isHorizontal() && (face.zLevel ?? 0) < -5
            })
        #expect(!fixture.pocket.wallFaceIndices.contains(bottomIndex))
        let bottomShape = try #require(Shape.fromFace(fixture.occurrences[bottomIndex]))
        let bottomEdges = bottomShape.edges()
        #expect(bottomEdges.count == 4)

        let covering = CoveringEdges(
            facesAt: fixture.pocket.wallFaceIndices, in: fixture.occurrences)
        for edge in bottomEdges {
            #expect(!covering.contains(edge))
        }
    }

    /// The identity rule, and #777's direct successor to the face-order property #753 pinned in
    /// `Issue753OffCenterPocketEnclosureTests`: the floor and the wall present the same edge with
    /// OPPOSITE orientations, so membership has to be `IsSame` (orientation ignored), never
    /// `IsEqual`.
    ///
    /// Two halves, and both are needed. The first measures the fixture rather than assuming it:
    /// all four of the floor's boundary edges are `isSame` and none is `isEqual` to the wall's own
    /// copy, and the two copies carry equal `hashCode`s, which is what lets the bucket lookup be
    /// orientation-insensitive too. The second puts each of those orientation-flipped edges
    /// through `CoveringEdges` itself.
    ///
    /// The second half exists because the first cannot fail when the rule is swapped: the pre-PR
    /// review injected `isEqual` into `CoveringEdges.contains` and only
    /// `floorBoundaryEdgesAreMembersOfTheWallEdgeSet` went red, because this test never
    /// constructed a `CoveringEdges` at all. It measured the premise and stopped short of the
    /// conclusion.
    @Test("membership ignores orientation, which is the only reason the shared edge matches at all")
    func membershipIgnoresOrientation() throws {
        let fixture = try Self.squarePocket()
        let covering = CoveringEdges(
            facesAt: fixture.pocket.wallFaceIndices, in: fixture.occurrences)
        var pairsFound = 0
        for wallIndex in fixture.pocket.wallFaceIndices {
            let wallShape = try #require(Shape.fromFace(fixture.occurrences[wallIndex]))
            for wallEdge in wallShape.subShapes(ofType: .edge) {
                for floorEdge in fixture.floorBoundaryEdges {
                    guard let floorShape = Shape.fromEdge(floorEdge),
                        wallEdge.isSame(as: floorShape)
                    else { continue }
                    pairsFound += 1
                    #expect(!wallEdge.isEqual(to: floorShape))
                    #expect(wallEdge.hashCode == floorShape.hashCode)
                    // The conclusion the two lines above are only the premise for: an edge the
                    // wall presents with the opposite orientation is still a member.
                    #expect(covering.contains(floorEdge))
                }
            }
        }
        // One shared edge per wall, and every one of them orientation-flipped: if this drops to
        // zero the assertions above become vacuous rather than failing.
        #expect(pairsFound == 4)
    }

    // MARK: - The boundary case the two constructions do not answer alike

    /// An edge bounded by MORE than two faces is the one place `Edge.adjacentFaces(in:)` and a
    /// per-face edge scan give different answers: the former stops after two, the latter sees them
    /// all (measured in `Scripts/repro/777-pocket-isopen/`, four such edges on this shape family).
    ///
    /// A pocketed box split down the middle and compounded is the only shape in this tree that
    /// presents one to the enclosure test. Both halves are genuinely open at the cut, because the
    /// floor meets the cut face at a CONVEX edge, so the cut face is not a wall and the floor's
    /// boundary edge there borders nothing in the covering set. The point of the test is that
    /// seeing more faces per edge must not turn that into a false enclosure, which is the only
    /// direction the replacement can move a verdict.
    ///
    /// **It does not isolate that mechanism**, and the distinction matters: the extra faces the
    /// new construction sees here belong to the other solid, and #699's same-solid restriction is
    /// what keeps them out of `wallFaceIndices`, not the enclosure test. So this is a
    /// characterization of the only >2-face fixture available, not a proof that the wider face set
    /// is harmless in general. `Scripts/repro/777-pocket-isopen/README.md` sets out the case that
    /// could still flip (a compound where `AAG.solidGroups` returns nil), which is argued rather
    /// than constructed.
    @Test("a floor boundary edge bounded by more than two faces does not fake an enclosure")
    func multiFaceBoundaryEdgeDoesNotFakeAnEnclosure() throws {
        let box = try #require(
            Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(
            Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let cut = try #require(box.subtracting(tool))
        let pieces = try #require(cut.split(atPlane: .zero, normal: SIMD3(1, 0, 0)))
        #expect(pieces.count == 2)
        let compound = try #require(Shape.compound(pieces))

        let occurrences = compound.orientedFaces()
        // The same alignment `squarePocket()` asserts, for the same reason: `buildGraph()` drops
        // any void-bounds face (#943), which would shift every occurrence index this test then
        // subscripts by `floorFaceIndex`.
        #expect(compound.buildAAG().nodes.count == occurrences.count)
        let pockets = compound.detectPocketsAAG()
        #expect(pockets.count == 2)

        var multiFaceEdges = 0
        for pocket in pockets {
            // Outside any `continue`: a floor whose outer wire could not be read still has a
            // verdict, and skipping the assertion with it would let this pass on a fixture that
            // stopped presenting two pockets.
            #expect(pocket.isOpen)
            guard let outer = occurrences[pocket.floorFaceIndex].outerWire else { continue }
            for edge in outer.edges() {
                guard let wrapped = Shape.fromEdge(edge) else { continue }
                if compound.adjacentFaces(forEdge: wrapped).count > 2 { multiFaceEdges += 1 }
            }
        }
        // Without this the suite would still pass on a shape whose edges are all 2-manifold, and
        // would have stopped testing the case it names.
        #expect(multiFaceEdges >= 1)
    }
}
