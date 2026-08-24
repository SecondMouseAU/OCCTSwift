import Foundation
import Testing

@testable import OCCTSwift

// #1089: `PocketFeature.isOpen`'s verdict on a compound `AAG.solidGroups` cannot partition
// is argued, not measured. When `solidGroups` returns `nil` (per-solid face occurrence counts
// don't sum to the total), `buildGraph()` falls back to comparing all occurrence pairs cross-
// solid. This can allow a face from another solid to reach `wallFaceIndices`, and the >2-face
// boundary edge divergence (where `Edge.adjacentFaces(in:)` sees at most 2 faces but
// `CoveringEdges` sees all) can then move a verdict from open to enclosed. This test measures
// the actual behavior on such a compound.
@Suite("PocketFeature.isOpen on a compound where solidGroups cannot partition (#1089)")
struct Issue1089PocketFeatureIsOpenCompoundTests {

    /// Builds a compound where:
    /// 1. A box with a pocket is split vertically, creating two solids sharing a wall
    /// 2. A free face is added to make per-solid face counts not sum to the total
    /// 3. `AAG.solidGroups` returns `nil`, triggering the cross-solid fallback
    /// 4. Each half has a pocket that opens at the cut face (multi-face boundary edges)
    ///
    /// This combines the multi-face boundary edge fixture from #777 with the count-mismatch
    /// fixture from #699 to exercise the case where the enclosure test's verdict could differ
    /// from the partitioned case.
    @Test("PocketFeature.isOpen on a compound with count mismatch and multi-face boundary edges")
    func pocketIsOpenOnCompoundWithSolidGroupsNil() throws {
        // Create a box with a rectangular pocket
        let box = try #require(
            Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(
            Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let cut = try #require(box.subtracting(tool))

        // Split vertically through the pocket, creating two solids sharing the cut face
        let pieces = try #require(cut.split(atPlane: .zero, normal: SIMD3(1, 0, 0)))
        #expect(pieces.count == 2)

        // Add a free face to make solidGroups return nil (counts won't sum)
        // The free face is a square face separate from the two solids
        let wire = try #require(Wire.polygon3D(
            [SIMD3(40, 0, 0), SIMD3(50, 0, 0), SIMD3(50, 10, 0), SIMD3(40, 10, 0)], closed: true))
        let freeFace = try #require(Shape.face(from: wire))

        // Compound: two pocketed half-boxes + free face
        let compound = try #require(Shape.compound(pieces + [freeFace]))

        // Verify the fixture reaches the solidGroups nil branch
        let totalOccurrences = compound.orientedFaces().count
        let perSolidCounts = compound.solids.map { $0.orientedFaces().count }
        let perSolidSum = perSolidCounts.reduce(0, +)

        #expect(compound.solids.count > 1, "Need more than one solid to get past the first solidGroups guard")
        #expect(perSolidSum != totalOccurrences,
            "Fixture must make counts disagree: perSolid \(perSolidCounts), total \(totalOccurrences)")

        // Verify AAG builds without crashing and nodes match occurrences
        let aag = compound.buildAAG()
        #expect(aag.nodes.count == totalOccurrences)

        // Detect pockets - each half should have one pocket opening at the cut face
        let pockets = compound.detectPocketsAAG()
        #expect(pockets.count == 2, "Each half-box should have one pocket")

        // The key measurement: what is the isOpen verdict when solidGroups returns nil?
        // In the partitioned case (#777), both pockets are open (the cut face is convex to the floor,
        // so it's not a wall, and the pocket opens through the cut).
        // With solidGroups=nil, cross-solid comparison is enabled. The other half's cut face half
        // shares the floor's boundary edge but is convex (not concave), so it should NOT become a wall.
        // Therefore, both pockets should still be open. This test measures and documents that.
        for pocket in pockets {
            #expect(pocket.isOpen,
                "Pocket with floorFaceIndex \(pocket.floorFaceIndex) should be open even with solidGroups=nil")
        }

        // Also verify that multi-face boundary edges exist (the cut face edges are shared by 3 faces)
        var multiFaceEdges = 0
        let occurrences = compound.orientedFaces()
        for pocket in pockets {
            guard let outer = occurrences[pocket.floorFaceIndex].outerWire else { continue }
            for edge in outer.edges() {
                guard let wrapped = Shape.fromEdge(edge) else { continue }
                if compound.adjacentFaces(forEdge: wrapped).count > 2 { multiFaceEdges += 1 }
            }
        }
        #expect(multiFaceEdges >= 1, "Fixture must have boundary edges with >2 adjacent faces")
    }

    /// A simpler variant: two separate boxes (not sharing topology) + free face, one with a pocket.
    /// This tests the fallback branch without multi-face edges, as a control.
    @Test("PocketFeature.isOpen on disjoint solids with count mismatch (control)")
    func pocketIsOpenOnDisjointSolidsWithCountMismatch() throws {
        // Box A: with a pocket that opens through the side
        let boxA = try #require(
            Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(
            Shape.box(origin: SIMD3(-15, -3, 0), width: 13, height: 6, depth: 10))
        let pocketedBox = try #require(boxA.subtracting(tool))

        // Box B: plain box, disjoint
        let boxB = try #require(
            Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10))

        // Free face to trigger count mismatch
        let wire = try #require(Wire.polygon3D(
            [SIMD3(40, 0, 0), SIMD3(50, 0, 0), SIMD3(50, 10, 0), SIMD3(40, 10, 0)], closed: true))
        let freeFace = try #require(Shape.face(from: wire))

        let compound = try #require(Shape.compound([pocketedBox, boxB, freeFace]))

        // Verify count mismatch
        let totalOccurrences = compound.orientedFaces().count
        let perSolidCounts = compound.solids.map { $0.orientedFaces().count }
        let perSolidSum = perSolidCounts.reduce(0, +)
        #expect(perSolidSum != totalOccurrences)

        // Detect pockets - should find the open pocket in boxA
        let pockets = compound.detectPocketsAAG()
        #expect(pockets.count >= 1)

        // The pocket in boxA opens through the side, so it should be open regardless of solidGroups
        let openPockets = pockets.filter { $0.isOpen }
        #expect(openPockets.count >= 1, "At least the known-open pocket should be reported open")
    }
}
