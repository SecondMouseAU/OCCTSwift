import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - Sub-Shape Extraction Tests (v0.38.0)

@Suite("Sub-Shape Extraction")
struct SubShapeExtractionTests {

    @Test("Box has one solid")
    func boxOneSolid() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        #expect(box.solidCount == 1)
        #expect(box.solids.count == 1)
    }

    @Test("Fused disjoint boxes have two solids in compound")
    func disjointSolids() throws {
        let box1 = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let box2 = try #require(
            Shape.box(width: 5, height: 5, depth: 5)?.translated(by: SIMD3(20, 0, 0)))
        let fused = box1 + box2
        let compound = try #require(fused)
        // Fusing disjoint boxes keeps both bodies: a compound holding two solids of 125 each.
        #expect(compound.shapeType == .compound)
        #expect(compound.solidCount == 2)
        let solids = compound.solids
        #expect(solids.count == 2)
        for solid in solids {
            #expect(abs(try #require(solid.volume) - 125) < 1e-9)
        }
    }

    @Test("Box shells")
    func boxShells() throws {
        // One solid, one shell, and that shell is the box's whole boundary: 6 faces.
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        #expect(box.shellCount == 1)
        let shells = box.shells
        #expect(shells.count == 1)
        if let shell = shells.first {
            #expect(shell.shapeType == .shell)
            #expect(shell.faceCount == 6)
        }
    }

    @Test("Box wires")
    func boxWires() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        // A box has 6 faces, each with 1 wire = 6 wires
        #expect(box.wireCount == 6)
        #expect(box.wires.count == 6)
    }

    @Test("Sphere wires")
    func sphereWires() throws {
        // The sphere is one face, and that face has the one wire that holds its seam and its
        // two pole edges.
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(sphere.faceCount == 1)
        #expect(sphere.wireCount == 1)
        #expect(sphere.wires.count == 1)
        // Control: a cylinder has three faces and so three wires.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cyl.wireCount == 3)
    }

    @Test("Empty shape returns empty arrays")
    func emptyShape() throws {
        // A single vertex has no solids, shells, or wires
        let vertex = try #require(Shape.vertex(at: SIMD3(0, 0, 0)))
        #expect(vertex.solidCount == 0)
        #expect(vertex.solids.isEmpty)
        #expect(vertex.shellCount == 0)
        #expect(vertex.shells.isEmpty)
    }
}
