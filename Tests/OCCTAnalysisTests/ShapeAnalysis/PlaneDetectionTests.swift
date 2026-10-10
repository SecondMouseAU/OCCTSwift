import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.41.0: Plane Detection

// Values probed on the pinned kernel: Scripts/repro/766-plane-detection/transcript.txt.
// BRepBuilderAPI_FindPlane reports the rectangle's plane as normal (0, 0, -1) through (-5, -5, 0);
// the assertions below read the normal up to sign, which is FindPlane's choice rather than
// anything the tests set out to pin, and the origin only by its height, since any point of the
// plane is a valid location.
@Suite("Plane Detection")
struct PlaneDetectionTests {
    @Test("Planar wire finds plane")
    func planarWire() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
            let wireShape = Shape.fromWire(wire)
        else {
            Issue.record("could not build the 10x10 rectangle wire shape")
            return
        }
        guard let plane = wireShape.findPlane() else {
            Issue.record("findPlane returned nil for a rectangle in z = 0")
            return
        }
        // Rectangle in the XY plane: the normal is along Z and the plane passes through z = 0.
        #expect(abs(abs(plane.normal.z) - 1.0) < 1e-12, "got \(plane.normal)")
        #expect(abs(plane.normal.x) < 1e-12)
        #expect(abs(plane.normal.y) < 1e-12)
        #expect(abs(plane.origin.z) < 1e-12, "got \(plane.origin)")
    }

    @Test("Non-planar 3D wire returns nil")
    func nonPlanarWire() {
        // Build a 3D wire with points not in a single plane
        guard let e1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)),
            let e2 = Wire.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 5)),
            let e3 = Wire.line(from: SIMD3(10, 10, 5), to: SIMD3(0, 10, 10)),
            let e4 = Wire.line(from: SIMD3(0, 10, 10), to: SIMD3(0, 0, 0))
        else {
            Issue.record("Wire.line returned nil for a non-degenerate segment")
            return
        }
        guard let joined = Wire.join([e1, e2, e3, e4]),
            let wireShape = Shape.fromWire(joined)
        else {
            Issue.record("could not join the four segments into a closed wire")
            return
        }
        #expect(wireShape.findPlane() == nil)
    }

    @Test("Face shape is planar")
    func faceShapePlanar() {
        // Create a face from a rectangle wire, the face shape should be planar
        guard let rect = Wire.rectangle(width: 10, height: 10),
            let face = Shape.face(from: rect)
        else {
            Issue.record("could not build a face from the 10x10 rectangle")
            return
        }
        guard let plane = face.findPlane() else {
            Issue.record("findPlane returned nil for a planar face")
            return
        }
        #expect(abs(abs(plane.normal.z) - 1.0) < 1e-12, "got \(plane.normal)")
        #expect(abs(plane.origin.z) < 1e-12, "got \(plane.origin)")
    }
}
