import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataXtd Triangulation Attribute Tests (v0.56.0)

@Suite("TDataXtd Triangulation Attribute")
struct TDataXtdTriangulationAttributeTests {

    @Test("Set triangulation from meshed shape")
    func setTriangulation() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let sphere = try #require(Shape.sphere(radius: 10.0))

        #expect(label.setTriangulationFromShape(sphere, deflection: 1.0))
        #expect(label.triangulationNodeCount > 0)
        #expect(label.triangulationTriangleCount > 0)
    }

    @Test("Triangulation deflection")
    func triangulationDeflection() throws {
        let doc = try #require(Document.create())
        let label = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))

        #expect(label.setTriangulationFromShape(box, deflection: 0.5))
        #expect(label.triangulationDeflection > 0)
    }
}
