import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis_Wire Tests")
struct SAWireAnalysisTests {

    @Test func basicWireChecks() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    // These return true if problems found; for a good box, expect no problems
                    let _ = SAWireAnalysis.checkOrder(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkConnected(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkSmall(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkDegenerated(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkClosed(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkGaps3d(wire: wire, face: face)
                }
            }
        }
    }

    @Test func wireEdgeCount() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let count = SAWireAnalysis.edgeCount(wire: wire, face: face)
                    #expect(count == 4)
                }
            }
        }
    }

    @Test func wireDistance3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let minD = SAWireAnalysis.minDistance3d(wire: wire, face: face)
                    let maxD = SAWireAnalysis.maxDistance3d(wire: wire, face: face)
                    #expect(minD >= 0)
                    #expect(maxD >= 0)
                }
            }
        }
    }

    @Test func wireDistance2d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let minD = SAWireAnalysis.minDistance2d(wire: wire, face: face)
                    let maxD = SAWireAnalysis.maxDistance2d(wire: wire, face: face)
                    #expect(minD >= 0)
                    #expect(maxD >= 0)
                }
            }
        }
    }

    @Test func wireSelfIntersection() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let selfInt = SAWireAnalysis.checkSelfIntersection(wire: wire, face: face)
                    #expect(!selfInt)
                }
            }
        }
    }

    @Test func wireEdgeCurves() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let _ = SAWireAnalysis.checkEdgeCurves(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkLacking(wire: wire, face: face)
                }
            }
        }
    }

    @Test func wirePerEdgeChecks() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let _ = SAWireAnalysis.checkConnectedEdge(wire: wire, face: face, edgeIndex: 1)
                    let _ = SAWireAnalysis.checkSmallEdge(wire: wire, face: face, edgeIndex: 1)
                    let _ = SAWireAnalysis.checkDegeneratedEdge(
                        wire: wire, face: face, edgeIndex: 1)
                    let _ = SAWireAnalysis.checkGap3dEdge(wire: wire, face: face, edgeIndex: 1)
                }
            }
        }
    }

    @Test func wireGaps2d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let _ = SAWireAnalysis.checkGaps2d(wire: wire, face: face)
                }
            }
        }
    }

    @Test func outerBound() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first, let wire = face.subShapes(ofType: .wire).first {
                // True means "problem found", matching every sibling. A box face's own wire is
                // its outer bound, so there is no problem to report (#999). False rather than
                // nil, since nil is now reserved for a check that could not run (#1058).
                #expect(SAWireAnalysis.checkOuterBound(wire: wire, face: face) == false)
            }
        }
    }
}
