import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - AIS Annotations & Measurements (v0.26.0)

// #766: the three point tests force-unwrapped `dim!` inside `#expect`, which crashes the run on a
// nil instead of failing the test; the edge and face tests skipped their only assertion on a nil
// dimension (`if let`), and the edge test could never reach it: it passed a wire-typed shape,
// which `OCCTDimensionCreateLengthFromEdge` refuses, so it passed without measuring anything.
// Values are PrsDim_LengthDimension's, measured in
// Scripts/repro/766-drawing-length-normalproj/transcript.txt.
@Suite("Length Dimension")
struct LengthDimensionTests {

    @Test("Point-to-point distance")
    func pointToPoint() {
        guard let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("LengthDimension(from:to:) returned nil")
            return
        }
        #expect(abs(dim.value - 10.0) < 1e-6, "Distance should be 10, got \(dim.value)")
    }

    @Test("Diagonal distance")
    func diagonalDistance() {
        guard let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0)) else {
            Issue.record("LengthDimension(from:to:) returned nil")
            return
        }
        #expect(abs(dim.value - 5.0) < 1e-6, "3-4-5 triangle hypotenuse should be 5")
    }

    @Test("3D distance")
    func threeDDistance() {
        guard let dim = LengthDimension(from: SIMD3(1, 2, 3), to: SIMD3(4, 6, 3)) else {
            Issue.record("LengthDimension(from:to:) returned nil")
            return
        }
        let expected = sqrt(9.0 + 16.0)  // 5.0
        #expect(abs(dim.value - expected) < 1e-6)
    }

    @Test("Edge length measurement")
    func edgeLength() {
        guard let wire = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(7, 0, 0)),
            let edge = Shape.fromWire(wire)?.edges().first,
            let edgeShape = Shape.fromEdge(edge)
        else {
            Issue.record("Wire should produce at least one edge")
            return
        }
        // The dimension takes an edge-typed shape; the wire the line was built as is refused.
        guard let dim = LengthDimension(edge: edgeShape) else {
            Issue.record("LengthDimension(edge:) returned nil for a 7-unit edge")
            return
        }
        #expect(abs(dim.value - 7.0) < 1e-9, "edge length should be 7, got \(dim.value)")
    }

    @Test("Face-to-face distance equals box dimension")
    func faceToFaceDistance() {
        // Two parallel 20 x 30 faces, 10 apart.
        guard let face1 = Wire.rectangle(width: 20, height: 30).flatMap({ Shape.face(from: $0) }),
            let face2 = face1.translated(by: SIMD3(0, 0, 10))
        else {
            Issue.record("face fixture failed")
            return
        }
        guard let dim = LengthDimension(face1: face1, face2: face2) else {
            Issue.record("LengthDimension(face1:face2:) returned nil for two parallel faces")
            return
        }
        #expect(abs(dim.value - 10.0) < 1e-4, "Face-to-face should be 10, got \(dim.value)")
    }

    @Test("Geometry contains valid first and second points")
    func geometryPoints() {
        guard let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(5, 0, 0)) else {
            Issue.record("LengthDimension(from:to:) returned nil")
            return
        }
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
        guard let dim = LengthDimension(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)) else {
            Issue.record("LengthDimension(from:to:) returned nil")
            return
        }
        #expect(abs(dim.value - 10.0) < 1e-6)
        dim.setCustomValue(42.0)
        #expect(abs(dim.value - 42.0) < 1e-6)
    }
}
