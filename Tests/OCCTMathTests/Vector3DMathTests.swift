import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Vector3DMath")
struct Vector3DMathTests {
    @Test func modulus() {
        #expect(abs(Vector3DMath.modulus(SIMD3(1, 2, 2)) - 3.0) < 1e-10)
    }

    @Test func cross() {
        let c = Vector3DMath.cross(SIMD3(1, 0, 0), SIMD3(0, 1, 0))
        #expect(abs(c.z - 1.0) < 1e-10)
    }

    @Test func dot() {
        #expect(abs(Vector3DMath.dot(SIMD3(1, 2, 3), SIMD3(4, 5, 6)) - 32.0) < 1e-10)
    }

    @Test func dotCross() {
        #expect(
            abs(Vector3DMath.dotCross(SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)) - 1.0) < 1e-10
        )
    }

    @Test func normalize() {
        let n = Vector3DMath.normalize(SIMD3(1, 2, 2))
        #expect(n != nil)
        if let n = n {
            #expect(abs(Vector3DMath.modulus(n) - 1.0) < 1e-10)
            // Probed (Scripts/repro/766-math-vector3d): (1/3, 2/3, 2/3). A unit vector pointing
            // the wrong way also has modulus 1.
            #expect(abs(n.x - 1.0 / 3.0) < 1e-12)
            #expect(abs(n.y - 2.0 / 3.0) < 1e-12)
            #expect(abs(n.z - 2.0 / 3.0) < 1e-12)
        }
    }
}

