import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_ShapeMapTool Tests")
struct XCAFDocShapeMapToolTests {
    @Test func setShapeAndQuery() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(label.setShapeMapTool())
                if let box = Shape.box(width: 10, height: 20, depth: 30) {
                    #expect(label.shapeMapToolSetShape(box))
                    let faces = box.subShapes(ofType: .face)
                    if let face = faces.first {
                        #expect(label.shapeMapToolIsSubShape(face))
                    }
                    #expect(label.shapeMapToolExtent > 0)
                }
            }
        }
    }
}
