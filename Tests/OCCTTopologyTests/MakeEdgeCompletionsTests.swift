import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.113.0 Tests

@Suite("v0.113.0 - MakeEdge Completions")
struct MakeEdgeCompletionsTests {

    @Test func edgeFromEllipse() {
        let edge = Shape.edgeFromEllipse(majorRadius: 10, minorRadius: 5)
        #expect(edge != nil)
        if let e = edge {
            #expect(e.isValid)
        }
    }

    @Test func edgeFromEllipseArc() {
        let edge = Shape.edgeFromEllipseArc(majorRadius: 10, minorRadius: 5, u1: 0, u2: .pi)
        #expect(edge != nil)
        if let e = edge {
            #expect(e.isValid)
        }
    }

    @Test func edgeFromHyperbolaArc() {
        let edge = Shape.edgeFromHyperbolaArc(majorRadius: 5, minorRadius: 3, u1: -1.0, u2: 1.0)
        #expect(edge != nil)
        if let e = edge {
            #expect(e.isValid)
        }
    }

    @Test func edgeFromParabolaArc() {
        let edge = Shape.edgeFromParabolaArc(focalLength: 3.0, u1: -5.0, u2: 5.0)
        #expect(edge != nil)
        if let e = edge {
            #expect(e.isValid)
        }
    }

    @Test func edgeFromCurve() {
        if let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            let edge = Shape.edgeFromCurve(circ)
            #expect(edge != nil)
        }
    }

    @Test func edgeFromCurveWithParams() {
        if let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            let edge = Shape.edgeFromCurve(circ, u1: 0, u2: .pi)
            #expect(edge != nil)
        }
    }

    @Test func edgeFromCurveWithPoints() {
        if let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            let edge = Shape.edgeFromCurve(circ, from: SIMD3(5, 0, 0), to: SIMD3(0, 5, 0))
            #expect(edge != nil)
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
