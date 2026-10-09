import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataXtd Geometry Attribute Tests (v0.56.0)

@Suite("TDataXtd Geometry Attribute")
struct TDataXtdGeometryAttributeTests {

    @Test("Set and get geometry type")
    func setGetGeometryType() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        #expect(label.setGeometryType(.point))
        #expect(label.hasGeometryAttribute)
        #expect(label.geometryType() == .point)

        #expect(label.setGeometryType(.plane))
        #expect(label.geometryType() == .plane)

        #expect(label.setGeometryType(.cylinder))
        #expect(label.geometryType() == .cylinder)
    }

    @Test("All geometry type values")
    func allGeometryTypes() {
        let doc = Document.create()!
        let types: [GeometryType] = [
            .anyGeom, .point, .line, .circle, .ellipse, .spline, .plane, .cylinder,
        ]
        for type in types {
            let label = doc.createLabel()!
            #expect(label.setGeometryType(type))
            #expect(label.geometryType() == type)
        }
    }
}
