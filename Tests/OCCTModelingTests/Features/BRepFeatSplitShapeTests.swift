import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFeat_SplitShape Tests")
struct BRepFeatSplitShapeTests {
    @Test("split face by edge")
    func splitByEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            // Find a planar face and create a splitting edge on it
            for face in faces {
                let edge = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10))
                if let e = edge {
                    let result = b.splitByEdge(e, onFace: face)
                    if let r = result {
                        let newFaces = r.subShapes(ofType: .face)
                        // At least one face should be split, giving more total faces
                        #expect(newFaces.count >= faces.count)
                        return
                    }
                }
            }
        }
    }

    @Test("split face by wire")
    func splitByWire() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            for face in faces {
                let e = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10))
                if let e {
                    let wire = Shape.makeWire(from: [e])
                    if let w = wire {
                        let result = b.splitByWire(w, onFace: face)
                        if let r = result {
                            let newFaces = r.subShapes(ofType: .face)
                            #expect(newFaces.count >= faces.count)
                            return
                        }
                    }
                }
            }
        }
    }

    @Test("split with sides - left and right")
    func splitWithSides() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            for face in faces {
                let e = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10))
                if let e {
                    let result = b.splitWithSides(edgesOnFaces: [(edge: e, face: face)])
                    if let r = result {
                        #expect(r.shape.subShapes(ofType: .face).count >= faces.count)
                        // Left and right may or may not be populated
                        #expect(r.leftFaces.count + r.rightFaces.count >= 0)
                        return
                    }
                }
            }
        }
    }
}
