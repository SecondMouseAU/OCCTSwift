import Testing
import Foundation
@testable import OCCTSwift

// #762: a fillet at a pocket's floor/wall junction is tangent to both surfaces
// (`ChFi3d::DefineConnectType` reports `.smooth` at both new edges, by construction, since a
// fillet is G1-continuous with both faces it blends), so `concaveNeighbors(of:)` finds
// nothing and `detectPocketsAAG()` cannot see the pocket at all. A chamfer has the same
// missing-pocket symptom for a different, independently measured reason: both its new edges
// ARE `.concave`, but the chamfer face itself fails the wall's own `isVertical` filter, and
// the pre-fix search never continued past it to the true wall.
//
// Ground-truthed against `ChFi3d::DefineConnectType` directly before writing this fix, in
// `Scripts/repro/762-filleted-pocket-detection/`, across a sharp control, four fillet
// radii, a chamfer, a partially-filleted pocket, a filleted through-slot, a filleted boss,
// and a filleted plain box (the last two are false-positive guards, not detection targets).
//
// Fixed in `AAG.wallsAndJunctions(fromFloor:floorZ:tolerance:)`
// (`Sources/OCCTSwift/FeatureRecognition.swift`): trace concave edges AND `.smooth` edges
// into a confirmed radially-inward fillet outward from the floor, absorbing any junction
// face found along the way, until a genuine vertical wall is reached. See that method's own
// doc comment for the full mechanism and why a chain-discovered wall skips the #724
// Z-tolerance check that a direct concave neighbor still has to pass.

@Suite("A filleted pocket's floor/wall junction is detected through the fillet (#762)")
struct Issue762FilletedPocketDetectionTests {

    /// The issue's own construction, byte for byte: a 10x10x15 pocket in a 20mm cube. Confirms
    /// the sharp version is detected and enclosed. This is the fixture the fillet variants
    /// below are built from, so a negative result there is meaningful only against this
    /// positive control.
    @Test("the sharp pocket (control) is detected and enclosed")
    func sharpPocketIsDetectedAndEnclosed() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let cut = try #require(box.subtracting(pocketTool))

        let pockets = cut.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 4)
        #expect(!pocket.isOpen)
    }

    /// Filleting all four floor/wall junction edges must NOT make the pocket disappear.
    /// Radii 0.5 through 4, matching the range #753 originally measured as "not detected."
    @Test("a filleted floor/wall junction pocket IS detected and enclosed", arguments: [0.5, 1.0, 2.0, 4.0])
    func filletedJunctionPocketIsDetected(radius: Double) throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let cut = try #require(box.subtracting(pocketTool))

        let junctionEdges = cut.edges(where: { abs($0.bounds.min.z) < 1e-6 && abs($0.bounds.max.z) < 1e-6 })
        #expect(junctionEdges.count == 4)
        let filleted = try #require(cut.filleted(edges: junctionEdges, radius: radius))

        let pockets = filleted.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 4)
        #expect(!pocket.isOpen)
        #expect(abs(pocket.zLevel) < 1e-6)
    }
}

@Suite("A chamfered pocket's floor/wall junction is detected through the chamfer (#762)")
struct Issue762ChamferedPocketDetectionTests {

    /// Ground-truthed: a symmetric chamfer's two new edges are both `.concave` (a 270-degree
    /// reentrant corner splits into two 225-degree ones), so `concaveNeighbors(of:)` already
    /// reaches the chamfer directly. The pre-fix miss was the chamfer face's own
    /// `isVertical` filter stopping the search one hop too early, not a missing edge.
    @Test("a chamfered floor/wall junction pocket IS detected and enclosed")
    func chamferedJunctionPocketIsDetected() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let cut = try #require(box.subtracting(pocketTool))

        let allEdges = cut.edges()
        let allFaces = cut.faces()
        var chamferSpecs: [(edgeIndex: Int, faceIndex: Int, dist1: Double, dist2: Double)] = []
        for (i, edge) in allEdges.enumerated() {
            guard abs(edge.bounds.min.z) < 1e-6, abs(edge.bounds.max.z) < 1e-6 else { continue }
            guard let (face1, _) = edge.adjacentFaces(in: cut) else { continue }
            guard let faceIndex = allFaces.firstIndex(where: { abs($0.area() - face1.area()) < 1e-6 }) else { continue }
            chamferSpecs.append((edgeIndex: i, faceIndex: faceIndex, dist1: 1.0, dist2: 1.0))
        }
        #expect(chamferSpecs.count == 4)
        let chamfered = try #require(cut.chamferedTwoDistances(chamferSpecs))

