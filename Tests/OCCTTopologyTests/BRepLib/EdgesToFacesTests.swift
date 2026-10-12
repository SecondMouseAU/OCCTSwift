import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Edges to Faces")
struct EdgesToFacesTests {
    @Test("Edges to faces from wire shape")
    func edgesToFacesFromWire() throws {
        // A wire shape of 4 connected edges forming a 10 x 5 rectangle.
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        let wireShape = try #require(Shape.fromWire(rect))
        let result = try #require(Shape.facesFromEdges(wireShape, onlyPlanar: true))
        // One face, bounded by the same four edges, covering exactly the rectangle.
        #expect(result.faces().count == 1)
        #expect(result.edges().count == 4)
        #expect(abs((result.surfaceArea ?? 0) - 50) < 1e-6)
    }

    @Test("Edges to faces from compound of edges produces faces")
    func edgesToFacesFromCompound() throws {
        // A compound of four loose edges (not a wire) from a closed planar loop.
        // Note: passing a full solid (box) doesn't work because edges are shared
        // between faces and the greedy wire-building algorithm can't reconstruct them
        let rect = try #require(Wire.rectangle(width: 6, height: 4))
        let looseEdges = rect.edges().compactMap { Shape.fromEdge($0) }
        #expect(looseEdges.count == 4)
        let compound = try #require(Shape.compound(looseEdges))
        #expect(compound.faces().isEmpty)

        let result = try #require(Shape.facesFromEdges(compound, onlyPlanar: true))
        #expect(result.faces().count == 1)
        #expect(abs((result.surfaceArea ?? 0) - 24) < 1e-6)
    }

    @Test("Edges to faces with non-planar mode")
    func edgesToFacesNonPlanar() throws {
        // onlyPlanar: false still has to build the plain planar face from a planar loop. Measured
        // on kernel.6: a skew quadrilateral (one corner lifted 3) is refused in both modes, so the
        // flag is not something this wrapper can show opening up non-planar loops; only the
        // planar-only refusal is pinned.
        let rect = try #require(Wire.rectangle(width: 10, height: 5))
        let wireShape = try #require(Shape.fromWire(rect))
        let result = try #require(Shape.facesFromEdges(wireShape, onlyPlanar: false))
        #expect(result.faces().count == 1)
        #expect(abs((result.surfaceArea ?? 0) - 50) < 1e-6)

        let skew = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 3), SIMD3(0, 10, 0)],
                closed: true))
        let skewShape = try #require(Shape.fromWire(skew))
        #expect(Shape.facesFromEdges(skewShape, onlyPlanar: true) == nil)
        #expect(Shape.facesFromEdges(skewShape, onlyPlanar: false) == nil)
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
