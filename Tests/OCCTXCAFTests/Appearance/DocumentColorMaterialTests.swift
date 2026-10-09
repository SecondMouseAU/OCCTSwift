import Foundation
import Testing

@testable import OCCTSwift

@Suite("Document Color/Material Setter Tests")
struct DocumentColorMaterialTests {

    @Test("Set and get label color")
    func setLabelColor() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("color_test.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try box.writeSTEP(to: tempURL)
        let doc = try Document.load(from: tempURL)
        let nodes = doc.rootNodes
        #expect(!nodes.isEmpty)

        if let node = nodes.first {
            node.setColor(Color(red: 1.0, green: 0.0, blue: 0.0))
            let color = node.color
            #expect(color != nil)
            if let color {
                #expect(abs(color.red - 1.0) < 0.01)
                #expect(abs(color.green) < 0.01)
                #expect(abs(color.blue) < 0.01)
            }
        }
    }

    @Test("Color attribute (XCAFDoc_Color) round-trips a non-trivial RGB triple (#1508)")
    func colorAttrRoundTrips() throws {
        // #1508: OCCTDocumentSetColorAttr built Quantity_Color(r,g,b, Quantity_TOC_sRGB) --
        // gamma-encoded the caller's RGB into OCCT's internal linear storage -- while
        // OCCTDocumentGetColorAttr read it back via .Red()/.Green()/.Blue(), which return the raw
        // internal value with no conversion. Set-then-get returned a different color than was
        // set: (0.5, 0.25, 0.75) in, (0.214041, 0.050876, 0.522522) out, before the fix.
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("color_attr_roundtrip_test.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try box.writeSTEP(to: tempURL)
        let doc = try Document.load(from: tempURL)
        let nodes = doc.rootNodes
        #expect(!nodes.isEmpty)

        guard let node = nodes.first else { return }

        let set = node.setColorAttribute(red: 0.5, green: 0.25, blue: 0.75)
        #expect(set)

        let readBack = node.colorAttribute
        #expect(readBack != nil)
        if let readBack {
            #expect(abs(readBack.red - 0.5) < 1e-6)
            #expect(abs(readBack.green - 0.25) < 1e-6)
            #expect(abs(readBack.blue - 0.75) < 1e-6)
        }
    }

    @Test("RGBA color attribute (XCAFDoc_Color) round-trips a non-trivial RGBA quadruple (#1508)")
    func colorRGBAAttrRoundTrips() throws {
        // Same defect as colorAttrRoundTrips, on the RGBA sibling pair
        // (OCCTDocumentSetColorRGBAAttr / OCCTDocumentGetColorRGBAAttr).
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("color_rgba_attr_roundtrip_test.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try box.writeSTEP(to: tempURL)
        let doc = try Document.load(from: tempURL)
        let nodes = doc.rootNodes
        #expect(!nodes.isEmpty)

        guard let node = nodes.first else { return }

        let set = node.setColorAttribute(red: 0.5, green: 0.25, blue: 0.75, alpha: 0.4)
        #expect(set)

        let readBack = node.colorRGBAAttribute
        #expect(readBack != nil)
        if let readBack {
            #expect(abs(readBack.red - 0.5) < 1e-6)
            #expect(abs(readBack.green - 0.25) < 1e-6)
            #expect(abs(readBack.blue - 0.75) < 1e-6)
            #expect(abs(readBack.alpha - 0.4) < 1e-6)
        }
    }

    @Test("Set and get label material")
    func setLabelMaterial() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("material_test.step")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try box.writeSTEP(to: tempURL)
        let doc = try Document.load(from: tempURL)
        let nodes = doc.rootNodes
        #expect(!nodes.isEmpty)

        if let node = nodes.first {
            let mat = Material(
                baseColor: Color(red: 0.8, green: 0.2, blue: 0.1),
                metallic: 0.9,
                roughness: 0.3,
                transparency: 0.0
            )
            node.setMaterial(mat)

            let readMat = node.material
            #expect(readMat != nil)
            if let readMat {
                #expect(abs(readMat.metallic - 0.9) < 0.01)
                #expect(abs(readMat.roughness - 0.3) < 0.01)
            }
        }
    }
}
