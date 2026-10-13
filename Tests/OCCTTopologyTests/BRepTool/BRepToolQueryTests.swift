import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("v0.114.0 - BRep_Tool Queries")
struct BRepToolQueryTests {

    @Test func edgeCurveFromBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                if let result = edges[0].edgeCurveWithParams() {
                    #expect(result.first < result.last)
                    let mid = (result.first + result.last) / 2.0
                    let pt = result.curve.point(at: mid)
                    // Point should be on the box
                    #expect(pt.x >= -6 && pt.x <= 16)
                }
            }
        }
    }

    @Test func faceSurfaceFromBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let surf = faces[0].faceSurfaceGeom()
                #expect(surf != nil)
                if let s = surf {
                    let tn = s.typeName
                    #expect(tn != nil)
                    // Box faces are planes
                    if let name = tn {
                        #expect(name.contains("Plane"))
                    }
                }
            }
        }
    }

    @Test func isClosedShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let shell = try #require(box.subShapes(ofType: .shell).first)
        #expect(shell.isClosedShape)

        // Controls: six faces collected into a shell without sewing are not a closed shell, and
        // neither is a sewn shell missing a face.
        let faces = box.subShapes(ofType: .face)
        let loose = try #require(Shape.shellFromFaces(faces))
        #expect(!loose.isClosedShape)
        let sewn = try #require(Shape.sew(shapes: Array(faces.prefix(5))))
        let openShell = try #require(sewn.subShapes(ofType: .shell).first)
        #expect(!openShell.isClosedShape)
    }
}
