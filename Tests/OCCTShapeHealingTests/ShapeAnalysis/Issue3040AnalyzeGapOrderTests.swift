import Foundation
import Testing

@testable import OCCTSwift

/// `Shape.analyze(tolerance:)` must not count the stored order of a wire as a gap.
///
/// Filed as #3040. `ShapeAnalysis_Wire::CheckGap3d(i)` compares edge i's end with the start of the
/// edge stored next, so on a wire whose edges are not stored in connection order, which is every
/// face of a primitive, it measured the face diagonal and a flawless box read 24 gaps and
/// `isHealthy == false` at every tolerance. `OCCTShapeAnalyze` now orders the wire first, as
/// `ShapeFix_Wire::Perform` does (`ShapeFix_Wire.cxx:312`), before it counts.
///
/// The controls matter as much as the primitives: a change that zeroed `gapCount` for everything
/// would pass every primitive below, so each real-gap case pins a gap that must still be found.
@Suite("Issue 3040: analyze counts gaps on an ordered wire")
struct Issue3040AnalyzeGapOrder {

    private static let corners: [SIMD3<Double>] = [
        SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
    ]

    private func expectHealthy(_ shape: Shape, tolerance: Double, _ label: String) throws {
        let a = try #require(shape.analyze(tolerance: tolerance), "\(label): analyze returned nil")
        #expect(a.gapCount == 0, "\(label): gapCount at \(tolerance)")
        #expect(a.freeEdgeCount == 0, "\(label): freeEdgeCount at \(tolerance)")
        #expect(a.smallEdgeCount == 0, "\(label): smallEdgeCount at \(tolerance)")
        #expect(a.smallFaceCount == 0, "\(label): smallFaceCount at \(tolerance)")
        #expect(!a.hasInvalidTopology, "\(label): hasInvalidTopology at \(tolerance)")
        #expect(a.totalProblems == 0, "\(label): totalProblems at \(tolerance)")
        #expect(a.isHealthy, "\(label): isHealthy at \(tolerance)")
    }

    @Test("a primitive box is healthy at every tolerance")
    func boxIsHealthy() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for tolerance in [1e-6, 1e-3, 1.0] {
            try expectHealthy(box, tolerance: tolerance, "box")
        }
    }

    @Test("each face of a box is gap-free on its own")
    func boxFacesAreGapFree() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        for (i, face) in faces.enumerated() {
            let a = try #require(face.analyze(tolerance: 1e-6), "face \(i): analyze returned nil")
            #expect(a.gapCount == 0, "face \(i): gapCount")
            #expect(a.isHealthy, "face \(i): isHealthy")
        }
    }

    @Test("a primitive cylinder is healthy")
    func cylinderIsHealthy() throws {
        try expectHealthy(
            try #require(Shape.cylinder(radius: 3, height: 10)), tolerance: 1e-6, "cylinder")
    }

    @Test("a primitive sphere is healthy")
    func sphereIsHealthy() throws {
        try expectHealthy(
            try #require(Shape.sphere(radius: 5)), tolerance: 1e-6, "sphere")
    }

    @Test("a polygon face is healthy (the control that was always in order)")
    func polygonFaceIsHealthy() throws {
        let outer = try #require(Wire.polygon3D(Self.corners, closed: true))
        try expectHealthy(try #require(Shape.face(from: outer)), tolerance: 1e-6, "polygon face")
    }

    /// Four line edges of the 10x10 square, the last corner pulled `gap` away from the start of
    /// the edge that follows it, added to a raw wire in the given order.
    private func squareFace(order: [Int], gap: Double) throws -> Shape {
        // Edge i runs corners[i] -> corners[i+1]. Edge 3 ends where edge 0 starts, so shifting
        // edge 3's end by `gap` opens exactly one junction.
        var pts = Self.corners
        pts.append(SIMD3(0, gap, 0))
        var edges: [Shape] = []
        for i in 0..<4 {
            let w = try #require(Wire.line(from: pts[i], to: pts[i + 1]))
            let e = try #require(w.edges().first)
            edges.append(try #require(Shape.fromEdge(e)))
        }
        let raw = try #require(Shape.builderMakeWire())
        for i in order { raw.builderAdd(edges[i]) }
        let wire = try #require(Wire(raw))
        return try #require(Shape.face(from: wire, planar: true))
    }

    @Test("an unordered wire with no gap measures none")
    func unorderedWireWithoutGap() throws {
        let face = try squareFace(order: [0, 2, 1, 3], gap: 0)
        let a = try #require(face.analyze(tolerance: 0.01))
        #expect(a.gapCount == 0)
    }

    @Test("an unordered wire with one real gap still reports exactly that gap")
    func unorderedWireWithRealGap() throws {
        let face = try squareFace(order: [0, 2, 1, 3], gap: 0.5)
        let a = try #require(face.analyze(tolerance: 0.01))
        #expect(a.gapCount == 1, "one junction is 0.5 apart, which is more than 0.01")
        #expect(!a.isHealthy)
        // The same gap is below a tolerance of 1.0, so it is the tolerance that decides, as it
        // does for an ordered wire.
        let loose = try #require(face.analyze(tolerance: 1.0))
        #expect(loose.gapCount == 0)
    }

    @Test("an ordered wire with the same gap reports the same count")
    func orderedWireWithRealGap() throws {
        let face = try squareFace(order: [0, 1, 2, 3], gap: 0.5)
        let a = try #require(face.analyze(tolerance: 0.01))
        #expect(a.gapCount == 1)
    }
}
