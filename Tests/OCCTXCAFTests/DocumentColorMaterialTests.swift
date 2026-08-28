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
