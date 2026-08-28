import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.30.0 Tests

@Suite("Non-Uniform Scale")
struct NonUniformScaleTests {
    @Test("Scale box non-uniformly")
    func scaleBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let scaled = box.nonUniformScaled(sx: 2, sy: 1, sz: 0.5)
        #expect(scaled != nil)
        #expect(scaled!.isValid)
        let size = scaled!.size!
        #expect(abs(size.x - 20) < 0.1)
        #expect(abs(size.y - 10) < 0.1)
        #expect(abs(size.z - 5) < 0.1)
    }

    @Test("Non-uniform scale preserves volume ratio")
    func volumeRatio() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let scaled = box.nonUniformScaled(sx: 2, sy: 3, sz: 0.5)!
        let origVol = box.volume ?? 0
        let scaledVol = scaled.volume ?? 0
        // Volume should scale by sx*sy*sz = 3.0
        #expect(abs(scaledVol / origVol - 3.0) < 0.1)
    }
}

