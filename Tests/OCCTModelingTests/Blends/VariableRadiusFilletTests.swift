import Testing
import simd

@testable import OCCTSwift

// MARK: - Advanced Blends & Surface Filling Tests (v0.14.0)

@Suite("Variable Radius Fillet Tests")
struct VariableRadiusFilletTests {

    @Test("Variable radius fillet on box edge")
    func variableFilletOnBoxEdge() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Apply variable radius fillet: starts at 1mm, ends at 3mm
        let filleted = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.0, 1.0), (1.0, 3.0)]
        )

        #expect(filleted != nil)
        if let filleted = filleted {
            #expect(filleted.isValid)
        }
    }

    @Test("Variable radius fillet with mid-point")
    func variableFilletWithMidPoint() {
        let box = Shape.box(width: 30, height: 30, depth: 30)!

        // Apply variable radius fillet: 1mm at start, 4mm at middle, 1mm at end
        let filleted = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.0, 1.0), (0.5, 4.0), (1.0, 1.0)]
        )

        #expect(filleted != nil)
        if let filleted = filleted {
            #expect(filleted.isValid)
        }
    }

    @Test("Variable fillet requires at least two points")
    func variableFilletRequiresMinPoints() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Should fail with only one point
        let filleted = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.5, 1.0)]
        )

        #expect(filleted == nil)
    }
}