        let pockets = chamfered.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 4)
        #expect(!pocket.isOpen)
    }
}

@Suite("A pocket filleted on only some junctions mixes direct and chained wall discovery (#762)")
struct Issue762PartialFilletDetectionTests {

    /// Two of the four floor/wall edges filleted, two left sharp: the sharp pair must still be
    /// found directly (concave, one hop) and the filleted pair through the chain, in the same
    /// pocket, with all four walls present and the pocket still enclosed.
    @Test("a pocket filleted on only some junctions is still fully detected and enclosed")
    func partiallyFilletedPocketIsDetected() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let cut = try #require(box.subtracting(pocketTool))

        let junctionEdges = cut.edges(where: { abs($0.bounds.min.z) < 1e-6 && abs($0.bounds.max.z) < 1e-6 })
        #expect(junctionEdges.count == 4)
        let filleted = try #require(cut.filleted(edges: Array(junctionEdges.prefix(2)), radius: 1.0))

        let pockets = filleted.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 4)
        #expect(!pocket.isOpen)
    }
}

@Suite("An L-shaped pocket's reflex corner, partially filleted, is still measured correctly (#762)")
struct Issue762ReflexCornerPartialFilletTests {

    /// Built specifically to test a removal-matrix conjunction an earlier review of this fix's
    /// PR raised: a wall reached PAST an already-absorbed junction (where the #724 Z-tolerance
    /// check is deliberately bypassed) via a `.convex` edge, with no other, more direct route
    /// from the floor for an earlier BFS visit to have already resolved. `ChFi3d` was
    /// ground-truthed first (`Scripts/repro/762-filleted-pocket-detection/`, fixture 8): at
    /// the reflex vertex of an L-shaped pocket's own floor boundary, the two walls meeting
    /// there DO share a `.convex` vertical edge (the mirror image of a boss's own corner,
    /// where two base fillets also meet convexly), confirming the hypothesis. Filleting only
    /// one of those two walls (WallY0) makes its fillet meet the other, unfilleted wall
    /// (WallX0) via that same `.convex` edge, past the fillet junction.
    ///
    /// Measured, though, that WallX0 is ALSO directly reachable from the floor: unlike this
    /// fix's other guard fixtures, this is not the floor's own polygon giving it a second
    /// route (WallX0's floor-junction edge is on the OTHER side of the reflex vertex from the
    /// filleted wall), but `BRepFilletAPI_MakeFillet`'s own corner-blending, needed to keep
    /// the result watertight where a fillet ends at an unfilleted reflex corner, reshaping
    /// WallX0's face so the floor borders it directly too. So this fixture, like the
    /// through-slot fixture (masked by the floor's own direct edge to the same exterior wall
    /// the fillet also reaches), does not isolate the `.convex` guard specifically; see the PR
    /// body for the fuller removal-matrix discussion and why every construction tried reduces
    /// to the same kind of masking. Kept as a permanent test regardless: it is a real
    /// correctness check on reflex-corner geometry combined with a partial fillet, a
    /// combination nothing else in this file covers.
    ///
    /// Runs at the DEFAULT tolerance (not a widened one). A second review round found the
    /// earlier version of this test widened `tolerance` to 1e-3 specifically to make WallX0's
    /// own near-boundary low-Z bound clear the check reliably, and that widening was concealing
    /// a real, separate bug (`visited` marked too early, fixed below in
    /// `Issue762DeadEndRevisitableThroughJunctionTests`): at the default tolerance, on the
    /// UNFIXED code, whichever way that near-boundary noise happened to fall was the difference
    /// between "found directly" and "silently dropped forever," not between "found directly"
    /// and "found through the junction instead." With that bug fixed, WallX0 still does not
    /// appear at the default tolerance, but for the reason already established above (the
    /// `.convex` guard, not a numerical coincidence): its only OTHER route is the `.convex`
    /// edge from the fillet, which stays blocked on purpose. `wallCounts` below is `[2, 4]`,
    /// not `[3, 5]`, at the default tolerance for exactly that reason.
    ///
    /// The L-shape's own floor splits into two separate, coplanar faces (matched by the sharp,
    /// unfilleted control below), each reporting its own partial wall loop and `isOpen == true`
    /// since neither alone fully encloses the combined L cavity. That split is pre-existing,
    /// present identically before and after filleting, and not something this fix changes or
    /// needs to change.
    @Test("the sharp L-shaped pocket (control) reports two open, coplanar floor pieces")
    func sharpLShapedPocketReportsTwoOpenFloors() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let toolA = try #require(Shape.box(origin: SIMD3(-6, -6, 0), width: 12, height: 6, depth: 10))
        let toolB = try #require(Shape.box(origin: SIMD3(-6, 0, 0), width: 6, height: 6, depth: 10))
        let toolL = try #require(toolA.union(toolB))
        let cut = try #require(box.subtracting(toolL))

