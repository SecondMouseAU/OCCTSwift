import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataXtd Position Attribute Tests (v0.56.0)

@Suite("TDataXtd Position Attribute")
struct TDataXtdPositionAttributeTests {

    @Test("Set and get position attribute")
    func setGetPosition() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        #expect(label.setPositionAttribute(x: 1.0, y: 2.0, z: 3.0))
        #expect(label.hasPositionAttribute)
        if let pos = label.positionAttribute() {
            #expect(abs(pos.x - 1.0) < 1e-10)
            #expect(abs(pos.y - 2.0) < 1e-10)
            #expect(abs(pos.z - 3.0) < 1e-10)
        }
    }

    @Test("Label without position attribute")
    func noPositionAttribute() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(!label.hasPositionAttribute)
        #expect(label.positionAttribute() == nil)
    }
}
