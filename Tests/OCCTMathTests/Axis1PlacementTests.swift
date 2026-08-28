import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Axis1Placement Tests")
struct Axis1PlacementTests {
    @Test("create and read")
    func createAndRead() {
        let ax = Axis1Placement(origin: SIMD3(1, 2, 3), direction: SIMD3(0, 0, 1))
        #expect(abs(ax.location.x - 1) < 1e-10)
        #expect(abs(ax.direction.z - 1) < 1e-10)
    }

    @Test("reverse")
    func reverse() {
        let ax = Axis1Placement(origin: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1))
        ax.reverse()
        #expect(abs(ax.direction.z + 1) < 1e-10)
    }

    @Test("reversed copy")
    func reversedCopy() {
        let ax = Axis1Placement(origin: SIMD3(0, 0, 0), direction: SIMD3(0, 1, 0))
        let rev = ax.reversed()
        #expect(abs(rev.direction.y + 1) < 1e-10)
        #expect(abs(ax.direction.y - 1) < 1e-10)  // original unchanged
    }

    @Test("setDirection and setLocation")
    func setters() {
        let ax = Axis1Placement(origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        ax.setDirection(SIMD3(0, 1, 0))
        ax.setLocation(SIMD3(5, 5, 5))
        #expect(abs(ax.direction.y - 1) < 1e-10)
        #expect(abs(ax.location.x - 5) < 1e-10)
    }
}

