import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Quaternion Tests")
struct QuaternionTests {

    @Test func identity() {
        let q = Quaternion()
        let c = q.components
        #expect(abs(c.w - 1.0) < 1e-10)
        #expect(abs(c.x) < 1e-10)
    }

    @Test func fromAxisAngle() {
        let q = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 2)
        let rotated = q.rotate(SIMD3(1, 0, 0))
        #expect(abs(rotated.x) < 1e-10)
        #expect(abs(rotated.y - 1.0) < 1e-10)
    }

    @Test func fromVectors() {
        let q = Quaternion.fromVectors(from: SIMD3(1, 0, 0), to: SIMD3(0, 1, 0))
        let rotated = q.rotate(SIMD3(1, 0, 0))
        #expect(abs(rotated.y - 1.0) < 1e-10)
    }

    @Test func eulerAngles() {
        let q = Quaternion()
        // gp_Intrinsic_XYZ = 8 in gp_EulerSequence enum
        q.setEulerAngles(order: 8, alpha: .pi / 4, beta: 0, gamma: 0)
        let euler = q.getEulerAngles(order: 8)
        #expect(abs(euler.alpha - .pi / 4) < 1e-10)
    }

    @Test func matrix() {
        let q = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 2)
        let m = q.matrix
        #expect(m.count == 9)
    }

    @Test func multiply() {
        let q1 = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 4)
        let q2 = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 4)
        let q3 = q1.multiplied(by: q2)
        let rotated = q3.rotate(SIMD3(1, 0, 0))
        #expect(abs(rotated.x) < 1e-10)
        #expect(abs(rotated.y - 1.0) < 1e-10)
    }

    @Test func axisAngle() {
        let q = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 6)
        let aa = q.axisAngle
        #expect(abs(aa.angle - .pi / 6) < 1e-10)
        #expect(abs(aa.axis.z - 1.0) < 1e-10)
    }

    @Test func rotationAngle() {
        let q = Quaternion.fromAxisAngle(axis: SIMD3(0, 0, 1), angle: .pi / 3)
        #expect(abs(q.rotationAngle - .pi / 3) < 1e-10)
    }

    @Test func normalize() {
        let q = Quaternion(x: 1, y: 2, z: 3, w: 4)
        q.normalize()
        let c = q.components
        let norm = sqrt(c.x * c.x + c.y * c.y + c.z * c.z + c.w * c.w)
        #expect(abs(norm - 1.0) < 1e-10)
    }
}

