import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.113.0 Tests

@Suite("v0.113.0 - MakeEdge Completions")
struct MakeEdgeCompletionsTests {

    /// The edge's bounding box, to the 1e-7 enlargement OCCT adds, against `min`/`max`.
    private func expectBox(
        _ edge: Shape, min: SIMD3<Double>, max: SIMD3<Double>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let box = edge.boundingBox else {
            Issue.record("no bounding box", sourceLocation: sourceLocation)
            return
        }
        #expect(vectorLength(box.min - min) < 1e-5, sourceLocation: sourceLocation)
        #expect(vectorLength(box.max - max) < 1e-5, sourceLocation: sourceLocation)
    }

    @Test func edgeFromEllipse() throws {
        let e = try #require(Shape.edgeFromEllipse(majorRadius: 10, minorRadius: 5))
        #expect(e.isValid)
        #expect(e.shapeType == .edge)
        // A full ellipse: one closed edge, perimeter 4 a E(e) = 48.4422411027 (a = 10, b = 5).
        #expect(abs(e.totalEdgeLength - 48.44224110273844) < 1e-6)
        expectBox(e, min: SIMD3(-10, -5, 0), max: SIMD3(10, 5, 0))
    }

    @Test func edgeFromEllipseArc() throws {
        let e = try #require(
            Shape.edgeFromEllipseArc(majorRadius: 10, minorRadius: 5, u1: 0, u2: .pi))
        #expect(e.isValid)
        // Half of the perimeter, 24.2211205514, over the upper half plane.
        #expect(abs(e.totalEdgeLength - 24.221120551368877) < 1e-6)
        expectBox(e, min: SIMD3(-10, 0, 0), max: SIMD3(10, 5, 0))
        let ends = e.vertices()
        #expect(ends.count == 2)
        if ends.count == 2 {
            #expect(vectorLength(ends[0] - SIMD3(10, 0, 0)) < 1e-6)
            #expect(vectorLength(ends[1] - SIMD3(-10, 0, 0)) < 1e-6)
        }
    }

    @Test func edgeFromHyperbolaArc() throws {
        let e = try #require(
            Shape.edgeFromHyperbolaArc(majorRadius: 5, minorRadius: 3, u1: -1.0, u2: 1.0))
        #expect(e.isValid)
        // x = 5 cosh u, y = 3 sinh u over u in [-1, 1]; the length is the integral of
        // sqrt(25 sinh^2 u + 9 cosh^2 u) = 9.16837590768 (Simpson, 20000 panels).
        #expect(abs(e.totalEdgeLength - 9.168375907676) < 1e-6)
        expectBox(
            e, min: SIMD3(5, -3 * sinh(1.0), 0), max: SIMD3(5 * cosh(1.0), 3 * sinh(1.0), 0))
    }

    @Test func edgeFromParabolaArc() throws {
        let e = try #require(Shape.edgeFromParabolaArc(focalLength: 3.0, u1: -5.0, u2: 5.0))
        #expect(e.isValid)
        // y^2 = 4 f x with f = 3: x = u^2 / 12, so the arc ends at x = 25/12; the length is the
        // integral of sqrt(1 + (u/6)^2) over [-5, 5] = 11.0594582198 (Simpson, 20000 panels).
        #expect(abs(e.totalEdgeLength - 11.059458219751) < 1e-6)
        expectBox(e, min: SIMD3(0, -5, 0), max: SIMD3(25.0 / 12.0, 5, 0))
    }

    @Test func edgeFromCurve() throws {
        let circ = try #require(
            Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let e = try #require(Shape.edgeFromCurve(circ))
        #expect(e.shapeType == .edge)
        // The whole circle, 2 pi r, closed on a single vertex.
        #expect(abs(e.totalEdgeLength - 10 * Double.pi) < 1e-9)
        #expect(e.vertices().count == 1)
        expectBox(e, min: SIMD3(-5, -5, 0), max: SIMD3(5, 5, 0))
    }

    @Test func edgeFromCurveWithParams() throws {
        let circ = try #require(
            Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let e = try #require(Shape.edgeFromCurve(circ, u1: 0, u2: .pi))
        // Half the circle, 5 pi, over the upper half plane.
        #expect(abs(e.totalEdgeLength - 5 * Double.pi) < 1e-9)
        #expect(e.vertices().count == 2)
        expectBox(e, min: SIMD3(-5, 0, 0), max: SIMD3(5, 5, 0))
    }

    @Test func edgeFromCurveWithPoints() throws {
        let circ = try #require(
            Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let e = try #require(Shape.edgeFromCurve(circ, from: SIMD3(5, 0, 0), to: SIMD3(0, 5, 0)))
        // The quarter arc between the two points, 2.5 pi, not the 7.5 pi the long way round.
        #expect(abs(e.totalEdgeLength - 2.5 * Double.pi) < 1e-9)
        let ends = e.vertices()
        #expect(ends.count == 2)
        if ends.count == 2 {
            #expect(vectorLength(ends[0] - SIMD3(5, 0, 0)) < 1e-9)
            #expect(vectorLength(ends[1] - SIMD3(0, 5, 0)) < 1e-9)
        }
    }

    @Test func edgeVertices() {
        if let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            if let edge = Shape.edgeFromCurve(circ, u1: 0, u2: .pi) {
                let v1 = edge.edgeVertex1()
                let v2 = edge.edgeVertex2()
                #expect(abs(v1.x - 5.0) < 0.1)
                #expect(abs(v2.x + 5.0) < 0.1)
            }
        }
    }
}
