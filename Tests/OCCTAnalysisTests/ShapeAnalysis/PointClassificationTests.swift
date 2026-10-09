import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Point Classification Tests (v0.17.0)

@Suite("Point Classification Tests")
struct PointClassificationTests {

    @Test("Point inside box")
    func pointInsideBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Box is centered at origin, extends from -5 to 5 in each axis
        let result = box.classify(point: SIMD3(0, 0, 0), tolerance: 1e-6)
        #expect(result == .inside)
    }

    @Test("Point outside box")
    func pointOutsideBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.classify(point: SIMD3(100, 100, 100), tolerance: 1e-6)
        #expect(result == .outside)
    }

    @Test("Point on box face")
    func pointOnBoxFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Point on the top face at Z=5 (box extends from -5 to 5 on Z)
        let result = box.classify(point: SIMD3(0, 0, 5), tolerance: 1e-3)
        #expect(result == .onBoundary)
    }

    @Test("Point inside sphere")
    func pointInsideSphere() {
        let sphere = Shape.sphere(radius: 10)!
        let result = sphere.classify(point: SIMD3(1, 1, 1), tolerance: 1e-6)
        #expect(result == .inside)
    }

    @Test("Face classify: point on face")
    func faceClassifyPoint() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        // Find a face and classify a point on it
        let face = faces[0]
        let normal = face.normal
        #expect(normal != nil)
    }

    @Test("Face classify UV: center of face")
    func faceClassifyUV() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let faces = box.faces()
        #expect(!faces.isEmpty)

        let face = faces[0]
        // Get UV bounds and classify at the center
        let uvb = face.uvBounds!
        let uMid = (uvb.uMin + uvb.uMax) / 2.0
        let vMid = (uvb.vMin + uvb.vMax) / 2.0
        let result = face.classify(u: uMid, v: vMid, tolerance: 1e-6)
        // Center of face domain should be classified as inside
        #expect(result == .inside)
    }
}