        let pockets = cut.detectPocketsAAG()
        #expect(pockets.count == 2)
        for pocket in pockets {
            #expect(pocket.isOpen)
        }
    }

    @Test("an L-shaped pocket with one reflex-corner wall filleted is still measured, and stays open")
    func filletedReflexCornerPocketIsStillMeasured() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let toolA = try #require(Shape.box(origin: SIMD3(-6, -6, 0), width: 12, height: 6, depth: 10))
        let toolB = try #require(Shape.box(origin: SIMD3(-6, 0, 0), width: 6, height: 6, depth: 10))
        let toolL = try #require(toolA.union(toolB))
        let cut = try #require(box.subtracting(toolL))

        // WallY0: the floor/wall junction edge at y=0, z=0, x in [0,6] (bounds the reflex
        // corner's own material block from below).
        let wallY0Edges = cut.edges(where: { edge in
            abs(edge.bounds.min.z) < 1e-6 && abs(edge.bounds.max.z) < 1e-6 &&
            abs(edge.bounds.min.y) < 1e-6 && abs(edge.bounds.max.y) < 1e-6 &&
            edge.bounds.min.x > -1e-6 && edge.bounds.max.x > 5.9 && edge.bounds.max.x < 6.1
        })
        #expect(wallY0Edges.count == 1)
        let filleted = try #require(cut.filleted(edges: wallY0Edges, radius: 1.0))

        // Default tolerance: see this test's own doc comment for why WallX0 is correctly
        // absent here (the `.convex` guard, not a numerical near-miss).
        let pockets = filleted.detectPocketsAAG()
        #expect(pockets.count == 2)
        let wallCounts = pockets.map { $0.wallFaceIndices.count }.sorted()
        #expect(wallCounts == [2, 4])
        for pocket in pockets {
            #expect(pocket.isOpen)
        }
    }
}

@Suite("A face rejected as a direct dead end stays reachable through its own junction (#762 review)")
struct Issue762DeadEndRevisitableThroughJunctionTests {

    /// Review of this fix found `wallsAndJunctions(fromFloor:floorZ:tolerance:)` marked
    /// `visited` as soon as an edge was crossable, before deciding wall, junction, or dead end.
    /// A face that failed the #724 Z-check as a DIRECT neighbor (`reachedThroughJunction ==
    /// false`) was marked visited regardless, so a SEPARATE edge reaching that same face
    /// through an already-absorbed junction (where the Z-check is bypassed) could never run:
    /// the face was already, wrongly, closed off.
    ///
    /// Ground-truthed rather than assumed (`Sources/OCCTTest/main.swift` scratch diagnostic):
    /// the partial-fillet fixture's two SHARP walls each have their own low-Z bound offset from
    /// the floor's exact Z by about `1.5e-7`, a `BRepFilletAPI_MakeFillet` corner-blending
    /// artifact where each meets the ADJACENT filleted wall's own fillet. That is far below the
    /// default tolerance (`1e-4`), so it is invisible there, but a deliberately smaller
    /// tolerance (`1e-8`, well under the measured offset) reliably fails each sharp wall's
    /// DIRECT concave route from the floor while its OWN fillet's separate, `.concave` (not
    /// `.convex`, so not screened by that unrelated guard) edge to the same wall would accept
    /// it unconditionally once reached through the junction, since #724's Z check does not
    /// apply there.
    ///
    /// Proved by injection: temporarily moving `visited.insert(neighbor)` back to before the
    /// wall/junction/dead-end decision (the original, unfixed placement) and rerunning this
    /// exact fixture at this exact tolerance drops both sharp walls entirely
    /// (`wallFaceIndices.count` 4 to 2, `isOpen` false to true); restoring the fix returns both
    /// walls and the correct enclosed verdict. See the PR body's removal-matrix update for the
    /// full injection record.
    @Test("a sharp wall that fails the direct Z-check is still found through its own fillet's junction")
    func deadEndSharpWallIsStillFoundThroughItsOwnJunction() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let cut = try #require(box.subtracting(pocketTool))

