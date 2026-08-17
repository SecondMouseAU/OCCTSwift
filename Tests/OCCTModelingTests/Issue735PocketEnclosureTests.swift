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
// the floor's outer wire borders a wall in `wallFaceIndices`.
//
// Review of the first version of this fix (PR #753) found that summing `AAGEdge.
// sharedEdgeCount` over `wallIndices` and comparing to the outer wire's edge count, wire
// scoped on one side only, could still misreport a genuinely open pocket as closed: a
// boss standing on the pocket floor passes every wallIndices filter (vertical, rests on the
// floor) just like a real wall, and its own inner-wire edge was being added to the same sum
// as the outer boundary's. The count-based approach was also capped, separately, by
// `OCCTFaceGetSharedEdges`'s fixed output buffer. Both are fixed by testing membership per
// edge instead of comparing sums: for each edge of the floor's own outer wire, ask which
// faces border it in the shape and check whether one of them is a member of `wallIndices`,
// by structural identity rather than by count. See `Issue753PocketBossWireScopeTests`
// below for the boss fixture, and `AAG.detectPockets()`'s doc comment in
// `FeatureRecognition.swift` for the full reasoning, including the tolerance-filter
// interaction review also raised (measured, did not reproduce).
//
// A bounding-box containment check (is the pocket's own bbox strictly inside the parent
// solid's, in the horizontal axes) was considered and rejected: it is cheaper, but wrong
// for a pocket that legitimately reaches an outer wall of the part while still being fully
// enclosed on every side that matters. Enclosure is a property of the wall loop, not of the
// pocket's position in space.
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

// #753: review of the first version of #735's fix (above) found the enclosure test itself was
// wire-scoped on one side only. `floorBoundaryEdgeCount` counted the floor's OUTER wire, but
// `coveredEdgeCount` summed `AAGEdge.sharedEdgeCount`, a per-face-pair TOTAL, inner wires
// included, over every face in `wallFaceIndices`. A boss standing on the pocket floor passes
// every `wallFaceIndices` filter (vertical, rests on the floor at `floorZ`) exactly like a real
// wall, so its own inner-wire edge was being added to the same sum as the outer boundary's,
// which could push the sum up to (or past) the outer wire's edge count even when a real gap
// remained in the outer loop: #735's own bug re-entering through the wire-scope mismatch.
//
// Fixed by testing membership per edge instead of comparing sums: for each edge of the floor's
// own outer wire, ask which faces border it in the shape (`Edge.adjacentFaces(in:)`) and check
// whether one of them is a member of `wallFaceIndices`, by structural identity
// (`TopoDS_Shape::IsSame`) rather than by count. A boss's wall can never contribute to this test
// at all, since the loop only ever visits the outer wire's own edges.
@Suite("PocketFeature.isOpen is scoped to the outer wire even with a floor boss (#753)")
struct Issue753PocketBossWireScopeTests {

    /// The adjudicated worked example, byte for byte: a rectangular pocket open on one side,
    /// with a cylindrical boss standing on the floor. The boss's wall passes every
    /// `wallFaceIndices` filter and is counted as a wall (`wallFaceIndices.count == 4`, not 3),
    /// but the pocket is still open on the side with no wall at all: the boss must not be able
    /// to mask that gap.
    ///
    /// Measured against the sum-based formula this replaces (temporarily reinstated, then
    /// reverted): with the boss present, `wallFaceIndices.count == 4` and the sum-based
    /// `coveredEdgeCount` reaches the outer wire's 4 edges (3 real walls + the boss's own
    /// inner-wire edge), so it reported `isOpen == false`, enclosed, which is wrong. The
    /// per-edge test in this PR reports `isOpen == true`, correctly, because the boss's wall is
    /// never checked against the outer wire's edges at all.
    @Test("an open pocket with a floor boss is still NOT enclosed")
    func openPocketWithFloorBossIsNotEnclosed() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        // Same slot as Issue735PocketEnclosureTests.openThreeWalledSlotIsNotEnclosed: opens
        // through the box's own x = -10 face, so the floor's fourth boundary edge borders no
        // wall at all.
        let tool = try #require(Shape.box(origin: SIMD3(-15, -3, 0), width: 13, height: 6, depth: 10))
        let cut = try #require(box.subtracting(tool))

        // A boss well inside the slot (x = -6, 4 units from the east wall at x = -2 and 4 units
        // from the open west boundary at x = -10), standing on the floor at z = 0.
        let boss = try #require(Shape.cylinder(at: SIMD3(-6, 0, 0), direction: SIMD3(0, 0, 1), radius: 1, height: 5))
        let bossed = try #require(cut.union(boss))

        let pockets = bossed.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        // The boss's own wall is a genuine member of wallFaceIndices (4, not 3): it must be,
        // for this to be a meaningful test of wire scope rather than of the wall filter.
        #expect(pocket.wallFaceIndices.count == 4)
        #expect(pocket.isOpen)
    }

    /// The other direction: a boss on the floor of an otherwise fully enclosed pocket must not
    /// make the pocket look open either. This is not the bug #753 found (that direction is
    /// already covered above), but it rules out an overcorrection where the fix starts ignoring
    /// real wall coverage whenever any inner wire is present.
    @Test("a fully enclosed pocket with a floor boss is still enclosed")
    func enclosedPocketWithFloorBossIsStillEnclosed() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let cut = try #require(box.subtracting(pocketTool))

        let boss = try #require(Shape.cylinder(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 1, height: 5))
        let bossed = try #require(cut.union(boss))

        let pockets = bossed.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 5)
        #expect(!pocket.isOpen)
    }
}

