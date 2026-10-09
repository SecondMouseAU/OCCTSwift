import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.42.0: Solid Construction

@Suite("Solid Construction")
struct SolidConstructionTests {
    @Test("Solid from single box shell")
    func solidFromSingleShell() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let solid = Shape.solidFromShells([box])
        #expect(solid != nil)
        if let solid {
            #expect(solid.isValid)
            // Volume should match the box volume
            let vol = solid.volume!
            #expect(abs(vol - 1000.0) < 1.0)
        }
    }

    @Test("Solid from two box shells (outer + cavity)")
    func solidFromTwoShells() {
        let outer = Shape.box(width: 20, height: 20, depth: 20)!
        let inner = Shape.box(width: 10, height: 10, depth: 10)!
        let solid = Shape.solidFromShells([outer, inner])
        #expect(solid != nil)
        // The solid should be created (two shells combined)
    }

    @Test("Solid from empty array returns nil")
    func solidFromEmptyReturnsNil() {
        let solid = Shape.solidFromShells([])
        #expect(solid == nil)
    }
}
