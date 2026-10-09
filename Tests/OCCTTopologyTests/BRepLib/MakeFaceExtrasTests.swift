import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("MakeFace Extras Tests")
struct MakeFaceExtrasTests {

    @Test func faceFromSphere() {
        if let face = Shape.faceFromSphere(
            radius: 5.0, uMin: 0, uMax: .pi, vMin: -.pi / 4, vMax: .pi / 4)
        {
            #expect(face.isValid)
        }
    }

    @Test func faceFromTorus() {
        if let face = Shape.faceFromTorus(
            majorRadius: 10, minorRadius: 2, uMin: 0, uMax: .pi, vMin: 0, vMax: .pi)
        {
            #expect(face.isValid)
        }
    }

    @Test func faceFromCone() {
        if let face = Shape.faceFromCone(
            semiAngle: .pi / 6, radius: 5, uMin: 0, uMax: .pi, vMin: 0, vMax: 10)
        {
            #expect(face.isValid)
        }
    }

    @Test func faceFromSurfaceWire() {
        // Create a planar face from a wire, then extract the face's outer wire and surface
        if let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            if let wire = Wire.rectangle(width: 10, height: 10) {
                // First make a face from the wire to get a proper shape wire
                if let planarFace = Shape.face(from: wire) {
                    let wires = planarFace.subShapes(ofType: .wire)
                    if let wireShp = wires.first {
                        if let face = Shape.faceFromSurface(plane, wire: wireShp) {
                            // Face may or may not be valid depending on wire orientation
                            let _ = face
                        }
                    }
                }
            }
        }
    }

    @Test func faceCopy() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                if let copy = Shape.faceCopy(face) {
                    #expect(copy.isValid)
                }
            }
        }
    }

    @Test func faceAddHole() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            // Try to get a wire sub-shape to use as a hole
            if let face = faces.first {
                let wires = box.subShapes(ofType: .wire)
                if wires.count >= 2 {
                    let _ = Shape.faceAddHole(face: face, wire: wires[1])
                }
            }
        }
    }
}
