import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Vector2DMath")
struct Vector2DMathTests {
    @Test func modulus() {
        #expect(abs(Vector2DMath.modulus(SIMD2(3, 4)) - 5.0) < 1e-10)
    }

    @Test func cross() {
        #expect(abs(Vector2DMath.cross(SIMD2(1, 0), SIMD2(0, 1)) - 1.0) < 1e-10)
    }

    @Test func dot() {
        #expect(abs(Vector2DMath.dot(SIMD2(1, 2), SIMD2(3, 4)) - 11.0) < 1e-10)
    }

    @Test func normalize() {
        let n = Vector2DMath.normalize(SIMD2(3, 4))
        #expect(n != nil)
        if let n = n {
            #expect(abs(Vector2DMath.modulus(n) - 1.0) < 1e-10)
            // Probed (Scripts/repro/766-math-trsfmod-uzawa-vector2d): (0.6, 0.8). A unit vector
            // pointing the wrong way also has modulus 1.
            #expect(abs(n.x - 0.6) < 1e-12)
            #expect(abs(n.y - 0.8) < 1e-12)
        }
    }
}

