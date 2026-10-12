import Foundation
import OCCTBridge
import Testing

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
    func circleEdgeClosed() throws {
        let circle = try #require(Wire.circle(radius: 5))
        let face = try #require(Shape.face(from: circle))
        // A disc face is bounded by exactly one edge, the closed circle.
        let edges = face.edges()
        #expect(edges.count == 1)
        for edge in edges {
            #expect(edge.isClosed3D)
            #expect(abs(edge.length - 2 * .pi * 5) < 1e-9)
        }

        // Control: the four edges of a rectangular face are open, so a getter that answers
        // true for everything cannot pass.
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        let rectFace = try #require(Shape.face(from: rect))
        let rectEdges = rectFace.edges()
        #expect(rectEdges.count == 4)
        for edge in rectEdges { #expect(!edge.isClosed3D) }
    }

    @Test("Cylinder has seam edge")
    func cylinderSeamEdge() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        // Exactly one (edge, face) pair is a seam: the length-10 generator on the lateral face
        // (area 100 pi). The rim circles are not seams on any of the three faces.
        var seams: [(length: Double, area: Double)] = []
        for face in cyl.faces() {
            for edge in cyl.edges() where edge.isSeam(on: face) {
                seams.append((edge.length, face.area()))
            }
        }
        #expect(seams.count == 1)
        if let seam = seams.first {
            #expect(abs(seam.length - 10) < 1e-9)
            #expect(abs(seam.area - 100 * .pi) < 1e-9)
        }

        // Control: a box has no seams, so an answer that is true for every pair cannot pass.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for face in box.faces() {
            for edge in box.edges() { #expect(!edge.isSeam(on: face)) }
        }
    }
}
