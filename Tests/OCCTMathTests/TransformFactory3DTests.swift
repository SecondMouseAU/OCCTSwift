import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.103.0 Tests

@Suite("gce Transform Factory 3D Tests")
struct TransformFactory3DTests {

    @Test func pointMirror() {
        let t = TransformFactory3D.mirrorPoint(SIMD3(0, 0, 0))
        let p = t.apply(to: SIMD3(1, 2, 3))
        #expect(abs(p.x + 1) < 1e-6)
        #expect(abs(p.y + 2) < 1e-6)
        #expect(abs(p.z + 3) < 1e-6)
    }

    @Test func planeMirror() {
        let t = TransformFactory3D.mirrorPlane(point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let p = t.apply(to: SIMD3(1, 2, 3))
        #expect(abs(p.x - 1) < 1e-6)
        #expect(abs(p.z + 3) < 1e-6)
    }

    @Test func rotation90() {
        let t = TransformFactory3D.rotation(point: .zero, direction: SIMD3(0, 0, 1), angle: .pi / 2)
        let p = t.apply(to: SIMD3(1, 0, 0))
        #expect(abs(p.x) < 1e-6)
        #expect(abs(p.y - 1) < 1e-6)
    }

    @Test func scaleBy2() {
        let t = TransformFactory3D.scale(center: .zero, factor: 2)
        let p = t.apply(to: SIMD3(1, 2, 3))
        #expect(abs(p.x - 2) < 1e-6)
        #expect(abs(p.y - 4) < 1e-6)
        #expect(abs(p.z - 6) < 1e-6)
    }

    @Test func translationVector() {
        let t = TransformFactory3D.translation(SIMD3(10, 20, 30))
        let p = t.apply(to: SIMD3(1, 2, 3))
        #expect(abs(p.x - 11) < 1e-6)
        #expect(abs(p.y - 22) < 1e-6)
    }

    @Test func translationPoints() {
        let t = TransformFactory3D.translation(from: .zero, to: SIMD3(5, 5, 5))
        let p = t.apply(to: SIMD3(1, 1, 1))
        #expect(abs(p.x - 6) < 1e-6)
    }

    @Test func axisMirror() {
        let t = TransformFactory3D.mirrorAxis(point: .zero, direction: SIMD3(0, 0, 1))
        let p = t.apply(to: SIMD3(1, 2, 3))
        #expect(abs(p.x + 1) < 1e-6)
        #expect(abs(p.y + 2) < 1e-6)
        #expect(abs(p.z - 3) < 1e-6)
    }
}

