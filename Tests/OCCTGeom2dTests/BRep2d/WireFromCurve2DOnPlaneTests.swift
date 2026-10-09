import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue #39: Wire.fromCurve2D(on:)

// #1979: every test wrapped its checks in `if let`s (a nil wire, length or shape passed) and
// force-unwrapped its fixtures; lengths had 0.01 to 0.05 of slack on values the pcurve-on-plane
// edge reproduces exactly. Fixtures are `#require` now and lengths pinned to 1e-9.
//
// The plane is built as `gp_Ax2(origin, normal, xAxis)`, so the 2D point (u, v) lands at
// `origin + u * xAxis + v * (normal x xAxis)`. A segment along u alone cannot tell the normal from
// any other direction perpendicular to the x axis, so `liftFollowsTheNormalAndTheXAxis` lifts one
// with both components onto three planes: `v` along +z, along -z once the normal is flipped, and
// along -z again on a plane through an oblique origin.
@Suite("Wire fromCurve2D on Plane Tests")
struct WireFromCurve2DOnPlaneTests {

    /// A wire's own start and end, which a box and a length cannot tell apart from each other.
    private func ends(_ w: Wire) throws -> (start: SIMD3<Double>, end: SIMD3<Double>) {
        let info = try #require(w.curveInfo)
        return (info.startPoint, info.endPoint)
    }

