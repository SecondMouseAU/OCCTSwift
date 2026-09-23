import Foundation
import Testing
import simd

@testable import OCCTSwift

// Counts and thicknesses are BRepMAT2d_BisectingLocus's on the same faces; see
// Scripts/repro/766-medial-axis/transcript.txt. The suite-wide `.disabled` this carried is now on
// the one test that crashes.
@Suite("Medial Axis, Various Shapes")
struct MedialAxisVariousShapesTests {

    @Test("Square medial axis has symmetric structure")
    func squareMedialAxis() {
        let wire = Wire.rectangle(width: 6, height: 6)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis for square")
            return
        }
        // Square should have arcs and nodes
        #expect(ma.arcCount > 0)
        #expect(ma.nodeCount > 0)
        // Min thickness = half of side = 3.0
        let minT = ma.minThickness
        #expect(abs(minT - 3.0) < 0.1, "Expected min thickness ~3.0 for 6x6 square, got \(minT)")
    }

    @Test("L-shaped polygon produces medial axis")
    func lShapedMedialAxis() {
        let wire = Wire.polygon(
            [
                SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 4),
                SIMD2(4, 4), SIMD2(4, 8), SIMD2(0, 8),
            ], closed: true)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis for L-shape")
            return
        }
        // L-shape has more arcs than a simple rectangle
        #expect(ma.arcCount == 11, "L-shape should have 11 arcs, got \(ma.arcCount)")
        #expect(ma.nodeCount == 12)
    }

    // BRepMAT2d on a face bounded by one full circle is an uncatchable SIGSEGV inside OCCT: the
    // probe runs it in a child process, which dies on signal 11 before the locus is computed.
    // Enabling this test would take down the whole test process, as it did the two suites.
    // Scripts/repro/766-medial-axis reproduces it in plain C++.
    @Test(
        "Circle face produces medial axis with single central node",
        .disabled("BRepMAT2d_BisectingLocus segfaults on a single-circle boundary"))
    func circleMedialAxis() {
        let wire = Wire.circle(radius: 5)!
        let face = Shape.face(from: wire)!
        let ma = MedialAxis(of: face)
        // Circle medial axis is a single point (center), may compute as degenerate
        if let ma = ma {
            #expect(ma.nodeCount >= 1)
            let minT = ma.minThickness
            #expect(minT > 0)
        }
    }

    @Test("Narrow rectangle has small min thickness")
    func narrowRectangle() {
        let wire = Wire.rectangle(width: 20, height: 1)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis for narrow rectangle")
            return
        }
        let minT = ma.minThickness
        #expect(minT > 0)
        #expect(abs(minT - 0.5) < 0.1, "Expected min thickness ~0.5 for 20x1 rect, got \(minT)")
    }

    @Test("Triangle produces medial axis")
    func triangleMedialAxis() {
        let wire = Wire.polygon(
            [
                SIMD2(0, 0), SIMD2(10, 0), SIMD2(5, 8),
            ], closed: true)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis for triangle")
            return
        }
        // Triangle medial axis has 3 arcs (one from each vertex bisector) meeting at the incentre
        #expect(ma.arcCount == 3, "Triangle should have 3 arcs, got \(ma.arcCount)")
        #expect(ma.nodeCount == 4)
    }

    @Test("Nil for shape without faces")
    func noFaceFails() {
        let wire = Wire.rectangle(width: 5, height: 5)!
        let wireShape = Shape.fromWire(wire)!
        let ma = MedialAxis(of: wireShape)
        #expect(ma == nil, "Medial axis should fail for wireframe shape")
    }

    @Test("Node accessor out of bounds returns nil")
    func nodeOutOfBounds() throws {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        let ma = try #require(MedialAxis(of: face))
        #expect(ma.node(at: 0) == nil, "Index 0 should be out of bounds (1-based)")
        #expect(ma.node(at: ma.nodeCount + 1) == nil, "Past-end index should be nil")
    }

    @Test("Arc accessor out of bounds returns nil")
    func arcOutOfBounds() throws {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        let ma = try #require(MedialAxis(of: face))
        #expect(ma.arc(at: 0) == nil, "Index 0 should be out of bounds (1-based)")
        #expect(ma.arc(at: ma.arcCount + 1) == nil, "Past-end index should be nil")
    }

    @Test("Distance on arc with invalid index returns -1")
    func distanceInvalidArc() throws {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        let ma = try #require(MedialAxis(of: face))
        #expect(ma.distanceToBoundary(arcIndex: 0, parameter: 0.5) == -1.0)
        #expect(ma.distanceToBoundary(arcIndex: ma.arcCount + 1, parameter: 0.5) == -1.0)
    }

    @Test("Draw arc with invalid index returns empty")
    func drawArcInvalidIndex() throws {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        let ma = try #require(MedialAxis(of: face))
        #expect(ma.drawArc(at: 0).isEmpty)
        #expect(ma.drawArc(at: ma.arcCount + 1).isEmpty)
    }

    @Test("Medial axis nodes lie inside the shape boundary")
    func nodesInsideBoundary() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        // Rectangle is centered at origin: x in [-5, 5], y in [-2, 2]
        for node in ma.nodes {
            #expect(
                node.position.x >= -5.1 && node.position.x <= 5.1,
                "Node x=\(node.position.x) outside rectangle bounds")
            #expect(
                node.position.y >= -2.1 && node.position.y <= 2.1,
                "Node y=\(node.position.y) outside rectangle bounds")
        }
    }
}
