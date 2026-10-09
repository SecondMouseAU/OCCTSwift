import Foundation
import Testing

@testable import OCCTSwift

@Suite("XDE ColorTool by Shape")
struct XDEColorToolByShapeTests {
    @Test("SetColor and GetColor by shape")
    func setAndGetColor() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let red = Color(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            doc.setShapeColor(box, color: red)
            #expect(doc.isShapeColorSet(box))
            if let got = doc.shapeColor(box) {
                #expect(abs(got.red - 1.0) < 1e-5)
                #expect(abs(got.green) < 1e-5)
            }
        }
    }

    @Test("Label visibility")
    func visibility() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let box = box {
            doc.addShape(box)
            let roots = doc.rootNodes
            if let node = roots.first {
                node.isVisible = false
                #expect(!node.isVisible)
                node.isVisible = true
                #expect(node.isVisible)
            }
        }
    }

    // #763: `shapeColor` used to hardcode `a = 1.0` regardless of what was actually stored,
    // `XCAFDoc_ColorTool::GetColor(shape, type, Quantity_Color&)` fetches the real RGBA value
    // internally and then discards alpha, and the bridge was reading it through that overload.
    // A shape colored with a translucent color must read back its real alpha, not a fabricated
    // fully-opaque constant.
    @Test("Shape color round-trips a non-opaque alpha (#763)")
    func shapeColorPreservesAlpha() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        doc.addShape(box)
        let translucent = Color(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.5)
        doc.setShapeColor(box, color: translucent)
        #expect(doc.isShapeColorSet(box))
        if let got = doc.shapeColor(box) {
            #expect(abs(got.red - 0.2) < 1e-5)
            #expect(abs(got.green - 0.4) < 1e-5)
            #expect(abs(got.blue - 0.6) < 1e-5)
            #expect(abs(got.alpha - 0.5) < 1e-5)
        } else {
            #expect(Bool(false), "Expected a color to be set")
        }
    }

    @Test("Shape color round-trips full opacity (#763 regression guard)")
    func shapeColorOpaqueUnaffected() {
        guard let doc = Document.create() else {
            #expect(Bool(false), "Failed to create document")
            return
        }
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        doc.addShape(box)
        let opaque = Color(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        doc.setShapeColor(box, color: opaque)
        if let got = doc.shapeColor(box) {
            #expect(abs(got.alpha - 1.0) < 1e-5)
        } else {
            #expect(Bool(false), "Expected a color to be set")
        }
    }
}
