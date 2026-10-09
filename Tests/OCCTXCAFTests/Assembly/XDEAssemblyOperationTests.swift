import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("XDE Assembly Operations")
struct XDEAssemblyOperationTests {
    /// Where a component sits, read from the shape its label carries: the bounding box of the
    /// referenced shape with the component's location applied, which is the only way to see a
    /// placement through the public API without going through the explorer.
    private func placement(
        _ doc: Document, _ componentLabelId: Int64
    ) throws -> (min: SIMD3<Double>, max: SIMD3<Double>) {
        let node = try #require(doc.node(at: componentLabelId), "component \(componentLabelId)")
        let shape = try #require(node.shape, "component \(componentLabelId) carries no shape")
        return try #require(shape.boundingBox, "component \(componentLabelId) has no bounds")
    }

    private func expectBounds(
        _ b: (min: SIMD3<Double>, max: SIMD3<Double>), min lo: SIMD3<Double>,
        max hi: SIMD3<Double>, _ what: String
    ) {
        // The bounding box is padded by about 1e-7, so the tolerance is looser than that.
        #expect(simd_length(b.min - lo) < 1e-5, "\(what): min \(b.min), expected \(lo)")
        #expect(simd_length(b.max - hi) < 1e-5, "\(what): max \(b.max), expected \(hi)")
    }

    @Test("AddComponent creates assembly")
    func addComponent() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        let boxLabelId = doc.addShape(box)
        let sphereLabelId = doc.addShape(sphere)
        let assemblyLabelId = doc.newShapeLabel()
        #expect(boxLabelId >= 0)
        #expect(sphereLabelId >= 0)
        #expect(assemblyLabelId >= 0)
        // Three distinct labels, so a "label" that is one constant for everything is not it.
        #expect(Set([boxLabelId, sphereLabelId, assemblyLabelId]).count == 3)
        #expect(doc.componentCount(assemblyLabelId: assemblyLabelId) == 0)

        let comp1 = doc.addComponent(
            assemblyLabelId: assemblyLabelId,
            shapeLabelId: boxLabelId,
            translation: (0, 0, 0))
        #expect(comp1 >= 0)
        #expect(doc.componentCount(assemblyLabelId: assemblyLabelId) == 1)

        let comp2 = doc.addComponent(
            assemblyLabelId: assemblyLabelId,
            shapeLabelId: sphereLabelId,
            translation: (50, 0, 0))
        #expect(comp2 >= 0)
        #expect(comp2 != comp1)
        #expect(comp2 != assemblyLabelId)
        #expect(doc.componentCount(assemblyLabelId: assemblyLabelId) == 2)

        // Which shapes became the components, in the order they were added.
        #expect(doc.componentLabelId(assemblyLabelId: assemblyLabelId, at: 0) == comp1)
        #expect(doc.componentLabelId(assemblyLabelId: assemblyLabelId, at: 1) == comp2)
        #expect(doc.componentReferredLabelId(comp1) == boxLabelId)
        #expect(doc.componentReferredLabelId(comp2) == sphereLabelId)

