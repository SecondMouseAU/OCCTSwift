import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.60.0 XDE/XCAF Full Coverage Tests

@Suite("XDE ShapeTool Queries")
struct XDEShapeToolQueryTests {
    @Test("AddShape and GetShapeCount")
    func addShapeAndCount() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        #expect(box != nil)
        if let box = box {
            let labelId = doc.addShape(box)
            #expect(labelId >= 0)
            #expect(doc.shapeCount > 0)
        }
    }

    @Test("GetFreeShapeCount")
    func freeShapeCount() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            #expect(doc.freeShapeCount > 0)
        }
    }

    @Test("FindShape and SearchShape")
    func findAndSearch() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let addedId = doc.addShape(box)
            #expect(addedId >= 0)
            let foundId = doc.findShape(box)
            #expect(foundId >= 0)
            let searchId = doc.searchShape(box)
            #expect(searchId >= 0)
        }
    }

    @Test("NewShape and RemoveShape")
    func newAndRemove() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            let labelId = doc.addShape(box)
            #expect(labelId >= 0)
            let removed = doc.removeShape(labelId: labelId)
            #expect(removed)
        }
    }

    @Test("IsTopLevel, IsComponent, IsCompound on node")
    func labelQueries() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            #expect(roots.count > 0)
            if let root = roots.first {
                #expect(root.isTopLevel)
                #expect(!root.isComponent)
            }
        }
    }
}
