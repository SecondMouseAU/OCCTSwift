import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRep_Tool_Extras")
struct BRepToolExtrasTests {
    @Test func edgeSameParameter() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            if !edges.isEmpty {
                #expect(edges[0].edgeSameParameter)
            }
        }
    }

    @Test func edgeSameRange() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            if !edges.isEmpty {
                #expect(edges[0].edgeSameRange)
            }
        }
    }

    @Test func faceNaturalRestriction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if !faces.isEmpty {
                // Box faces may or may not have natural restriction
                let _ = faces[0].faceNaturalRestriction
            }
        }
    }

    @Test func edgeIsGeometric() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            if !edges.isEmpty {
                #expect(edges[0].edgeIsGeometric)
            }
        }
    }

    @Test func faceIsGeometric() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if !faces.isEmpty {
                #expect(faces[0].faceIsGeometric)
            }
        }
    }
}
