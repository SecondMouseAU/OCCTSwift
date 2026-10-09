import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.83.0: XDE Attributes Tests

@Suite("XCAFDoc_Location Tests")
struct XCAFDocLocationTests {
    @Test func setAndGetLocation() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                let ok = label.setLocationTranslation(x: 10, y: 20, z: 30)
                #expect(ok)
                #expect(label.hasLocationAttribute)
                if let loc = label.locationTranslation {
                    #expect(abs(loc.x - 10) < 1e-6)
                    #expect(abs(loc.y - 20) < 1e-6)
                    #expect(abs(loc.z - 30) < 1e-6)
                }
            }
        }
    }

    @Test func noLocation() {
        if let doc = Document.create(), let main = doc.mainLabel {
            if let label = doc.createLabel(parent: main) {
                #expect(!label.hasLocationAttribute)
                #expect(label.locationTranslation == nil)
            }
        }
    }
}
