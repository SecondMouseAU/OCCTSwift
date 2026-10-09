import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataXtd Triangulation Attribute Tests (v0.56.0)

@Suite("TDataXtd Triangulation Attribute")
struct TDataXtdTriangulationAttributeTests {

    @Test("Set triangulation from meshed shape")
    func setTriangulation() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let sphere = Shape.sphere(radius: 10.0)!

        #expect(label.setTriangulationFromShape(sphere, deflection: 1.0))
        #expect(label.triangulationNodeCount > 0)
        #expect(label.triangulationTriangleCount > 0)
    }

    @Test("Triangulation deflection")
    func triangulationDeflection() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 20, depth: 30)!

        #expect(label.setTriangulationFromShape(box, deflection: 0.5))
        #expect(label.triangulationDeflection > 0)
    }
}
