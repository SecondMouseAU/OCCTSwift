import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue #39: Wire.fromCurve2D(on:)

@Suite("Wire fromCurve2D on Plane Tests")
struct WireFromCurve2DOnPlaneTests {

    @Test("Segment on XY plane lifts to horizontal 3D wire")
    func segmentOnXYPlane() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let wire = Wire.fromCurve2D(seg)
        #expect(wire != nil)
        if let w = wire {
            // Verify length matches the 2D segment length
            if let len = w.length {
                #expect(abs(len - 10.0) < 0.01)
            }
            // Convert to Shape to validate geometry
            if let shape = Shape.fromWire(w) {
                #expect(shape.isValid)
            }
        }
    }

    @Test("Circle arc on XY plane lifts correctly")
    func arcOnXYPlane() {
        // Quarter-circle arc of radius 5
        let arc = Curve2D.arcOfCircle(
            center: .zero, radius: 5,
            startAngle: 0, endAngle: .pi / 2)!
        let wire = Wire.fromCurve2D(arc)
        #expect(wire != nil)
        if let w = wire {
            if let len = w.length {
                let expected = .pi / 2.0 * 5.0
                #expect(abs(len - expected) < 0.05)
            }
            if let shape = Shape.fromWire(w) {
                #expect(shape.isValid)
            }
        }
    }

    @Test("Segment on XY plane at Z offset")
    func segmentOnXYPlaneAtZ() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let wire = Wire.fromCurve2D(
            seg,
            origin: SIMD3(0, 0, 5),
            normal: SIMD3(0, 0, 1),
            xAxis: SIMD3(1, 0, 0))
        #expect(wire != nil)
        if let w = wire {
            // Z-extent of the bounding box should be near 5
            if let shape = Shape.fromWire(w) {
                let bb = shape.bounds!
                #expect(abs(bb.min.z - 5.0) < 0.01)
                #expect(abs(bb.max.z - 5.0) < 0.01)
            }
        }
    }

    @Test("Segment on YZ plane (normal = X axis)")
    func segmentOnYZPlane() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(5, 0))!
        let wire = Wire.fromCurve2D(
            seg,
            origin: SIMD3(3, 0, 0),
            normal: SIMD3(1, 0, 0),
            xAxis: SIMD3(0, 1, 0))
        #expect(wire != nil)
        if let w = wire {
            // X should stay at 3; Y spans 0–5; Z stays 0
            if let shape = Shape.fromWire(w) {
                let bb = shape.bounds!
                #expect(abs(bb.min.x - 3.0) < 0.01)
                #expect(abs(bb.max.x - 3.0) < 0.01)
                #expect(abs(bb.max.y - 5.0) < 0.01)
            }
        }
    }

    @Test("BSpline interpolated curve lifts to 3D wire")
    func bsplineOnXYPlane() {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(6, 2), SIMD2(10, 5),
        ]
        let curve = Curve2D.interpolate(through: pts)!
        let wire = Wire.fromCurve2D(curve)
        #expect(wire != nil)
        if let w = wire {
            if let shape = Shape.fromWire(w) {
                #expect(shape.isValid)
            }
        }
    }

    @Test("Resulting 3D wire can be used as profile for extrusion")
    func wireAsSweptProfile() {
        // A circle profile lifted onto XY plane then extruded along Z
        let circle2D = Curve2D.circle(center: .zero, radius: 3)!
        if let profile = Wire.fromCurve2D(circle2D) {
            if let shape = Shape.fromWire(profile) {
                #expect(shape.isValid)
            }
            // Use it as profile for an extrusion to verify it is a valid 3D wire
            if let extruded = Shape.extrude(
                profile: profile,
                direction: SIMD3(0, 0, 1),
                length: 10)
            {
                #expect(extruded.isValid)
            }
        }
    }
}
