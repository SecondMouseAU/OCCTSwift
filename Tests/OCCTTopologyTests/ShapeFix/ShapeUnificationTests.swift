import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape Unification Tests")
struct ShapeUnificationTests {

    @Test("Unify boolean result")
    func unifyBooleanResult() {
        // Create a shape with potentially redundant topology from booleans
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let cyl = Shape.cylinder(radius: 3, height: 25)!

        // Subtract cylinder to create internal faces
        let result = (box - cyl)!

        let unified = result.unified()

        #expect(unified != nil)
        #expect(unified!.isValid)
    }

    @Test("Unify with edge-only mode")
    func unifyEdgesOnly() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let unified = box.unified(unifyEdges: true, unifyFaces: false)

        #expect(unified != nil)
        #expect(unified!.isValid)
    }

    @Test("Simplify shape")
    func simplifyShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let simplified = box.simplified(tolerance: 0.001)

        #expect(simplified != nil)
        #expect(simplified!.isValid)
    }
}
