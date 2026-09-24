import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Expected values are the pinned kernel's answers for the same edges and parameter, measured by
/// `Scripts/repro/766-breplprop-edge/probe.mm` (transcript alongside it).
///
/// `Shape.box` is centred, so the 10-unit box spans -5...5 and its first edge is the line
/// x = -5, y = -5 running up Z with parameter range [0, 10]: parameter 0.5 is (-5, -5, -4.5).
/// A straight edge cannot tell a tangent from a first derivative, or zero curvature from a
/// bridge that always reports zero, so the curvature and D1 tests also read the first edge of
/// `Shape.cylinder(radius: 5, height: 10)`, the top circle, where both differ.
///
/// Before #766 every test here nested its assertions inside `if let box`, `if edges.count > 0`
/// and `if let p`, so a bridge returning `nil` for every edge passed three of the four, and the
/// assertions that did run (`dist > 0`, `len > 0`) accepted almost any point or vector.
@Suite("BRepLProp Edge v0.111")
struct BRepLPropEdgeTests {

    private func firstEdge(of shape: Shape?) -> Shape? {
        shape?.subShapes(ofType: .edge).first
    }

    @Test func edgeValue() {
        guard let edge = firstEdge(of: Shape.box(width: 10, height: 10, depth: 10)) else {
            Issue.record("could not read the box's first edge")
            return
        }
        guard let p = edge.edgeLPropValue(at: 0.5) else {
            Issue.record("a line evaluates at parameter 0.5")
            return
        }
        #expect(abs(p.x - (-5)) < 1e-12, "x: expected -5, got \(p.x)")
        #expect(abs(p.y - (-5)) < 1e-12, "y: expected -5, got \(p.y)")
        #expect(abs(p.z - (-4.5)) < 1e-12, "z: expected -4.5, got \(p.z)")
    }

    @Test func edgeTangent() {
        guard let edge = firstEdge(of: Shape.box(width: 10, height: 10, depth: 10)) else {
            Issue.record("could not read the box's first edge")
            return
        }
        guard let tan = edge.edgeTangent(at: 0.5) else {
            Issue.record("a line has a tangent")
            return
        }
        // The edge runs up Z, so the unit tangent is +Z, not just any unit vector.
        #expect(abs(tan.x) < 1e-12, "x: expected 0, got \(tan.x)")
        #expect(abs(tan.y) < 1e-12, "y: expected 0, got \(tan.y)")
        #expect(abs(tan.z - 1) < 1e-12, "z: expected 1, got \(tan.z)")
    }

    @Test func edgeCurvature() {
        guard let line = firstEdge(of: Shape.box(width: 10, height: 10, depth: 10)),
            let circle = firstEdge(of: Shape.cylinder(radius: 5, height: 10))
        else {
            Issue.record("could not read the box's or the cylinder's first edge")
            return
        }
        // Edges of a box are straight lines, curvature 0.
        if let k = line.edgeCurvatureLP(at: 0.5) {
            #expect(abs(k) < 1e-12, "a straight edge has curvature 0, got \(k)")
        } else {
            Issue.record("a box edge has curvature 0, not an undefined one")
        }
        // The radius-5 circle has curvature 1/5 everywhere (probed: 0.20000000000000001).
        if let k = circle.edgeCurvatureLP(at: 0.5) {
            #expect(abs(k - 0.2) < 1e-12, "a radius-5 circle has curvature 0.2, got \(k)")
        } else {
            Issue.record("a circle's curvature is defined")
        }
    }

    @Test func edgeD1() {
        guard let line = firstEdge(of: Shape.box(width: 10, height: 10, depth: 10)),
            let circle = firstEdge(of: Shape.cylinder(radius: 5, height: 10))
        else {
            Issue.record("could not read the box's or the cylinder's first edge")
            return
        }
        guard let d1 = line.edgeLPropD1(at: 0.5) else {
            Issue.record("a line has a first derivative")
            return
        }
        // The box edge is parametrised by arc length, so D1 is the unit +Z.
        #expect(abs(d1.x) < 1e-12 && abs(d1.y) < 1e-12, "expected (0, 0, 1), got \(d1)")
        #expect(abs(d1.z - 1) < 1e-12, "expected (0, 0, 1), got \(d1)")

        guard let c1 = circle.edgeLPropD1(at: 0.5) else {
            Issue.record("a circle has a first derivative")
            return
        }
        // On the circle D1 = r * (-sin t, cos t, 0) at t = 0.5: length 5, which is what
        // separates it from the unit tangent.
        #expect(abs(c1.x - (-5 * sin(0.5))) < 1e-12, "x: expected \(-5 * sin(0.5)), got \(c1.x)")
        #expect(abs(c1.y - 5 * cos(0.5)) < 1e-12, "y: expected \(5 * cos(0.5)), got \(c1.y)")
        #expect(abs(c1.z) < 1e-12, "z: expected 0, got \(c1.z)")
    }
}
