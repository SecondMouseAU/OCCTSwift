import Foundation
import Testing

@testable import OCCTSwift

@Suite("v0.126.0, XCAFDoc_ShapeTool completions")
struct ShapeToolCompletionsTests {
    @Test("IsFree returns true for top-level shape")
    func isFree() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(doc.shapeToolIsFree(labelId: labelId))
            }
        }
    }

    @Test("IsSimpleShape returns true for box")
    func isSimpleShape() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(doc.shapeToolIsSimpleShape(labelId: labelId))
            }
        }
    }

    @Test("IsComponent returns false for simple shape")
    func isComponent() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(!doc.shapeToolIsComponent(labelId: labelId))
            }
        }
    }

    @Test("IsCompound returns false for simple box")
    func isCompound() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(!doc.shapeToolIsCompound(labelId: labelId))
            }
        }
    }

    @Test("IsSubShape returns false for top-level")
    func isSubShape() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(!doc.shapeToolIsSubShape(labelId: labelId))
            }
        }
    }

    @Test("IsExternRef returns false for regular shape")
    func isExternRef() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                #expect(!doc.shapeToolIsExternRef(labelId: labelId))
            }
        }
    }

    @Test("GetUsers returns 0 for unreferenced shape")
    func getUsers() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                let users = doc.shapeToolGetUsers(labelId: labelId)
                #expect(users == 0)
            }
        }
    }

    @Test("NbComponents returns 0 for simple shape")
    func nbComponents() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                let nb = doc.shapeToolNbComponents(labelId: labelId)
                #expect(nb == 0)
            }
        }
    }

    @Test("ComputeShapes doesn't crash")
    func computeShapes() {
        guard let doc = Document.create() else { return }
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let labelId = doc.addShape(box)
            if labelId >= 0 {
                doc.shapeToolComputeShapes(labelId: labelId)
                // Just check it doesn't crash
            }
        }
    }
}
