import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Axis2Placement Tests")
struct Axis2PlacementTests {
    @Test("create and read directions")
    func createAndRead() {
        let ax = Axis2Placement(
            origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        #expect(abs(ax.xDirection.x - 1) < 1e-10)
        #expect(abs(ax.yDirection.y - 1) < 1e-10)
        #expect(abs(ax.mainDirection.z - 1) < 1e-10)
    }

    @Test("location")
    func location() {
        let ax = Axis2Placement(
            origin: SIMD3(5, 5, 5), normal: SIMD3(0, 1, 0), xDirection: SIMD3(1, 0, 0))
        #expect(abs(ax.location.x - 5) < 1e-10)
    }

    @Test("setDirection")
    func setDirection() {
        let ax = Axis2Placement(
            origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        ax.setDirection(SIMD3(0, 1, 0))
        #expect(abs(ax.mainDirection.y - 1) < 1e-10)
    }

    @Test("setXDirection")
    func setXDirection() {
        let ax = Axis2Placement(
            origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0))
        ax.setXDirection(SIMD3(0, 1, 0))
        #expect(abs(ax.xDirection.y - 1) < 1e-10)
    }
}

