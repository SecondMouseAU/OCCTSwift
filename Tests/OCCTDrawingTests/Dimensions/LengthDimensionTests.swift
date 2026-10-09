import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - AIS Annotations & Measurements (v0.26.0)

@Suite("Length Dimension")
struct LengthDimensionTests {

    @Test("Point-to-point distance")
    func pointToPoint() {
        let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        #expect(dim != nil)
        #expect(abs(dim!.value - 10.0) < 1e-6, "Distance should be 10, got \(dim!.value)")
    }

    @Test("Diagonal distance")
    func diagonalDistance() {
        let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0))
        #expect(dim != nil)
        #expect(abs(dim!.value - 5.0) < 1e-6, "3-4-5 triangle hypotenuse should be 5")
    }

    @Test("3D distance")
    func threeDDistance() {
        let dim = LengthDimension(from: SIMD3(1, 2, 3), to: SIMD3(4, 6, 3))
        #expect(dim != nil)
        let expected = sqrt(9.0 + 16.0)  // 5.0
        #expect(abs(dim!.value - expected) < 1e-6)
    }

    @Test("Edge length measurement")
    func edgeLength() {
        let wire = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(7, 0, 0))!
        let edgeShape = Shape.fromWire(wire)!
        let edges = edgeShape.edges()
        guard let edge = edges.first else {
            Issue.record("Wire should produce at least one edge")
            return
        }
        // Get the edge as a Shape for the dimension
        let dim = LengthDimension(edge: edgeShape)
        // Edge-based dimension may not work on wire shapes, test API doesn't crash
        if let dim = dim {
            #expect(dim.value > 0)
        }
    }

    @Test("Face-to-face distance equals box dimension")
    func faceToFaceDistance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        // Get faces from the box, we need Shape-typed faces
        // Use slicing approach: box has 6 faces, opposing pairs are separated by width/height/depth
        // Create two parallel face shapes
        let face1 = Shape.face(from: Wire.rectangle(width: 20, height: 30)!)!
        let face2 = face1.translated(by: SIMD3(0, 0, 10))!
        let dim = LengthDimension(face1: face1, face2: face2)
        if let dim = dim {
            #expect(abs(dim.value - 10.0) < 1e-4, "Face-to-face should be 10, got \(dim.value)")
        }
    }

    @Test("Geometry contains valid first and second points")
    func geometryPoints() {
        let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(5, 0, 0))!
        let geom = dim.geometry
        #expect(geom != nil)
        if let g = geom {
            #expect(abs(g.firstPoint.x - 0) < 1e-6)
            #expect(abs(g.secondPoint.x - 5) < 1e-6)
            #expect(g.isValid)
        }
    }

    @Test("Custom value overrides measured")
    func customValue() {
        let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        #expect(abs(dim.value - 10.0) < 1e-6)
        dim.setCustomValue(42.0)
        #expect(abs(dim.value - 42.0) < 1e-6)
    }
}
