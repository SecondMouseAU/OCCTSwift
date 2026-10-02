import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `BRepLProp_CLProps` on an edge, pinned to closed forms rather than to bounds.
///
/// Two fixtures, both with an exact answer at every point:
///
/// * `Shape.box(width: 10, height: 10, depth: 10)` is centred, so it spans `-5...5` and its first
///   edge is the straight line `x = -5, y = -5` running up Z over the parameter range `[0, 10]`.
///   The curve is parametrised by arc length, so the point at parameter `t` is `(-5, -5, -5 + t)`,
///   the unit tangent and the first derivative are both `(0, 0, 1)`, and the curvature is 0.
/// * `Shape.cylinder(radius: 5, height: 10)`'s first edge is the top circle, `[0, 2 pi]` in the
///   plane `z = 10`. At parameter `t` the point is `(5 cos t, 5 sin t, 10)`, the unit tangent is
///   `(-sin t, cos t, 0)`, the first derivative is `5 (-sin t, cos t, 0)` and the curvature is
///   `1/5`.
///
/// The second fixture is what makes three of these tests able to fail. A straight edge cannot
/// tell a unit tangent from a first derivative (both `(0, 0, 1)`), nor a real zero curvature from
/// a bridge that always answers zero; on the circle the tangent has length 1 and the derivative
/// length 5, and the curvature is 0.2.
///
/// `edgeCurvatureLP` is **unsigned**: it is `BRepLProp_CLProps::Curvature()`, which is
/// `|C' x C''| / |C'|^3`. #1437's signed-curvature trap is about `MinCurvature`/`MaxCurvature`
/// on a *surface* and does not reach here, so `0.2` rather than `+/-0.2` is the right pin.
///
/// Before #766 every test nested its assertions inside `if let box`, `if edges.count > 0` and
/// `if let p`, so a bridge returning `nil` for every edge passed three of the four, and the
/// assertions that did run (`dist > 0`, `len > 0`) accepted almost any point or vector. Every
/// unwrap here is `try #require`, so an absent fixture or a nil answer fails the test rather than
/// skipping it.
/// Measured by `Scripts/repro/766-breplprop-edge/probe.mm` (transcript alongside it).
@Suite("BRepLProp Edge v0.111")
struct BRepLPropEdgeTests {

    private func firstEdge(of shape: Shape?) -> Shape? {
        shape?.subShapes(ofType: .edge).first
    }

    private func boxEdge() -> Shape? {
        firstEdge(of: Shape.box(width: 10, height: 10, depth: 10))
    }

    private func circleEdge() -> Shape? {
        firstEdge(of: Shape.cylinder(radius: 5, height: 10))
    }

    /// #1786: `#expect(dist > 0.0)` on the distance from the origin accepted every point on the
    /// box except the eight that are exactly at the origin, of which there are none.
    @Test func edgeValue() throws {
        let line = try #require(boxEdge(), "the box's first edge")
        let circle = try #require(circleEdge(), "the cylinder's first edge")

        // Arc-length parametrised from z = -5, so t = 0.5 is z = -4.5.
        let p = try #require(line.edgeLPropValue(at: 0.5), "a line evaluates at parameter 0.5")
        #expect(abs(p.x - (-5)) < 1e-12, "x: expected -5, got \(p.x)")
        #expect(abs(p.y - (-5)) < 1e-12, "y: expected -5, got \(p.y)")
        #expect(abs(p.z - (-4.5)) < 1e-12, "z: expected -4.5, got \(p.z)")

        // (5 cos 0.5, 5 sin 0.5, 10): a point no straight-line fixture could distinguish.
        let c = try #require(circle.edgeLPropValue(at: 0.5), "a circle evaluates at parameter 0.5")
        #expect(abs(c.x - 5 * cos(0.5)) < 1e-12, "x: expected \(5 * cos(0.5)), got \(c.x)")
        #expect(abs(c.y - 5 * sin(0.5)) < 1e-12, "y: expected \(5 * sin(0.5)), got \(c.y)")
        #expect(abs(c.z - 10) < 1e-12, "z: expected 10, got \(c.z)")
    }