        let junctionEdges = cut.edges(where: { abs($0.bounds.min.z) < 1e-6 && abs($0.bounds.max.z) < 1e-6 })
        #expect(junctionEdges.count == 4)
        let filleted = try #require(cut.filleted(edges: Array(junctionEdges.prefix(2)), radius: 1.0))

        // Deliberately smaller than the sharp walls' own measured ~1.5e-7 natural offset, so
        // their direct route fails while the junction route (unconditional past #724's Z
        // check) still accepts them.
        let pockets = filleted.detectPocketsAAG(tolerance: 1e-8)
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 4)
        #expect(!pocket.isOpen)
    }
}

// MARK: - False-positive guards

// #762 named the risk explicitly: "transitive tangency could sweep in faces that are not
// walls at all." These three suites are the guards against that, each proven to matter by
// actually removing it (see the PR body's removal matrix) rather than by inspection alone.

@Suite("A filleted through-slot stays open, matching its sharp counterpart's own verdict (#762)")
struct Issue762FilletedThroughSlotStaysOpenTests {

    /// The sharp two-walled through-slot (`Issue735PocketEnclosureTests
    /// .twoWalledThroughSlotIsNotEnclosed`'s own fixture): both ends open, `isOpen == true`.
    @Test("the sharp through-slot (control) is not enclosed")
    func sharpThroughSlotIsNotEnclosed() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.box(origin: SIMD3(-15, -3, 0), width: 25, height: 6, depth: 10))
        let cut = try #require(box.subtracting(tool))

        let pockets = cut.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 2)
        #expect(pocket.isOpen)
    }

    /// Filleting the slot's two long floor/wall junctions must not close it: the two walls
    /// are now found through their fillets (0 walls pre-fix, since `concaveNeighbors(of:)`
    /// found nothing at all through a tangent junction), but the two open ends still have no
    /// neighbor whatsoever there (a `.convex` edge to the box's own exterior side wall), so
    /// nothing is absorbed on those sides and the enclosure test still sees the gap.
    @Test("a filleted through-slot is still not enclosed")
    func filletedThroughSlotIsNotEnclosed() throws {
        let box = try #require(Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(Shape.box(origin: SIMD3(-15, -3, 0), width: 25, height: 6, depth: 10))
        let cut = try #require(box.subtracting(tool))

        let longEdges = cut.edges(where: { edge in
            abs(edge.bounds.min.z) < 1e-6 && abs(edge.bounds.max.z) < 1e-6 &&
            (edge.bounds.max.x - edge.bounds.min.x) > 15.0
        })
        #expect(longEdges.count == 2)
        let filleted = try #require(cut.filleted(edges: longEdges, radius: 1.0))

        let pockets = filleted.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.wallFaceIndices.count == 2)
        #expect(pocket.isOpen)
    }
}

@Suite("A filleted boss is not falsely reported as an ENCLOSED pocket (#762)")
struct Issue762FilletedBossFalsePositiveTests {

