import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.41.0: Shape Surgery

@Suite("Shape Surgery (ReShape)")
struct ShapeSurgeryTests {
    @Test("Remove shape from compound")
    func removeFromCompound() {
        let s1 = Shape.fromWire(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!)!
        let s2 = Shape.fromWire(Wire.line(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0))!)!
        let compound = Shape.compound([s1, s2])!
        let result = compound.removingSubShapes([s1])
        #expect(result != nil)
    }

    @Test("Replace shape in compound")
    func replaceInCompound() {
        let s1 = Shape.fromWire(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!)!
        let s2 = Shape.fromWire(Wire.line(from: SIMD3(0, 5, 0), to: SIMD3(10, 5, 0))!)!
        let compound = Shape.compound([s1, s2])!
        let result = compound.replacingSubShapes([(old: s1, new: s2)])
        #expect(result != nil)
    }
}