        // Where they sit. The shapes are centred on the origin, so the box (10 x 20 x 30) stays
        // at +-5, +-10, +-15 and the sphere (radius 5) moves to x 45...55.
        expectBounds(
            try placement(doc, comp1), min: SIMD3(-5, -10, -15), max: SIMD3(5, 10, 15),
            "box at the origin")
        expectBounds(
            try placement(doc, comp2), min: SIMD3(45, -5, -5), max: SIMD3(55, 5, 5),
            "sphere moved to x = 50")
    }

    @Test("a translation moves the component on each axis, not on x alone")
    func translationOnEveryAxis() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 2, height: 4, depth: 6))
        let part = doc.addShape(box, makeAssembly: false)
        let asm = doc.newShapeLabel()
        let moved = doc.addComponent(
            assemblyLabelId: asm, shapeLabelId: part, translation: (10, 20, 30))
        #expect(moved >= 0)
        // Distinct values per axis, so a swapped or dropped axis reads wrong: the box spans
        // +-1, +-2, +-3 about the origin.
        expectBounds(
            try placement(doc, moved), min: SIMD3(9, 18, 27), max: SIMD3(11, 22, 33),
            "box translated by (10, 20, 30)")
    }

    @Test("GetComponents and GetReferredShape")
    func getComponents() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        let boxLabelId = doc.addShape(box)
        let sphereLabelId = doc.addShape(sphere)
        let assemblyLabelId = doc.newShapeLabel()
        let compId = doc.addComponent(
            assemblyLabelId: assemblyLabelId,
            shapeLabelId: boxLabelId)
        #expect(compId >= 0)
        let compLabelId = doc.componentLabelId(assemblyLabelId: assemblyLabelId, at: 0)
        // The component is the label addComponent made, and not the assembly or the shape.
        #expect(compLabelId == compId)
        #expect(compLabelId != assemblyLabelId)
        #expect(compLabelId != boxLabelId)
        // It refers to the box it was made from, and not to the other shape in the document.
        let referredId = doc.componentReferredLabelId(compLabelId)
        #expect(referredId == boxLabelId)
        #expect(referredId != sphereLabelId)

        // The refusals: no component at index 1 or -1, and a label that is not a component has
        // no referred shape.
        #expect(doc.componentLabelId(assemblyLabelId: assemblyLabelId, at: 1) == -1)
        #expect(doc.componentLabelId(assemblyLabelId: assemblyLabelId, at: -1) == -1)
        #expect(doc.componentReferredLabelId(boxLabelId) == -1)
        #expect(doc.componentCount(assemblyLabelId: sphereLabelId) == 0)
    }

    @Test("RemoveComponent")
    func removeComponent() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        let cone = try #require(Shape.cone(bottomRadius: 4, topRadius: 2, height: 6))
        let boxId = doc.addShape(box)
        let sphereId = doc.addShape(sphere)
        let coneId = doc.addShape(cone)
        let asmId = doc.newShapeLabel()
        let comp1 = doc.addComponent(assemblyLabelId: asmId, shapeLabelId: boxId)
        let comp2 = doc.addComponent(assemblyLabelId: asmId, shapeLabelId: sphereId)
        let comp3 = doc.addComponent(assemblyLabelId: asmId, shapeLabelId: coneId)
        #expect(doc.componentCount(assemblyLabelId: asmId) == 3)

        // Remove the middle one: it is that component that goes, the other two stay in order.
        doc.removeComponent(labelId: comp2)
        #expect(doc.componentCount(assemblyLabelId: asmId) == 2)
        #expect(doc.componentLabelId(assemblyLabelId: asmId, at: 0) == comp1)
        #expect(doc.componentLabelId(assemblyLabelId: asmId, at: 1) == comp3)
        #expect(doc.componentReferredLabelId(comp1) == boxId)
        #expect(doc.componentReferredLabelId(comp3) == coneId)
        // The shape the removed component referred to is still in the document, just unused.
        #expect(doc.shapeUserCount(shapeLabelId: sphereId) == 0)
        #expect(doc.shapeUserCount(shapeLabelId: boxId) == 1)

        // Then the first, which a "remove the first component" stand-in would not tell from
        // removing the one named when the two coincide.
        doc.removeComponent(labelId: comp3)
        #expect(doc.componentCount(assemblyLabelId: asmId) == 1)
        #expect(doc.componentLabelId(assemblyLabelId: asmId, at: 0) == comp1)
        doc.removeComponent(labelId: comp1)
        #expect(doc.componentCount(assemblyLabelId: asmId) == 0)
    }

    @Test("ShapeUserCount")
    func userCount() throws {
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        let boxId = doc.addShape(box, makeAssembly: false)
        let sphereId = doc.addShape(sphere, makeAssembly: false)
        let asmId = doc.newShapeLabel()
        let otherAsmId = doc.newShapeLabel()

        // Nothing instantiates it yet.
        #expect(doc.shapeUserCount(shapeLabelId: boxId) == 0)

        doc.addComponent(assemblyLabelId: asmId, shapeLabelId: boxId)
        #expect(doc.shapeUserCount(shapeLabelId: boxId) == 1)
        #expect(doc.shapeUserCount(shapeLabelId: sphereId) == 0)

        // Two instances in one assembly and one in another: each is a user.
        doc.addComponent(assemblyLabelId: asmId, shapeLabelId: boxId, translation: (20, 0, 0))
        #expect(doc.shapeUserCount(shapeLabelId: boxId) == 2)
        let third = doc.addComponent(assemblyLabelId: otherAsmId, shapeLabelId: boxId)
        #expect(doc.shapeUserCount(shapeLabelId: boxId) == 3)

        // And it counts down when a user goes.
        doc.removeComponent(labelId: third)
        #expect(doc.shapeUserCount(shapeLabelId: boxId) == 2)
        #expect(doc.shapeUserCount(shapeLabelId: sphereId) == 0)
    }

    @Test("UpdateAssemblies")
    func updateAssemblies() throws {
        let doc = try #require(Document.create())
        // On an empty document there is nothing to update and nothing changes.
        doc.updateAssemblies()
        #expect(doc.explorerNodeCount == 0)

        // With an assembly, the update is what builds the occurrence the explorer walks: a part
        // placed under an assembly is one leaf at depth one, with the component's location.
        doc.defineAllFormats()
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let part = doc.addShape(box, makeAssembly: false)
        let asm = doc.newShapeLabel()
        #expect(
            doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, translation: (7, 0, 0)) >= 0)
        doc.updateAssemblies()
        #expect(doc.explorerNodeCount == 1)
        #expect(doc.explorerDepth(at: 0) == 1)
        #expect(doc.explorerLocation(at: 0) == [1, 0, 0, 7, 0, 1, 0, 0, 0, 0, 1, 0])
        let node = try #require(doc.node(at: asm))
        #expect(node.isAssembly)
        let compound = try #require(node.shape, "the assembly carries no shape after the update")
        #expect(compound.subShapeCount(ofType: .solid) == 1)
        let bounds = try #require(compound.boundingBox)
        expectBounds(bounds, min: SIMD3(2, -10, -15), max: SIMD3(12, 10, 15), "assembly compound")
    }
}
