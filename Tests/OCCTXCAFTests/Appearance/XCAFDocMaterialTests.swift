import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_Material Tests")
struct XCAFDocMaterialTests {
    @Test func setAndGet() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(
                    label.setMaterialAttribute(
                        name: "Steel", description: "Carbon steel",
                        density: 7850.0, densityName: "density",
                        densityValueType: "kg/m3"))
                #expect(label.hasMaterialAttribute)
                #expect(label.materialAttributeName == "Steel")
                #expect(label.materialAttributeDescription == "Carbon steel")
                if let d = label.materialAttributeDensity {
                    #expect(abs(d - 7850.0) < 1e-6)
                }
            }
        }
    }

    @Test func noMaterial() throws {
        let doc = try #require(Document.create())
        let main = try #require(doc.mainLabel)
        let label = try #require(doc.createLabel(parent: main))
        #expect(!label.hasMaterialAttribute)
        #expect(label.materialAttributeName == nil)
    }
}
