import Testing
import Foundation
@testable import OCCTSwift

// #735: `PocketFeature.isOpen` was `wallIndices.count < 3`, a wall count, not a test of
// enclosure. A blind cylindrical pocket has exactly ONE wall (the cylinder's own lateral
// face) and is fully enclosed, so it reported `isOpen == true`. Three walls was also the
// wrong threshold on its own terms: a genuinely open three-sided slot and a closed
// three-walled (e.g. triangular) pocket both have `wallIndices.count == 3` and are
// indistinguishable by counting alone.
//
// Fixed by testing the definition the field documents directly: the floor plus its walls
// form a closed loop around the floor's own boundary exactly when every boundary edge of
// the floor's outer wire is shared with a wall in `wallFaceIndices`. This is computed from
// what `AAG` already holds -- `AAGEdge.sharedEdgeCount` for each floor/wall pair (already
// built by `buildGraph()`), and the floor's own outer wire via `shape.orientedFaces()`, the
// same reindexing `PocketFeature.floorFaceIndex`'s own doc comment documents as correct.
//
// A bounding-box containment check (is the pocket's own bbox strictly inside the parent
// solid's, in the horizontal axes) was considered and rejected: it is cheaper, but wrong
// for a pocket that legitimately reaches an outer wall of the part while still being fully
// enclosed on every side that matters. Enclosure is a property of the wall loop, not of the
// pocket's position in space. See `AAG.detectPockets()`'s doc comment in
// `FeatureRecognition.swift` for the full reasoning.
@Suite("PocketFeature.isOpen tests enclosure, not wall count (#735)")
struct Issue735PocketEnclosureTests {

    // MARK: - The headline: one wall, fully enclosed

    /// The issue's own construction, byte for byte. A cylindrical bore has exactly one wall
    /// (the cylinder's lateral face) and is fully enclosed -- the floor's entire boundary (a
    /// single circular edge) is shared with that one wall. `wallIndices.count < 3` reported
    /// this as open; it is not.
    @Test("a blind cylindrical pocket (one wall) is fully enclosed")
    func cylindricalPocketIsEnclosed() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.cylinder(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 8, height: 25))
        let cut = try #require(box.subtracting(tool))

        let pockets = cut.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 1)
        #expect(!pocket.isOpen)
    }

    // MARK: - Non-regression: the square pocket everyone already relies on

    /// A square pocket's four walls each cover exactly one of the floor's four boundary
    /// edges, closing the loop. This was already correct under the old wall-count formula
    /// (4 is not < 3); it must stay correct under the enclosure test.
    @Test("a square pocket (four walls) is fully enclosed")
    func squarePocketIsEnclosed() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let result = try #require(box.subtracting(pocketTool))

        let pockets = result.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 4)
        #expect(!pocket.isOpen)
    }

    // MARK: - The threshold's other blind spot: three walls, genuinely open

    /// A slot cut so it opens through the box's own side face: two side walls and one end
    /// wall (3 walls total), but the floor's fourth boundary edge -- where the slot exits
    /// the part -- borders no wall at all. `wallIndices.count < 3` reported this as closed
    /// (3 is not < 3); it is open. Measured: floor has 4 boundary edges, the 3 walls cover
    /// only 3 of them.
    @Test("a three-walled slot that opens through the parent's side is NOT enclosed")
    func openThreeWalledSlotIsNotEnclosed() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        // Extends past the box's own x = -10 face (tool starts at x = -15), so the slot
        // opens through that side rather than bottoming out against a fourth wall.
        let tool = try #require(Shape.box(origin: SIMD3(-15, -3, 0), width: 13, height: 6, depth: 10))
        let cut = try #require(box.subtracting(tool))

        let pockets = cut.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 3)
        #expect(pocket.isOpen)
    }

    /// The threshold's counterexample in the other direction: three walls that DO close the
    /// loop. A triangular pocket's three walls each cover exactly one of the floor's three
    /// boundary edges. Paired with the previous test, this is the pair the old formula could
    /// not tell apart -- both have `wallIndices.count == 3`, one open and one closed.
    @Test("a three-walled triangular pocket IS fully enclosed")
    func closedThreeWalledTriangularPocketIsEnclosed() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let triangle = try #require(Wire.polygon3D([
            SIMD3(0, 4, 10),
            SIMD3(-4, -4, 10),
            SIMD3(4, -4, 10),
        ], closed: true))
        let tool = try #require(Shape.extrude(profile: triangle, direction: SIMD3(0, 0, -1), length: 5))
        let cut = try #require(box.subtracting(tool))

        let pockets = cut.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 3)
        #expect(!pocket.isOpen)
    }

    // MARK: - Non-regression: fewer than three walls, genuinely open

    /// A through-slot spanning the box's full width has two side walls and no end wall at
    /// all; both ends are open. This was already correctly `isOpen == true` under the old
    /// formula (2 < 3); confirms the new enclosure test agrees for the case the old formula
    /// got right by coincidence of count, not by measuring enclosure.
    @Test("a two-walled through-slot is not enclosed")
    func twoWalledThroughSlotIsNotEnclosed() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.box(origin: SIMD3(-15, -3, 0), width: 25, height: 6, depth: 10))
        let cut = try #require(box.subtracting(tool))

        let pockets = cut.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 2)
        #expect(pocket.isOpen)
    }
}
