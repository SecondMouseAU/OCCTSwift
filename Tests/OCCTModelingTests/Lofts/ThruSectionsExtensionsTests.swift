import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.123.0: Builder extensions, Section ops, Curve/Surface queries

// #3332: the setters were called, a `build()` result discarded, and `ts.shape != nil` asserted
// under `if let` on both circles. Every variant lofts the same two coaxial circles (r = 5 at
// z = 0, r = 3 at z = 10), so every one must give the cone frustum, V = 513.127. A parameter
// type or criterion weight that is ignored gives the same shape (they only matter for sections
// that are not coaxial circles), so what these pin is that setting them does not spoil the loft
// and that a rejected weight leaves the builder usable.
@Suite("v0.123.0, ThruSections extensions")
struct ThruSectionsExtensionsTests {
    private let frustum = Double.pi * 10 / 3 * (25 + 15 + 9)

    private func sections() throws -> (Shape, Shape) {
        let w1 = try #require(Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 5.0))
        let w2 = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3.0))
        return (try #require(Shape.fromWire(w1)), try #require(Shape.fromWire(w2)))
    }

    private func expectFrustum(_ ts: ThruSectionsBuilder, _ label: String) throws {
        let shape = try #require(ts.shape, Comment(rawValue: label))
        #expect(shape.isValid, Comment(rawValue: label))
        #expect(shape.shapeType == .solid, Comment(rawValue: label))
        #expect(shape.faceCount == 3, Comment(rawValue: label))
        let volume = try #require(shape.volume)
        #expect(abs(volume - frustum) < 1e-3, Comment(rawValue: label))
    }

    @Test("CheckCompatibility sets without crash")
    func checkCompatibility() throws {
        let (ws1, ws2) = try sections()
        for check in [true, false] {
            let ts = ThruSectionsBuilder(isSolid: true)
            ts.checkCompatibility(check)
            ts.addWire(ws1)
            ts.addWire(ws2)
            #expect(ts.build(), "checkCompatibility: \(check)")
            try expectFrustum(ts, "checkCompatibility: \(check)")
        }
    }

    @Test("SetParType parameterization")
    func setParType() throws {
        let (ws1, ws2) = try sections()
        // 0 chord length, 1 centripetal, 2 approximation (BRepFill's Approx_ParametrizationType).
        for parType in 0...2 {
            let ts = ThruSectionsBuilder(isSolid: true)
            ts.setParType(parType)
            ts.addWire(ws1)
            ts.addWire(ws2)
            #expect(ts.build(), "parType: \(parType)")
            try expectFrustum(ts, "parType: \(parType)")
        }
    }

    @Test("SetCriteriumWeight")
    func setCriteriumWeight() throws {
        let (ws1, ws2) = try sections()
        let ts = ThruSectionsBuilder(isSolid: true)
        #expect(ts.setCriteriumWeight(w1: 1.0, w2: 1.0, w3: 1.0) == true)
        ts.addWire(ws1)
        ts.addWire(ws2)
        #expect(ts.build())
        try expectFrustum(ts, "unit weights")

        // Different (positive) weights are accepted and give the same coaxial loft.
        let weighted = ThruSectionsBuilder(isSolid: true)
        #expect(weighted.setCriteriumWeight(w1: 0.5, w2: 2.0, w3: 3.0) == true)
        weighted.addWire(ws1)
        weighted.addWire(ws2)
        #expect(weighted.build())
        try expectFrustum(weighted, "weights 0.5, 2, 3")
    }

    @Test("SetCriteriumWeight rejects negative weights")
    func setCriteriumWeightRejectsNegative() {
        let ts = ThruSectionsBuilder(isSolid: true)
        #expect(ts.setCriteriumWeight(w1: -1.0, w2: 1.0, w3: 1.0) == false)
        #expect(ts.setCriteriumWeight(w1: 1.0, w2: -1.0, w3: 1.0) == false)
        #expect(ts.setCriteriumWeight(w1: 1.0, w2: 1.0, w3: -1.0) == false)
        #expect(ts.setCriteriumWeight(w1: -1.0, w2: -1.0, w3: -1.0) == false)
        // Verify builder still works after rejection
        #expect(ts.setCriteriumWeight(w1: 1.0, w2: 1.0, w3: 1.0) == true)
    }

    // The face generated from an edge of the FIRST section is the loft's lateral face: the cone
    // frustum surface, area pi (5 + 3) sqrt(100 + 4) = 256.305, one face (measured). An edge that
    // belongs to no section generates nothing.
    @Test("GeneratedFace from edge")
    func generatedFace() throws {
        let (ws1, ws2) = try sections()
        let ts = ThruSectionsBuilder(isSolid: true)
        ts.addWire(ws1)
        ts.addWire(ws2)
        #expect(ts.build())

        let edges = ws1.subShapes(ofType: .edge)
        #expect(edges.count == 1)
        let edge = try #require(edges.first)
        let face = try #require(ts.generatedFace(from: edge))
        #expect(face.shapeType == .face)
        #expect(face.isValid)
        let area = try #require(face.surfaceArea)
        #expect(abs(area - Double.pi * 8 * 104.0.squareRoot()) < 1e-3)

        let cube = try #require(Shape.box(width: 3, height: 3, depth: 3))
        let stray = try #require(cube.subShapes(ofType: .edge).first)
        #expect(ts.generatedFace(from: stray) == nil)
    }
}
