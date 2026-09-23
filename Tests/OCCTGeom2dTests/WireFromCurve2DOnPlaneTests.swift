import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue #39: Wire.fromCurve2D(on:)

// #1979: every test wrapped its checks in `if let`s (a nil wire, length or shape passed) and
// force-unwrapped its fixtures; lengths had 0.01 to 0.05 of slack on values the pcurve-on-plane
// edge reproduces exactly. Fixtures are `#require` now and lengths pinned to 1e-9.
@Suite("Wire fromCurve2D on Plane Tests")
struct WireFromCurve2DOnPlaneTests {

    @Test("Segment on XY plane lifts to horizontal 3D wire")
    func segmentOnXYPlane() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let w = try #require(Wire.fromCurve2D(seg))
        #expect(abs((w.length ?? 0) - 10.0) < 1e-9)
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
        // Z-extent of the bounding box should be near 5
        let shape = try #require(Shape.fromWire(w))
        let bb = try #require(shape.bounds)
        #expect(abs(bb.min.z - 5.0) < 0.01)
        #expect(abs(bb.max.z - 5.0) < 0.01)
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
        let shape = try #require(Shape.fromWire(w))
        let bb = try #require(shape.bounds)
        #expect(abs(bb.min.x - 3.0) < 0.01)
        #expect(abs(bb.max.x - 3.0) < 0.01)
        #expect(abs(bb.max.y - 5.0) < 0.01)
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
    }

    @Test("Resulting 3D wire can be used as profile for extrusion")
    func wireAsSweptProfile() throws {
        // A circle profile lifted onto XY plane then extruded along Z
        let circle2D = try #require(Curve2D.circle(center: .zero, radius: 3))
        let profile = try #require(Wire.fromCurve2D(circle2D))
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
    }
}
