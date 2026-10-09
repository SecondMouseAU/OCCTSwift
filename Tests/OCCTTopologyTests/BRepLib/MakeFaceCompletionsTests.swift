import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - MakeFace Completions")
struct MakeFaceCompletionsTests {

    @Test func faceFromSurfaceUV() {
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5) {
            let face = Shape.face(
                from: sphere, uBounds: 0...Double.pi, vBounds: (-Double.pi / 4)...(Double.pi / 4))
            #expect(face != nil)
            if let f = face {
                #expect(f.isValid)
            }
        }
    }

    @Test func faceFromGpPlane() {
        let face = Shape.faceFromPlane(uBounds: (-10)...10, vBounds: (-10)...10)
        #expect(face != nil)
        if let f = face {
            #expect(f.isValid)
        }
    }

    @Test func faceFromGpCylinder() {
        let face = Shape.faceFromCylinder(radius: 5, uBounds: 0...(2 * .pi), vBounds: 0...10)
        #expect(face != nil)
        if let f = face {
            #expect(f.isValid)
        }
    }
}
