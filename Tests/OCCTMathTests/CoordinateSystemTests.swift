import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Coordinate System Tests")
struct CoordinateSystemTests {
    @Test func zUpDirection() {
        let up = coordinateSystemUpDirection(.zUp)
        #expect(abs(up.z - 1.0) < 1e-10)
    }

    @Test func yUpDirection() {
        let up = coordinateSystemUpDirection(.yUp)
        #expect(abs(up.y - 1.0) < 1e-10)
    }

    @Test func convertWithScaling() {
        let result = convertCoordinateSystem(
            x: 1000, y: 0, z: 500,
            from: .zUp, inputUnit: 0.001,
            to: .zUp, outputUnit: 1.0)
        #expect(abs(result.x - 1.0) < 1e-6)
        #expect(abs(result.z - 0.5) < 1e-6)
    }

    @Test func convertZupToYup() {
        let result = convertCoordinateSystem(
            x: 1, y: 2, z: 3,
            from: .zUp, inputUnit: 1.0,
            to: .yUp, outputUnit: 1.0)
        // Z-up (X,Y,Z) → Y-up (X,Z,-Y)
        #expect(abs(result.x - 1.0) < 1e-6)
        #expect(abs(result.y - 3.0) < 1e-6)
        #expect(abs(result.z + 2.0) < 1e-6)
    }
}

