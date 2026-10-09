import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - unpackSIMD3 shared helper (#419)

@Suite("unpackSIMD3 shared helper")
struct UnpackSIMD3Tests {
    @Test("Exact index-to-component mapping for a known flat buffer")
    func exactMapping() {
        let flat: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        let points: [SIMD3<Double>] = unpackSIMD3(flat, count: 3)
        #expect(points.count == 3)
        #expect(points == [SIMD3(1, 2, 3), SIMD3(4, 5, 6), SIMD3(7, 8, 9)])
    }

    @Test("count: 0 returns an empty array")
    func zeroCountIsEmpty() {
        let flat: [Double] = [1, 2, 3]
        let points: [SIMD3<Double>] = unpackSIMD3(flat, count: 0)
        #expect(points.isEmpty)
    }

    @Test("Only reads the first `count` triples, never buffer entries past it")
    func stopsAtActualCountNotBufferLength() {
        // The whole point of #419: the caller passes the ACTUAL written count, and the
        // helper must never read past it even though the backing buffer is larger,
        // this is exactly the divergence that made sampleFaceUVGrid unsafe.
        let flat: [Double] = [1, 2, 3, 999, 999, 999]
        let points: [SIMD3<Double>] = unpackSIMD3(flat, count: 1)
        #expect(points == [SIMD3(1, 2, 3)])
    }

    @Test("Works generically for a Float scalar buffer")
    func floatScalarBuffer() {
        let flat: [Float] = [1, 2, 3, 4, 5, 6]
        let points: [SIMD3<Float>] = unpackSIMD3(flat, count: 2)
        #expect(points == [SIMD3<Float>(1, 2, 3), SIMD3<Float>(4, 5, 6)])
    }

    @Test("Works for an UnsafeBufferPointer, not just a plain Array")
    func unsafeBufferPointerBuffer() {
        let flat: [Double] = [1, 2, 3, 4, 5, 6]
        let points: [SIMD3<Double>] = flat.withUnsafeBufferPointer { buf in
            unpackSIMD3(buf, count: 2)
        }
        #expect(points == [SIMD3(1, 2, 3), SIMD3(4, 5, 6)])
    }
}
