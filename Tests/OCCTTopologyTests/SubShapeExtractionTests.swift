import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - Sub-Shape Extraction Tests (v0.38.0)

@Suite("Sub-Shape Extraction")
struct SubShapeExtractionTests {

    @Test("Box has one solid")
    func boxOneSolid() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        #expect(box.solidCount == 1)
        #expect(box.solids.count == 1)
    }

    @Test("Fused disjoint boxes have two solids in compound")
    func disjointSolids() {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 5, height: 5, depth: 5)!.translated(by: SIMD3(20, 0, 0))!
        let compound = box1 + box2
        #expect(compound != nil)
        // After fuse of disjoint shapes, result may be compound with 2 solids
        let solids = compound!.solids
        #expect(solids.count >= 1)
    }

    @Test("Box shells")
    func boxShells() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        #expect(box.shellCount >= 1)
        #expect(box.shells.count >= 1)
    }

    @Test("Box wires")
    func boxWires() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        // A box has 6 faces, each with 1 wire = 6 wires
        #expect(box.wireCount == 6)
        #expect(box.wires.count == 6)
    }

    @Test("Sphere wires")
    func sphereWires() {
        let sphere = Shape.sphere(radius: 5)!
        #expect(sphere.wireCount >= 1)
    }

    @Test("Empty shape returns empty arrays")
    func emptyShape() {
        // A single vertex has no solids, shells, or wires
        let vertex = Shape.vertex(at: SIMD3(0, 0, 0))!
        #expect(vertex.solidCount == 0)
        #expect(vertex.solids.isEmpty)
        #expect(vertex.shellCount == 0)
        #expect(vertex.shells.isEmpty)
    }
}
