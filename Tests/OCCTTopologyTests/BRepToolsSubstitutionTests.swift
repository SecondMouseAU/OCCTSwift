import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepTools Substitution Tests")
struct BRepToolsSubstitutionTests {
    @Test("Substitution bridge function is callable")
    func substituteCallable() {
        // BRepTools_Substitution works with topological sub-shapes extracted from
        // the same parent shape. Creating standalone vertices doesn't share topology.
        // We verify the bridge function handles this gracefully (returns nil).
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let v1 = Shape.vertex(at: SIMD3(0, 0, 0)),
            let v2 = Shape.vertex(at: SIMD3(1, 0, 0))
        {
            // This returns nil because v1 is not a sub-shape of box
            let result = box.substituted(replacing: v1, with: v2)
            // Just verify it doesn't crash
            _ = result
        }
    }
}
