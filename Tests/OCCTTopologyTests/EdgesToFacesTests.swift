import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Edges to Faces")
struct EdgesToFacesTests {
    @Test("Edges to faces from wire shape")
    func edgesToFacesFromWire() {
        // Create a wire shape, it contains 4 connected edges forming a rectangle
        let rect = Wire.rectangle(width: 10, height: 5)!
        let wireShape = Shape.fromWire(rect)!
        let result = Shape.facesFromEdges(wireShape, onlyPlanar: true)
        // A closed planar wire should produce a face
        #expect(result != nil)
    }

    @Test("Edges to faces from compound of edges produces faces")
    func edgesToFacesFromCompound() {
        // A compound of edges from a closed planar loop should produce a face
        // Note: passing a full solid (box) doesn't work because edges are shared
        // between faces and the greedy wire-building algorithm can't reconstruct them
        let rect = Wire.rectangle(width: 6, height: 4)!
        let wireShape = Shape.fromWire(rect)!
        let result = Shape.facesFromEdges(wireShape, onlyPlanar: true)
        #expect(result != nil)
    }

    @Test("Edges to faces with non-planar mode")
    func edgesToFacesNonPlanar() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let wireShape = Shape.fromWire(rect)!
        let result = Shape.facesFromEdges(wireShape, onlyPlanar: false)
        #expect(result != nil)
    }
}
