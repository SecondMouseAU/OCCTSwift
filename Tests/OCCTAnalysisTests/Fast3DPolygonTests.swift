import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.42.0: Fast 3D Polygon

@Suite("Fast 3D Polygon")
struct Fast3DPolygonTests {
    @Test("Closed square polygon")
    func closedSquare() {
        let wire = Wire.polygon3D(
            [
                SIMD3(0, 0, 0), SIMD3(10, 0, 0),
                SIMD3(10, 10, 0), SIMD3(0, 10, 0),
            ], closed: true)
        #expect(wire != nil)
        if let wire {
            #expect(wire.orderedEdgeCount == 4)
        }
    }

    @Test("Open triangle polygon")
    func openTriangle() {
        let wire = Wire.polygon3D(
            [
                SIMD3(0, 0, 0), SIMD3(5, 0, 3), SIMD3(10, 5, 6),
            ], closed: false)
        #expect(wire != nil)
        if let wire {
            #expect(wire.orderedEdgeCount == 2)
        }
    }

    @Test("3D polygon wire (non-planar)")
    func nonPlanarPolygon() {
        let wire = Wire.polygon3D(
            [
                SIMD3(0, 0, 0), SIMD3(10, 0, 0),
                SIMD3(10, 10, 5), SIMD3(0, 10, 10),
            ], closed: true)
        #expect(wire != nil)
        if let wire {
            #expect(wire.orderedEdgeCount == 4)
        }
    }

    @Test("Minimum points (2) makes a single edge")
    func twoPointPolygon() {
        let wire = Wire.polygon3D(
            [
                SIMD3(0, 0, 0), SIMD3(10, 0, 0),
            ], closed: false)
        #expect(wire != nil)
        if let wire {
            #expect(wire.orderedEdgeCount == 1)
        }
    }

    @Test("Single point returns nil")
    func singlePointReturnsNil() {
        let wire = Wire.polygon3D([SIMD3(0, 0, 0)])
        #expect(wire == nil)
    }
}