// #753's fix asks, per outer-wire edge, "which faces border this edge in the shape" via
// `Edge.adjacentFaces(in:)`, and checks BOTH of the two faces it returns against `wallFaceIndices`.
// The floor is always one of the two (trivially not a member of its own walls), and the
// documented contract of `adjacentFaces(in:)` makes no promise about which of its two return
// values that will be. Measured directly (a diagnostic build temporarily printed, per edge,
// which of face1/face2 matched the floor itself, across every fixture in this file): most
// fully-enclosed fixtures happen to return the wall as face1 in this build's BOP output, but an
// off-center pocket in a centered box does not: one of its four boundary edges returns the
// FLOOR as face1 and the wall as face2. That fixture is used here specifically because it is the
// one found, of several tried, where checking face1 alone would silently misjudge a real wall as
// absent.
@Suite("PocketFeature.isOpen does not depend on Edge.adjacentFaces(in:)'s face order (#753)")
struct Issue753EdgeFaceOrderIndependenceTests {
    /// An off-center pocket, fully enclosed by 4 walls. Chosen because at least one of its
    /// floor's boundary edges returns the floor itself as `adjacentFaces(in:)`'s FIRST face and
    /// the real wall as the second, unlike the centered square/triangular/cylindrical fixtures
    /// above, where the wall always comes first. A fix that only checked the first face would
    /// report this specific pocket as open (that edge looks uncovered) even though every
    /// boundary edge genuinely borders a wall.
    @Test("an off-center enclosed pocket is enclosed regardless of which adjacent face comes first")
    func offCenterPocketIsEnclosedRegardlessOfFaceOrder() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.box(origin: SIMD3(-8, -8, 0), width: 6, height: 6, depth: 5))
        let cut = try #require(box.subtracting(tool))

        let pockets = cut.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 4)
        #expect(!pocket.isOpen)
    }
}

// #753 review also raised a compounding failure mode: a wall dropped by the `#724`
// "rests on the floor" tolerance filter (e.g. a filleted floor/wall junction rounding the
// wall's low-Z bound past the floor's own Z) would also drop its edges from the enclosure
// count, permanently misreporting a fully enclosed filleted pocket as open. Measured directly
// at the time (radii 0.5 through 4 on a 10x10x15 pocket, `Sources/OCCTTest/main.swift` scratch
// probe, restored before committing): it did not reproduce, for a more fundamental reason than
// the one hypothesized. A fillet replaces the sharp floor/wall edge with a tangent (`smooth`,
// not `concave`) transition through the fillet face, so the filleted neighbor never appeared in
// `concaveNeighbors(of:)` at all: `wallFaceIndices` came back empty and the floor was skipped
// before the tolerance filter, or the enclosure test, ever ran.
//
// That was a real, measured gap, not a false alarm, and #762 was filed to close it: nearly
// every real machined pocket has a filleted floor/wall junction (an endmill cannot cut a sharp
// internal corner), so a recognizer that only sees sharp pockets has the detection ratio
// backwards for its actual input domain. This suite USED TO pin the negative result as a
// characterization test, specifically so a future change to edge convexity classification that
// started recognizing a filleted junction would not silently reintroduce the
// originally-hypothesized #753 finding-3 failure without a test noticing. #762 IS that future
// change: `AAG.wallsAndJunctions(fromFloor:floorZ:tolerance:)` (`FeatureRecognition.swift`)
// traces concave edges and confirmed-radially-inward-fillet `.smooth` edges outward from the
// floor, absorbing the fillet face, so the junction is now found THROUGH it rather than
// reclassifying `ChFi3d::DefineConnectType`'s own correct `.smooth` verdict at the edge itself.
//
// Per this repo's own instruction for exactly this situation ("that test must invert when you
// fix this"), the negative assertion below is now positive, and this suite is retitled to
// describe what it proves today rather than what it used to pin. See
// `Tests/OCCTModelingTests/Issue762FilletedPocketDetectionTests.swift` for the fuller fixture
// set (several radii, chamfer, partial fillet, and the false-positive guards) this single case
// is now a subset of; kept here, inverted rather than deleted, because it is literally the
// fixture #753 finding 3 and #762 both name.
@Suite("A filleted floor/wall junction IS detected as an enclosed pocket (#753 finding 3 inverted by #762)")
struct Issue753FilletedJunctionDetectedTests {
    @Test("a filleted floor/wall junction pocket IS recognized as an enclosed pocket")
    func filletedJunctionPocketIsDetected() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let cut = try #require(box.subtracting(pocketTool))

        // Confirm the sharp-cornered version is detected and enclosed before filleting it,
        // so the positive result below is "the fillet is now seen through," not "the fixture
        // was never a pocket to begin with."
        let prePockets = cut.detectPocketsAAG()
        #expect(prePockets.count == 1)

        let junctionEdges = cut.edges(where: { abs($0.bounds!.min.z) < 1e-6 && abs($0.bounds!.max.z) < 1e-6 })
        #expect(junctionEdges.count == 4)
        let filleted = try #require(cut.filleted(edges: junctionEdges, radius: 1.0))

        let postPockets = filleted.detectPocketsAAG()
        #expect(postPockets.count == 1)
        guard let pocket = postPockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 4)
        #expect(!pocket.isOpen)
    }
}
