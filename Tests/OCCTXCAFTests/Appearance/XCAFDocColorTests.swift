import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_Color Tests")
struct XCAFDocColorTests {
    @Test func setAndGetRGB() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(label.setColorAttribute(red: 1.0, green: 0.0, blue: 0.0))
                if let c = label.colorAttribute {
                    #expect(abs(c.red - 1.0) < 1e-6)
                    #expect(c.green < 0.01)
                }
            }
        }
    }

    @Test func setAndGetRGBA() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(label.setColorAttribute(red: 0.5, green: 0.6, blue: 0.7, alpha: 0.8))
                if let rgba = label.colorRGBAAttribute {
                    #expect(abs(rgba.alpha - 0.8) < 0.02)
                }
                #expect(abs(label.colorAlphaAttribute - 0.8) < 0.02)
            }
        }
    }

    @Test func namedColor() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                // Quantity_NOC_RED = 485 in OCCT 8
                #expect(label.setColorAttribute(red: 1.0, green: 0.0, blue: 0.0))
                let noc = label.colorNOCAttribute
                #expect(noc >= 0)  // Just verify it returns a valid value
            }
        }
    }
}
