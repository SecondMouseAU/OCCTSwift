import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepTools/BRepLib Utilities Tests")
struct BRepToolsUtilitiesTests {

    @Test func clean() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.clean()
            // No crash = pass
        }
    }

    @Test func cleanGeometry() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.cleanGeometry()
        }
    }

    @Test func removeUnusedPCurves() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.removeUnusedPCurves()
        }
    }

    @Test func updateShape() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.updateShape()
        }
    }

    @Test func updateTolerances() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.updateTolerances()
        }
    }

    @Test func updateInnerTolerances() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            box.updateInnerTolerances()
        }
    }

    @Test func buildCurve3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ok = Shape.buildCurve3d(edge: edge)
                let _ = ok
            }
        }
    }

    @Test func checkSameRange() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ok = Shape.checkSameRange(edge: edge)
                let _ = ok
            }
        }
    }

    @Test func sameRange() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ok = Shape.sameRange(edge: edge)
                let _ = ok
            }
        }
    }

    @Test func updateEdgeTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let ok = Shape.updateEdgeTolerance(edge: edge, tolerance: 1e-4)
                let _ = ok
            }
        }
    }
}
