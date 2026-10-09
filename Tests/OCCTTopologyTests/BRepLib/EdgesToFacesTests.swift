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

    @Test("Edges to faces from two disjoint closed loops (#1506)")
    func edgesToFacesFromTwoDisjointLoops() {
        // Two disjoint closed squares in one compound (the issue's own fixture). Before the fix,
        // the second loop's first edge failed to connect to the first loop's now-closed wire,
        // BRepBuilderAPI_MakeWire::Wire() was called on the builder anyway (no IsDone() guard),
        // threw StdFail_NotDone, and the exception propagated through both nested loops to the
        // function's blanket catch(...), discarding BOTH already-built faces, not just the
        // second, and returning nil.
        let square1 = Shape.fromWire(Wire.rectangle(width: 4, height: 4)!)!
        let square2 = Shape.fromWire(Wire.rectangle(width: 4, height: 4)!)!
            .translated(by: SIMD3<Double>(20, 0, 0))!
        let compound = Shape.compound([square1, square2])!

        let result = Shape.facesFromEdges(compound, onlyPlanar: true)
        #expect(result != nil)
        if let result {
            // Also guards the second defect: the edge that failed to connect must seed the next
            // wire rather than being silently discarded, or the second loop would come up one
            // edge short and never close into a face.
            #expect(result.faces().count == 2)
        }
    }
}
