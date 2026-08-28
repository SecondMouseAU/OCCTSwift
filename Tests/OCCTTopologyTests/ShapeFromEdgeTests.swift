import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape.fromEdge, Issue #45") struct ShapeFromEdgeTests {
    @Test("Shape.fromEdge converts edge to shape")
    func edgeToShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let edges = box.edges()
            #expect(edges.count > 0)
            if let firstEdge = edges.first {
                let shape = Shape.fromEdge(firstEdge)
                #expect(shape != nil)
                if let shape {
                    #expect(shape.isValid)
                }
            }
        }
    }

    @Test("anaFillet with Edge parameters")
    func anaFilletWithEdges() {
        let wire = Wire.polygon([
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10),
        ])
        if let wire {
            let edges = wire.edges()
            if edges.count >= 2 {
                let result = Shape.anaFillet(
                    edge1: edges[0], edge2: edges[1], radius: 1.0)
                #expect(result != nil)
            }
        }
    }

    @Test("anaFillet with Wire parameter")
    func anaFilletWithWire() {
        let wire = Wire.polygon([
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10),
        ])
        if let wire {
            let result = Shape.anaFillet(wire: wire, radius: 1.0)
            #expect(result != nil)
        }
    }

    @Test("filletAlgo with Edge parameters")
    func filletAlgoWithEdges() {
        let wire = Wire.polygon([
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10),
        ])
        if let wire {
            let edges = wire.edges()
            if edges.count >= 2 {
                let result = Shape.filletAlgo(
                    edge1: edges[0], edge2: edges[1], radius: 1.0)
                #expect(result != nil)
            }
        }
    }

    @Test("filletAlgo with Wire parameter")
    func filletAlgoWithWire() {
        let wire = Wire.polygon([
            SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10),
        ])
        if let wire {
            let result = Shape.filletAlgo(wire: wire, radius: 1.0)
            #expect(result != nil)
        }
    }
}