    @Test("Segment on XY plane lifts to horizontal 3D wire")
    func segmentOnXYPlane() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let w = try #require(Wire.fromCurve2D(seg))
        #expect(abs((w.length ?? 0) - 10.0) < 1e-9)
        let e = try ends(w)
        #expect(simd_distance(e.start, SIMD3(0, 0, 0)) < 1e-9)
        #expect(simd_distance(e.end, SIMD3(10, 0, 0)) < 1e-9)
        let shape = try #require(Shape.fromWire(w))
        #expect(shape.isValid)
    }

    @Test("Circle arc on XY plane lifts correctly")
    func arcOnXYPlane() throws {
        // Quarter-circle arc of radius 5
        let arc = try #require(
            Curve2D.arcOfCircle(
                center: .zero, radius: 5,
                startAngle: 0, endAngle: .pi / 2))
        let w = try #require(Wire.fromCurve2D(arc))
        #expect(abs((w.length ?? 0) - .pi / 2.0 * 5.0) < 1e-9)
        let e = try ends(w)
        #expect(simd_distance(e.start, SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_distance(e.end, SIMD3(0, 5, 0)) < 1e-9)
        let shape = try #require(Shape.fromWire(w))
        #expect(shape.isValid)
    }

    @Test("Segment on XY plane at Z offset")
    func segmentOnXYPlaneAtZ() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let w = try #require(
            Wire.fromCurve2D(
                seg,
                origin: SIMD3(0, 0, 5),
                normal: SIMD3(0, 0, 1),
                xAxis: SIMD3(1, 0, 0)))
        let e = try ends(w)
        #expect(simd_distance(e.start, SIMD3(0, 0, 5)) < 1e-9)
        #expect(simd_distance(e.end, SIMD3(10, 0, 5)) < 1e-9)
        // The box of an edge carries the edge's 1e-7 tolerance, so 1e-6 is what it can pin.
        let shape = try #require(Shape.fromWire(w))
        let bb = try #require(shape.bounds)
        #expect(abs(bb.min.z - 5.0) < 1e-6)
        #expect(abs(bb.max.z - 5.0) < 1e-6)
        #expect(abs(bb.min.x) < 1e-6)
        #expect(abs(bb.max.x - 10.0) < 1e-6)
    }

    @Test("Segment on YZ plane (normal = X axis)")
    func segmentOnYZPlane() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(5, 0)))
        let w = try #require(
            Wire.fromCurve2D(
                seg,
                origin: SIMD3(3, 0, 0),
                normal: SIMD3(1, 0, 0),
                xAxis: SIMD3(0, 1, 0)))
        // X should stay at 3; Y spans 0-5; Z stays 0
        let e = try ends(w)
        #expect(simd_distance(e.start, SIMD3(3, 0, 0)) < 1e-9)
        #expect(simd_distance(e.end, SIMD3(3, 5, 0)) < 1e-9)
        let shape = try #require(Shape.fromWire(w))
        let bb = try #require(shape.bounds)
        #expect(abs(bb.min.x - 3.0) < 1e-6)
        #expect(abs(bb.max.x - 3.0) < 1e-6)
        #expect(abs(bb.min.y) < 1e-6)
        #expect(abs(bb.max.y - 5.0) < 1e-6)
        #expect(abs(bb.min.z) < 1e-6)
        #expect(abs(bb.max.z) < 1e-6)
    }

    @Test("A 2D segment with both components follows the normal and the x axis")
    func liftFollowsTheNormalAndTheXAxis() throws {
        // (0, 0) to (3, 4), length 5, so the lift must keep the length and put the end at
        // origin + 3 * xAxis + 4 * (normal x xAxis).
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(3, 4)))

        // Normal +x, x axis +y: normal x xAxis = (1, 0, 0) x (0, 1, 0) = (0, 0, 1), so v is +z.
        let up = try #require(
            Wire.fromCurve2D(
                seg, origin: SIMD3(3, 0, 0), normal: SIMD3(1, 0, 0), xAxis: SIMD3(0, 1, 0)))
        #expect(abs((up.length ?? 0) - 5) < 1e-9)
        let upEnds = try ends(up)
        #expect(simd_distance(upEnds.start, SIMD3(3, 0, 0)) < 1e-9)
        #expect(simd_distance(upEnds.end, SIMD3(3, 3, 4)) < 1e-9)

        // The same plane seen from the other side: normal -x gives (-1, 0, 0) x (0, 1, 0) =
        // (0, 0, -1), so v is -z and the end is (3, 3, -4). A lift that ignored the normal's
        // sign would put both at +4.
        let down = try #require(
            Wire.fromCurve2D(
                seg, origin: SIMD3(3, 0, 0), normal: SIMD3(-1, 0, 0), xAxis: SIMD3(0, 1, 0)))
        let downEnd = try ends(down).end
        #expect(simd_distance(downEnd, SIMD3(3, 3, -4)) < 1e-9)

        // An oblique origin on the xz plane: normal +y, x axis +x gives (0, 1, 0) x (1, 0, 0) =
        // (0, 0, -1), so the end is (1, 2, 3) + 3 * (1, 0, 0) + 4 * (0, 0, -1) = (4, 2, -1).
        let oblique = try #require(
            Wire.fromCurve2D(
                seg, origin: SIMD3(1, 2, 3), normal: SIMD3(0, 1, 0), xAxis: SIMD3(1, 0, 0)))
        let obliqueEnds = try ends(oblique)
        #expect(simd_distance(obliqueEnds.start, SIMD3(1, 2, 3)) < 1e-9)
        #expect(simd_distance(obliqueEnds.end, SIMD3(4, 2, -1)) < 1e-9)
    }

    @Test("BSpline interpolated curve lifts to 3D wire")
    func bsplineOnXYPlane() throws {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(6, 2), SIMD2(10, 5),
        ]
        let curve = try #require(Curve2D.interpolate(through: pts))
        let w = try #require(Wire.fromCurve2D(curve))
        let shape = try #require(Shape.fromWire(w))
        #expect(shape.isValid)
        // #1979: lifted onto the XY plane the wire keeps the 2D curve's length (15.5494532204).
        let expected = try #require(curve.length)
        #expect(abs((w.length ?? 0) - expected) < 1e-9)
        // The interpolant passes through its first and last point, and so does the lift.
        let e = try ends(w)
        #expect(simd_distance(e.start, SIMD3(0, 0, 0)) < 1e-9)
        #expect(simd_distance(e.end, SIMD3(10, 5, 0)) < 1e-9)
    }

    @Test("Resulting 3D wire can be used as profile for extrusion")
    func wireAsSweptProfile() throws {
        // A circle profile lifted onto XY plane then extruded along Z
        let circle2D = try #require(Curve2D.circle(center: .zero, radius: 3))
        let profile = try #require(Wire.fromCurve2D(circle2D))
        #expect(abs((profile.length ?? 0) - 6 * .pi) < 1e-9)
        let shape = try #require(Shape.fromWire(profile))
        #expect(shape.isValid)
        // Use it as profile for an extrusion to verify it is a valid 3D wire
        let extruded = try #require(
            Shape.extrude(
                profile: profile,
                direction: SIMD3(0, 0, 1),
                length: 10))
        #expect(extruded.isValid)
        // #1979: a closed cylinder of r = 3, h = 10: 2 pi r h + 2 pi r^2 = 78 pi.
        #expect(abs((extruded.surfaceArea ?? 0) - 78 * .pi) < 1e-6)
        // And a solid, not an open wall: pi r^2 h = 90 pi.
        #expect(abs((extruded.volume ?? 0) - 90 * .pi) < 1e-6)
    }
}
