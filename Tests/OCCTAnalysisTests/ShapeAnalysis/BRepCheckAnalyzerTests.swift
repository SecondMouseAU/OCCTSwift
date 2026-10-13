import Foundation
import Testing

@testable import OCCTSwift

@Suite("BRepCheck Analyzer Tests")
struct BRepCheckAnalyzerTests {
    /// A planar face over a self-crossing (bow-tie) wire: `BRepCheck_Analyzer` rejects it at
    /// both geometric-check settings, which is the control that stops an analyzer answering
    /// "valid" to everything from passing the three solids below.
    private func bowTie() throws -> Shape {
        let wire = try #require(
            Wire.polygon(
                [SIMD2(0, 0), SIMD2(10, 10), SIMD2(10, 0), SIMD2(0, 10)], closed: true))
        return try #require(Shape.face(from: wire))
    }

    private func expectDistinguishes(_ valid: Shape, _ what: String) throws {
        #expect(valid.analyzeValidity(), "\(what) is valid")
        #expect(
            valid.analyzeValidity(geometryChecks: false),
            "\(what) is valid without geometry checks")
        let bad = try bowTie()
        #expect(!bad.analyzeValidity(), "a bow-tie face is not valid")
        #expect(!bad.analyzeValidity(geometryChecks: false), "nor without geometry checks")
    }

    @Test("Box passes analyzer validation")
    func boxValid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        try expectDistinguishes(box, "box")
    }

    @Test("Sphere passes analyzer validation")
    func sphereValid() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        try expectDistinguishes(sphere, "sphere")
    }

    @Test("Cylinder passes analyzer validation")
    func cylinderValid() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        try expectDistinguishes(cyl, "cylinder")
    }

    @Test("Analyzer without geometry checks")
    func noGeomChecks() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.analyzeValidity(geometryChecks: false))
    }
}
