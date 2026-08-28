import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("CoordinateSystem3D")
struct CoordinateSystem3DTests {
    @Test func defaultXYZ() {
        let cs = CoordinateSystem3D(
            origin: .zero, direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        #expect(cs.isDirect)
        #expect(abs(cs.yDirection.y - 1.0) < 1e-10)
    }

    @Test func fromNormal() {
        let cs = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1))
        #expect(cs.isDirect)
    }

    @Test func angle() {
        let cs1 = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1))
        let cs2 = CoordinateSystem3D(origin: .zero, direction: SIMD3(1, 0, 0))
        #expect(abs(cs1.angle(to: cs2) - .pi / 2) < 1e-10)
    }

    @Test func isCoplanar() {
        let cs1 = CoordinateSystem3D(origin: .zero, direction: SIMD3(0, 0, 1))
        let cs2 = CoordinateSystem3D(origin: SIMD3(1, 1, 0), direction: SIMD3(0, 0, 1))
        #expect(cs1.isCoplanar(with: cs2))
    }

    @Test func mirrorPoint() {
        let cs = CoordinateSystem3D(
            origin: SIMD3(1, 0, 0), direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        let mirrored = cs.mirrored(about: .zero)
        #expect(abs(mirrored.origin.x + 1.0) < 1e-10)
    }

    @Test func rotate() {
        let cs = CoordinateSystem3D(
            origin: SIMD3(1, 0, 0), direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        let rotated = cs.rotated(about: .zero, axisDirection: SIMD3(0, 0, 1), angle: .pi / 2)
        #expect(abs(rotated.origin.x) < 1e-10)
        #expect(abs(rotated.origin.y - 1.0) < 1e-10)
    }

    @Test func translate() {
        let cs = CoordinateSystem3D(
            origin: .zero, direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        let translated = cs.translated(by: SIMD3(1, 2, 3))
        #expect(abs(translated.origin.x - 1.0) < 1e-10)
        #expect(abs(translated.origin.z - 3.0) < 1e-10)
    }
}