    /// #1787: `abs(len - 1.0) < 1e-4` on the first edge that answered at all pinned only that the
    /// result is a unit vector, which every direction OCCT can return already is, and the `break`
    /// meant a bridge that answered for no edge asserted nothing.
    @Test func edgeTangent() throws {
        let line = try #require(boxEdge(), "the box's first edge")
        let circle = try #require(circleEdge(), "the cylinder's first edge")

        // The edge runs up Z, so the unit tangent is +Z, not just any unit vector.
        let tan = try #require(line.edgeTangent(at: 0.5), "a line has a tangent")
        #expect(abs(tan.x) < 1e-12, "x: expected 0, got \(tan.x)")
        #expect(abs(tan.y) < 1e-12, "y: expected 0, got \(tan.y)")
        #expect(abs(tan.z - 1) < 1e-12, "z: expected 1, got \(tan.z)")

        // (-sin t, cos t, 0): unit length, where the first derivative at the same point has
        // length 5. Returning D1 here instead of the tangent would pass on the box and fail here.
        let ct = try #require(circle.edgeTangent(at: 0.5), "a circle has a tangent")
        #expect(abs(ct.x - (-sin(0.5))) < 1e-12, "x: expected \(-sin(0.5)), got \(ct.x)")
        #expect(abs(ct.y - cos(0.5)) < 1e-12, "y: expected \(cos(0.5)), got \(ct.y)")
        #expect(abs(ct.z) < 1e-12, "z: expected 0, got \(ct.z)")
    }

    /// #1788: `abs(k) < 1e-4` on a straight edge is satisfied by a bridge that always answers 0,
    /// which is the one failure mode a curvature wrapper has.
    @Test func edgeCurvature() throws {
        let line = try #require(boxEdge(), "the box's first edge")
        let circle = try #require(circleEdge(), "the cylinder's first edge")

        // Edges of a box are straight lines, curvature 0.
        let straight = try #require(
            line.edgeCurvatureLP(at: 0.5), "a box edge has curvature 0, not an undefined one")
        #expect(abs(straight) < 1e-12, "a straight edge has curvature 0, got \(straight)")

        // The radius-5 circle has curvature 1/5 everywhere, and unsigned.
        let round = try #require(
            circle.edgeCurvatureLP(at: 0.5), "a circle's curvature is defined")
        #expect(abs(round - 0.2) < 1e-12, "a radius-5 circle has curvature 0.2, got \(round)")
    }

    /// #1789: `len > 0.0` on the first derivative accepted any non-degenerate vector, including
    /// the unit tangent, which is what `edgeLPropD1` must *not* return.
    @Test func edgeD1() throws {
        let line = try #require(boxEdge(), "the box's first edge")
        let circle = try #require(circleEdge(), "the cylinder's first edge")

        // The box edge is parametrised by arc length, so D1 is the unit +Z.
        let d1 = try #require(line.edgeLPropD1(at: 0.5), "a line has a first derivative")
        #expect(abs(d1.x) < 1e-12 && abs(d1.y) < 1e-12, "expected (0, 0, 1), got \(d1)")
        #expect(abs(d1.z - 1) < 1e-12, "expected (0, 0, 1), got \(d1)")

        // On the circle D1 = r (-sin t, cos t, 0) at t = 0.5: length 5, which is what separates
        // it from the unit tangent the test above pins.
        let c1 = try #require(circle.edgeLPropD1(at: 0.5), "a circle has a first derivative")
        #expect(abs(c1.x - (-5 * sin(0.5))) < 1e-12, "x: expected \(-5 * sin(0.5)), got \(c1.x)")
        #expect(abs(c1.y - 5 * cos(0.5)) < 1e-12, "y: expected \(5 * cos(0.5)), got \(c1.y)")
        #expect(abs(c1.z) < 1e-12, "z: expected 0, got \(c1.z)")
        #expect(abs(simd_length(c1) - 5) < 1e-12, "expected length 5, got \(simd_length(c1))")
    }
}
