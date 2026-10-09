import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepCheck Analyzer Tests")
struct BRepCheckAnalyzerTests {
    @Test("Box passes analyzer validation")
    func boxValid() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.analyzeValidity())
    }

    @Test("Sphere passes analyzer validation")
    func sphereValid() throws {
        let sphere = Shape.sphere(radius: 5)!
        #expect(sphere.analyzeValidity())
    }

    @Test("Cylinder passes analyzer validation")
    func cylinderValid() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        #expect(cyl.analyzeValidity())
    }

    @Test("Analyzer without geometry checks")
    func noGeomChecks() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.analyzeValidity(geometryChecks: false))
    }
}
