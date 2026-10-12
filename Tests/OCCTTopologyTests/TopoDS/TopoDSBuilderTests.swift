import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.114.0 Tests

@Suite("v0.114.0 - TopoDS_Builder")
struct TopoDSBuilderTests {

    @Test func makeCompound() throws {
        let compound = try #require(Shape.builderMakeCompound())
        #expect(compound.shapeType == .compound)
        #expect(compound.nbChildren == 0)
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(compound.builderAdd(box))
        #expect(compound.nbChildren == 1)
        #expect(compound.contentsExtended().nbSolids == 1)
        // A second add lands as a second child, not a replacement.
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(compound.builderAdd(sphere))
        #expect(compound.nbChildren == 2)
        #expect(compound.contentsExtended().nbSolids == 2)
        #expect(abs((compound.volume ?? 0) - (1000 + 500 * Double.pi / 3)) < 1e-6)
    }

    @Test func makeWire() {
        if let wire = Shape.builderMakeWire() {
            // Can create empty wire shape
            #expect(wire.shapeType == .wire)
        }
    }

    @Test func makeShell() {
        if let shell = Shape.builderMakeShell() {
            #expect(shell.shapeType == .shell)
        }
    }

    @Test func makeSolid() {
        if let solid = Shape.builderMakeSolid() {
            #expect(solid.shapeType == .solid)
        }
    }

    @Test func makeCompSolid() {
        if let cs = Shape.builderMakeCompSolid() {
            #expect(cs.shapeType == .compSolid)
        }
    }

    @Test func addAndRemove() {
        if let compound = Shape.builderMakeCompound() {
            if let box1 = Shape.box(width: 5, height: 5, depth: 5),
                let box2 = Shape.box(width: 3, height: 3, depth: 3)
            {
                compound.builderAdd(box1)
                compound.builderAdd(box2)
                let c1 = compound.contentsExtended()
                #expect(c1.nbSolids == 2)
                compound.builderRemove(box1)
                let c2 = compound.contentsExtended()
                #expect(c2.nbSolids == 1)
            }
        }
    }
}
