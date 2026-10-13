import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("v0.113.0 - MakeFace Completions")
struct MakeFaceCompletionsTests {

    @Test func faceFromSurfaceUV() throws {
        let sphere = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 5))
        let f = try #require(
            Shape.face(
                from: sphere, uBounds: 0...Double.pi, vBounds: (-Double.pi / 4)...(Double.pi / 4)))
        #expect(f.isValid)
        #expect(f.shapeType == .face)
        // r^2 (u2 - u1)(sin v2 - sin v1) = 25 pi sqrt 2
        #expect(abs((f.surfaceArea ?? 0) - 25 * Double.pi * 2.0.squareRoot()) < 1e-6)
    }

    @Test func faceFromGpPlane() throws {
        let f = try #require(Shape.faceFromPlane(uBounds: (-10)...10, vBounds: (-10)...10))
        #expect(f.isValid)
        #expect(abs((f.surfaceArea ?? 0) - 400) < 1e-6)
        let box = try #require(f.boundingBox)
        #expect(vectorLength(box.min - SIMD3(-10, -10, 0)) < 1e-5)
        #expect(vectorLength(box.max - SIMD3(10, 10, 0)) < 1e-5)
    }

    @Test func faceFromGpCylinder() throws {
        let f = try #require(
            Shape.faceFromCylinder(radius: 5, uBounds: 0...(2 * .pi), vBounds: 0...10))
        #expect(f.isValid)
        // 2 pi r h
        #expect(abs((f.surfaceArea ?? 0) - 100 * Double.pi) < 1e-6)
        let box = try #require(f.boundingBox)
        #expect(vectorLength(box.min - SIMD3(-5, -5, 0)) < 1e-5)
        #expect(vectorLength(box.max - SIMD3(5, 5, 10)) < 1e-5)
    }
}
