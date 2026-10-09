import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.126.0 Tests

@Suite("v0.126.0, BRep_Tool completions")
struct BRepToolCompletionsTests {
    @Test("CurveOnSurface returns pcurve of edge on face")
    func curveOnSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let faces = box.subShapes(ofType: .face)  // faces
            let edges = box.subShapes(ofType: .edge)  // edges
            if faces.count > 0 && edges.count > 0 {
                // Try each edge-face pair until we find one with a pcurve
                var found = false
                for face in faces {
                    for edge in edges {
                        if let result = Shape.curveOnSurface(edge: edge, face: face) {
                            #expect(result.first < result.last || result.first == result.last)
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
                // Box edges always have pcurves on their adjacent faces
                #expect(found)
            }
        }
    }

    @Test("HasContinuity and Continuity between faces")
    func continuity() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let edges = box.subShapes(ofType: .edge)
            let faces = box.subShapes(ofType: .face)
            if edges.count > 0 && faces.count >= 2 {
                // Test hasContinuity between two faces sharing an edge
                // Just make sure it doesn't crash
                let _ = Shape.hasContinuity(edge: edges[0], face1: faces[0], face2: faces[1])
            }
        }
    }

    @Test("HasAnyContinuity on filleted edge")
    func hasAnyContinuity() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box, let filleted = box.filleted(radius: 1.0) {
            let edges = filleted.subShapes(ofType: .edge)
            if edges.count > 0 {
                // At least some edges on filleted shape may have continuity
                let _ = Shape.hasAnyContinuity(edge: edges[0])
                let _ = Shape.maxContinuity(edge: edges[0])
            }
        }
    }

    @Test("Degenerated returns false for box edge")
    func degenerated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                #expect(!Shape.isDegenerated(edge: edges[0]))
            }
        }
    }

    @Test("NaturalRestriction on sphere face")
    func naturalRestriction() {
        // Sphere has natural restriction on its face
        let sphere = Shape.sphere(radius: 5)
        if let sphere = sphere {
            let faces = sphere.subShapes(ofType: .face)
            if faces.count > 0 {
                // Sphere face may or may not have natural restriction; just ensure no crash
                let _ = Shape.naturalRestriction(face: faces[0])
            }
        }
    }

    @Test("RangeOnFace returns valid range")
    func rangeOnFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count > 0 && edges.count > 0 {
                // Try to find an edge that belongs to the face
                for face in faces {
                    for edge in edges {
                        if let range = Shape.rangeOnFace(edge: edge, face: face) {
                            #expect(range.first <= range.last || range.first == range.last)
                            return
                        }
                    }
                }
            }
        }
    }

    @Test("ParametersOnFace returns UV for vertex on box face")
    func parametersOnFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let vertices = box.subShapes(ofType: .vertex)
            let faces = box.subShapes(ofType: .face)
            if vertices.count > 0 && faces.count > 0 {
                var found = false
                for face in faces {
                    for vertex in vertices {
                        if let uv = Shape.parametersOnFace(vertex: vertex, face: face) {
                            #expect(uv.u.isFinite)
                            #expect(uv.v.isFinite)
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
            }
        }
    }

    @Test("UVPoints returns valid UV endpoints for edge on face")
    func uvPoints() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if faces.count > 0 && edges.count > 0 {
                var found = false
                for face in faces {
                    for edge in edges {
                        if let uv = Shape.uvPoints(edge: edge, face: face) {
                            #expect(uv.firstU.isFinite)
                            #expect(uv.lastU.isFinite)
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
            }
        }
    }

    @Test("MaxTolerance returns positive value")
    func maxTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box {
            let tol = box.maxTolerance(subShapeType: 6)  // edges
            #expect(tol >= 0)
            let tolV = box.maxTolerance(subShapeType: 7)  // vertices
            #expect(tolV >= 0)
        }
    }
}
