import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - packSIMD3 shared helper (#1186, the write-direction sibling of unpackSIMD3, #419)

@Suite("packSIMD3 shared helper")
struct PackSIMD3Tests {
    @Test("Exact component-to-index mapping for a known SIMD3 array")
    func exactMapping() {
        let points: [SIMD3<Double>] = [SIMD3(1, 2, 3), SIMD3(4, 5, 6), SIMD3(7, 8, 9)]
        let flat = packSIMD3(points)
        #expect(flat == [1, 2, 3, 4, 5, 6, 7, 8, 9])
    }

    @Test("Empty input returns an empty array")
    func emptyInputIsEmpty() {
        let points: [SIMD3<Double>] = []
        let flat = packSIMD3(points)
        #expect(flat.isEmpty)
    }

    @Test("Works generically for a Float scalar")
    func floatScalarBuffer() {
        let points: [SIMD3<Float>] = [SIMD3(1, 2, 3), SIMD3(4, 5, 6)]
        let flat = packSIMD3(points)
        #expect(flat == [1, 2, 3, 4, 5, 6])
    }

    @Test("Round-trips through unpackSIMD3, the read-direction sibling")
    func roundTripsThroughUnpack() {
        let points: [SIMD3<Double>] = [SIMD3(1, 2, 3), SIMD3(4, 5, 6), SIMD3(7, 8, 9)]
        let flat = packSIMD3(points)
        let roundTripped: [SIMD3<Double>] = unpackSIMD3(flat, count: points.count)
        #expect(roundTripped == points)
    }
}
