import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataXtd Point/Axis/Plane Attribute Tests (v0.56.0)

@Suite("TDataXtd Point/Axis/Plane Attributes")
struct TDataXtdGeometricAttrTests {

    @Test("Set point attribute")
    func setPoint() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        #expect(label.setPointAttribute(x: 5.0, y: 10.0, z: 15.0))
    }

    @Test("Set axis attribute")
    func setAxis() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        #expect(
            label.setAxisAttribute(
                originX: 0, originY: 0, originZ: 0,
                directionX: 0, directionY: 0, directionZ: 1))
    }

    @Test("Set plane attribute")
    func setPlane() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        #expect(
            label.setPlaneAttribute(
                originX: 0, originY: 0, originZ: 0,
                normalX: 0, normalY: 0, normalZ: 1))
    }
}
