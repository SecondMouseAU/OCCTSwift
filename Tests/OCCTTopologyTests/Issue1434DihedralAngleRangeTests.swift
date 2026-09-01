import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1434: `OCCTEdgeGetDihedralAngle`'s documented `0...2*PI` range was unreachable: `std::acos`
// always answers in `[0, PI]`, so a convex edge and its complementary concave edge (same two face
// normals, opposite material side) returned the identical value. Worse, and NOT described by the
// original issue text, the raw `acos(dot)` value the function used to return was not even the
// correct interior/material dihedral angle in the convex case either, except by coincidence: a
// box's edges are all the self-symmetric 90-degree case, where `PI - acos(dot) == acos(dot)`, so
// the pre-existing `EdgeAdjacencyTests.boxDihedralAngle` test could not have caught this. This
// suite uses a 60-degree convex wedge and a 200-degree reflex (concave) notch, neither
// self-symmetric, to actually exercise both halves of the fix.
//
// The correct relationship (`trueAngle = PI - normalAngle` for convex, `trueAngle = PI +
// normalAngle` for concave) was independently confirmed against real OCCT geometry, not derived
// by hand alone: see the ground-truth probes referenced in this issue's PR body. That evidence
// also rules out `2*PI - normalAngle` for the concave case, one of the two fix shapes floated
// when the issue was filed: it would report 340 degrees for the 200-degree reflex fixture below,
// not the correct ~200.
@Suite("Edge.dihedralAngle honors its documented 0...2*PI range (#1434)")
struct Issue1434DihedralAngleRangeTests {

    /// Finds the edge of `shape` whose two endpoints both project to (0, *, 0) in XZ: the wedge
    /// apex edge running along Y through the origin.
    private func apexEdge(of shape: Shape) -> Edge? {
        for edge in shape.edges() {
            guard let bounds = edge.parameterBounds,
                let p0 = edge.point(at: bounds.first),
                let p1 = edge.point(at: bounds.last)
            else { continue }
            if abs(p0.x) < 1e-6, abs(p0.z) < 1e-6, abs(p1.x) < 1e-6, abs(p1.z) < 1e-6 {
                return edge
            }
        }
        return nil
    }

    @Test("A 60-degree convex wedge edge reports ~60 degrees, not its 120-degree normal angle")
    func convexWedgeSixtyDegrees() throws {
        // Triangular-prism wedge with a 60-degree apex angle at the origin, opening toward +X,
        // extruded along +Y. The apex edge is a known, independently-computed 60-degree convex
        // dihedral (ground-truth probe: raw acos(dot) = 120.0000 degrees at this fixture).
        let halfAngle = 30.0 * Double.pi / 180.0
        let t = tan(halfAngle)
        let p0 = SIMD3<Double>(0, 0, 0)
        let p1 = SIMD3<Double>(10, 0, 10 * t)
        let p2 = SIMD3<Double>(10, 0, -10 * t)
        guard let wire = Wire.polygon3D([p0, p1, p2], closed: true) else {
            Issue.record("Failed to build wedge wire")
            return
        }
        guard let wedge = Shape.extrude(profile: wire, direction: SIMD3(0, 1, 0), length: 20) else {
            Issue.record("Failed to extrude wedge")
            return
        }
        guard let edge = apexEdge(of: wedge) else {
            Issue.record("Apex edge not found")
            return
        }
        guard let adj = edge.adjacentFaces(in: wedge), adj.count == 2 else {
            Issue.record("Expected exactly 2 adjacent faces at the apex edge")
            return
        }
        guard let angle = edge.dihedralAngle(between: adj[0], and: adj[1]) else {
            Issue.record("dihedralAngle returned nil")
            return
        }
        let angleDegrees = angle * 180.0 / Double.pi
        #expect(angle < Double.pi, "a convex edge should report less than PI, got \(angleDegrees) degrees")
        #expect(abs(angleDegrees - 60.0) < 1.0, "expected ~60 degrees, got \(angleDegrees)")
    }

    @Test("A 200-degree reflex (concave) notch edge reports ~200 degrees, above PI")
    func concaveReflexTwoHundredDegrees() throws {
        // L-shaped notch (extruded hexagonal profile) whose reflex vertex has a known,
        // independently-computed 200-degree interior angle (ground-truth probe: raw acos(dot) =
        // 19.9896 degrees, DefineConnectType = Concave, at this fixture).
        let q0 = SIMD3<Double>(0, 0, 0)
        let q1 = SIMD3<Double>(10, 0, 0)
        let q2 = SIMD3<Double>(10, 0, 10)
        let q3 = SIMD3<Double>(5, 0, 10)
        let v = SIMD3<Double>(5, 0, 5)
        let q4 = SIMD3<Double>(3.2898, 0, 0.2986)  // v + 5*(cos(-110deg), sin(-110deg)) in XZ
        guard let wire = Wire.polygon3D([q0, q1, q2, q3, v, q4], closed: true) else {
            Issue.record("Failed to build notch wire")
            return
        }
        guard let notch = Shape.extrude(profile: wire, direction: SIMD3(0, 1, 0), length: 20) else {
            Issue.record("Failed to extrude notch")
            return
        }

        var reflexEdge: Edge?
        for edge in notch.edges() {
            guard let bounds = edge.parameterBounds,
                let p0 = edge.point(at: bounds.first),
                let p1 = edge.point(at: bounds.last)
            else { continue }
            if abs(p0.x - 5) < 1e-3, abs(p0.z - 5) < 1e-3, abs(p1.x - 5) < 1e-3, abs(p1.z - 5) < 1e-3 {
                reflexEdge = edge
                break
            }
        }
        guard let edge = reflexEdge else {
            Issue.record("Reflex edge not found")
            return
        }
        guard let adj = edge.adjacentFaces(in: notch), adj.count == 2 else {
            Issue.record("Expected exactly 2 adjacent faces at the reflex edge")
            return
        }
        guard let angle = edge.dihedralAngle(between: adj[0], and: adj[1]) else {
            Issue.record("dihedralAngle returned nil")
            return
        }
        let angleDegrees = angle * 180.0 / Double.pi
        #expect(angle > Double.pi, "a concave edge should report greater than PI, got \(angleDegrees) degrees")
        #expect(abs(angleDegrees - 200.0) < 1.0, "expected ~200 degrees, got \(angleDegrees)")
    }
}
