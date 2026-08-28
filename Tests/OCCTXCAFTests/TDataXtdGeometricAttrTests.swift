import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataXtd Point/Axis/Plane Attribute Tests (v0.56.0)

@Suite("TDataXtd Point/Axis/Plane Attributes")
struct TDataXtdGeometricAttrTests {

    @Test("Set point attribute")
    func setPoint() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(label.setPointAttribute(x: 5.0, y: 10.0, z: 15.0))
    }

    @Test("Set axis attribute")
    func setAxis() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(
            label.setAxisAttribute(
                originX: 0, originY: 0, originZ: 0,
                directionX: 0, directionY: 0, directionZ: 1))
    }

    @Test("Set plane attribute")
    func setPlane() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        #expect(
            label.setPlaneAttribute(
                originX: 0, originY: 0, originZ: 0,
                normalX: 0, normalY: 0, normalZ: 1))
    }
}
