import Foundation
import Testing

@testable import OCCTSwift

@Suite("XDE Assembly Operations")
struct XDEAssemblyOperationTests {
    @Test("AddComponent creates assembly")
    func addComponent() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let box = box, let sphere = sphere {
            let boxLabelId = doc.addShape(box)
            let sphereLabelId = doc.addShape(sphere)
            let assemblyLabelId = doc.newShapeLabel()
            #expect(assemblyLabelId >= 0)

            let comp1 = doc.addComponent(
                assemblyLabelId: assemblyLabelId,
                shapeLabelId: boxLabelId,
                translation: (0, 0, 0))
            #expect(comp1 >= 0)

            let comp2 = doc.addComponent(
                assemblyLabelId: assemblyLabelId,
                shapeLabelId: sphereLabelId,
                translation: (50, 0, 0))
            #expect(comp2 >= 0)

            #expect(doc.componentCount(assemblyLabelId: assemblyLabelId) == 2)
        }
    }

    @Test("GetComponents and GetReferredShape")
    func getComponents() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let boxLabelId = doc.addShape(box)
            let assemblyLabelId = doc.newShapeLabel()
            let compId = doc.addComponent(
                assemblyLabelId: assemblyLabelId,
                shapeLabelId: boxLabelId)
            #expect(compId >= 0)
            let compLabelId = doc.componentLabelId(assemblyLabelId: assemblyLabelId, at: 0)
            #expect(compLabelId >= 0)
            let referredId = doc.componentReferredLabelId(compLabelId)
            #expect(referredId >= 0)
        }
    }

    @Test("RemoveComponent")
    func removeComponent() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let box = box, let sphere = sphere {
            let boxId = doc.addShape(box)
            let sphereId = doc.addShape(sphere)
            let asmId = doc.newShapeLabel()
            let comp1 = doc.addComponent(assemblyLabelId: asmId, shapeLabelId: boxId)
            let comp2 = doc.addComponent(assemblyLabelId: asmId, shapeLabelId: sphereId)
            #expect(doc.componentCount(assemblyLabelId: asmId) == 2)
            doc.removeComponent(labelId: comp2)
            #expect(doc.componentCount(assemblyLabelId: asmId) == 1)
            _ = comp1  // silence warning
        }
    }

    @Test("ShapeUserCount")
    func userCount() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let boxId = doc.addShape(box)
            let asmId = doc.newShapeLabel()
            doc.addComponent(assemblyLabelId: asmId, shapeLabelId: boxId)
            #expect(doc.shapeUserCount(shapeLabelId: boxId) > 0)
        }
    }

    @Test("UpdateAssemblies")
    func updateAssemblies() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        doc.updateAssemblies()
        // No crash = success
        #expect(Bool(true))
    }
}
