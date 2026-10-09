import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_ShapeMapTool Tests")
struct XCAFDocShapeMapToolTests {
    /// #766: the old test nested four assertions inside two `if let`s and finished with
    /// `shapeMapToolExtent > 0`, so a map holding one entry, the wrong entries, or every shape in
    /// the process passed equally.
    ///
    /// Measured on `Shape.box(width: 10, height: 20, depth: 30)`:
    /// `TopExp::MapShapes` yields 1 solid + 1 shell + 6 faces + 6 wires + 12 edges + 8 vertices
    /// = 34 entries, and the map's extent is 33, because `XCAFDoc_ShapeMapTool` indexes the
    /// sub-shapes and not the shape itself. `shapeMapToolIsSubShape(box)` returning false is the
    /// same fact from the other side. See
    /// `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.
    @Test func setShapeAndQuery() throws {
        let doc = try #require(Document.create())
        let main = try #require(doc.mainLabel)
        let label = try #require(doc.createLabel(parent: main))
        #expect(label.setShapeMapTool())

        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(label.shapeMapToolSetShape(box))

        let faces = box.subShapes(ofType: .face)
        let edges = box.subShapes(ofType: .edge)
        let vertices = box.subShapes(ofType: .vertex)
        #expect(faces.count == 6)
        #expect(edges.count == 12)
        #expect(vertices.count == 8)
        #expect(label.shapeMapToolExtent == 33)

        // Every level of the box's own hierarchy is in the map.
        #expect(label.shapeMapToolIsSubShape(try #require(faces.first)))
        #expect(label.shapeMapToolIsSubShape(try #require(edges.first)))
        #expect(label.shapeMapToolIsSubShape(try #require(vertices.first)))
        // The indexed shape itself is not, and nothing from another shape is. Without these two
        // the test could not tell the real map from one that answers true to everything.
        #expect(!label.shapeMapToolIsSubShape(box))
        let foreign = try #require(Shape.sphere(radius: 4))
        #expect(!label.shapeMapToolIsSubShape(foreign))
        #expect(!label.shapeMapToolIsSubShape(try #require(foreign.subShapes(ofType: .face).first)))
    }
}
