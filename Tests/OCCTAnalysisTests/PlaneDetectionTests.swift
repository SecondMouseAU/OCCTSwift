import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.41.0: Plane Detection

@Suite("Plane Detection")
struct PlaneDetectionTests {
    @Test("Planar wire finds plane")
    func planarWire() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let wireShape = Shape.fromWire(wire)!
        let plane = wireShape.findPlane()
        #expect(plane != nil)
        if let plane {
            // Rectangle in XY plane, normal should be along Z
            #expect(abs(abs(plane.normal.z) - 1.0) < 0.01)
        }
    }

    @Test("Non-planar 3D wire returns nil")
    func nonPlanarWire() {
        // Build a 3D wire with points not in a single plane
        let e1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let e2 = Wire.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 5))!
        let e3 = Wire.line(from: SIMD3(10, 10, 5), to: SIMD3(0, 10, 10))!
        let e4 = Wire.line(from: SIMD3(0, 10, 10), to: SIMD3(0, 0, 0))!
        let joined = Wire.join([e1, e2, e3, e4])
        #expect(joined != nil)
        if let joined {
            let wireShape = Shape.fromWire(joined)!
            let plane = wireShape.findPlane()
            #expect(plane == nil)
        }
    }

    @Test("Face shape is planar")
    func faceShapePlanar() {
        // Create a face from a rectangle wire, the face shape should be planar
        let face = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let plane = face.findPlane()
        #expect(plane != nil)
    }
}
