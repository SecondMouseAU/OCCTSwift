import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Edge Analysis")
struct EdgeAnalysisTests {
    @Test("Box edges have 3D curves")
    func boxEdgesHaveCurves() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        #expect(edges.count == 12)
        for edge in edges {
            #expect(edge.hasCurve3D)
        }
    }

    @Test("Box edges are not closed")
    func boxEdgesNotClosed() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        for edge in box.edges() {
            #expect(!edge.isClosed3D)
        }
    }

    @Test("Circle edge is closed")
    func circleEdgeClosed() {
        let circle = Wire.circle(radius: 5)!
        let face = Shape.face(from: circle)!
        let edges = face.edges()
        // The circular edge should be closed
        let hasClosedEdge = edges.contains(where: { $0.isClosed3D })
        #expect(hasClosedEdge)
    }

    @Test("Cylinder has seam edge")
    func cylinderSeamEdge() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let faces = cyl.faces()
        let edges = cyl.edges()
        // At least one edge should be a seam on a face
        var foundSeam = false
        for face in faces {
            for edge in edges {
                if edge.isSeam(on: face) {
                    foundSeam = true
                    break
                }
            }
            if foundSeam { break }
        }
        #expect(foundSeam)
    }
}