    /// Ground-truthed (`Scripts/repro/762-filleted-pocket-detection/`): a boss's own base
    /// junction is a reentrant (270-degree material) corner, geometrically identical in kind
    /// to a pocket's own floor/wall corner. Filleting it gives the IDENTICAL
    /// radially-inward signature a pocket's fillet does, so this fix cannot and does not try
    /// to distinguish the two AT the junction. `Issue753PocketBossWireScopeTests` already
    /// established that a floor boss's wall legitimately belongs in `wallFaceIndices`
    /// (sharp, pre-#762): measured directly, a SHARP boss standing alone on a bare plate
    /// already reports `1 pocket, isOpen: true` before this fix. There was never a "0
    /// pockets" baseline to preserve for a boss. The property that actually matters is that a
    /// filleted boss produces the SAME verdict a sharp one does, never a false ENCLOSED
    /// (`isOpen == false`) pocket.
    @Test("the sharp boss (control) reports isOpen == true, not zero pockets")
    func sharpBossReportsOpenNotZero() throws {
        let plate = try #require(Shape.box(origin: SIMD3(-10, -10, -5), width: 20, height: 20, depth: 5))
        let boss = try #require(Shape.box(origin: SIMD3(-3, -3, 0), width: 6, height: 6, depth: 8))
        let fused = try #require(plate.union(boss))

        let pockets = fused.detectPocketsAAG()
        #expect(pockets.count == 1)
        guard let pocket = pockets.first else { return }
        #expect(pocket.isOpen)
    }

    /// The false-positive guard: filleting the boss's base must not turn this into a false
    /// ENCLOSED pocket. It is fine (and consistent with the sharp control) for it to still
    /// appear in the array, as long as it is correctly `isOpen`.
    @Test("a filleted boss reports isOpen == true, matching its sharp counterpart, never falsely enclosed")
    func filletedBossIsNeverFalselyEnclosed() throws {
        let plate = try #require(Shape.box(origin: SIMD3(-10, -10, -5), width: 20, height: 20, depth: 5))
        let boss = try #require(Shape.box(origin: SIMD3(-3, -3, 0), width: 6, height: 6, depth: 8))
        let fused = try #require(plate.union(boss))

        let baseEdges = fused.edges(where: { edge in
            abs(edge.bounds.min.z) < 1e-6 && abs(edge.bounds.max.z) < 1e-6 &&
            edge.bounds.min.x > -3.5 && edge.bounds.max.x < 3.5 &&
            edge.bounds.min.y > -3.5 && edge.bounds.max.y < 3.5
        })
        #expect(baseEdges.count == 4)
        let filletedBoss = try #require(fused.filleted(edges: baseEdges, radius: 1.0))

        let pockets = filletedBoss.detectPocketsAAG()
        // Either the boss's fillet is absorbed and the plate's top is reported as an open
        // "pocket" (matching the sharp control), or it is not reported at all: both are
        // safe. What must never happen is a pocket entry with isOpen == false.
        for pocket in pockets {
            #expect(pocket.isOpen)
        }
    }
}

@Suite("A plain box with its own exterior edges filleted is never reported as any pocket (#762)")
struct Issue762FilletedExternalCornerFalsePositiveTests {

    /// The radial-curvature guard's own reason for existing: a plain box's own top-to-side
    /// edge is genuinely CONVEX (material occupies only 90 degrees there, not a reentrant
    /// 270), so filleting it curves radially OUTWARD, the opposite signature from a pocket's
    /// or a boss's fillet. Without `isRadiallyInwardFillet(_:)` gating which `.smooth` edges
    /// are crossable, this fixture is wrongly reported as an ENCLOSED pocket (proven by
    /// actually removing the guard: see the PR body's removal matrix, injection A).
    @Test("the sharp box (control) has no pockets")
    func sharpBoxHasNoPockets() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        #expect(box.detectPocketsAAG().isEmpty)
    }

    @Test("a box with its own top exterior edges filleted still has no pockets")
    func filletedExteriorEdgeBoxHasNoPockets() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let topEdges = box.edges(where: { abs($0.bounds.min.z - 10) < 1e-6 && abs($0.bounds.max.z - 10) < 1e-6 })
        #expect(topEdges.count == 4)
        let filletedTop = try #require(box.filleted(edges: topEdges, radius: 2.0))

        #expect(filletedTop.detectPocketsAAG().isEmpty)
    }
}
