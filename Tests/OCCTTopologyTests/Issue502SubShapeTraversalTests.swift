import Foundation
import Testing

@testable import OCCTSwift

// #502: `solids`/`shells`/`wires` walked a bare `TopExp_Explorer`, which yields one entry per
// *occurrence* in the topology tree; `subShapes(ofType:)` walked `TopExp::MapShapes`, which
// deduplicates by `TopoDS_Shape::IsSame` (same TShape + same location, orientation ignored).
// Two answers to one question, and nothing anywhere compared them.
//
// These tests fix the answer at the deduplicated one, for every type and both spellings, and
// pin the two properties that make that choice safe: instances at different locations survive,
// and the enumeration order does not change.

@Suite("Sub-shape traversal is one enumeration (#502)")
struct Issue502SubShapeTraversalTests {

    // MARK: - The two spellings agree on ordinary geometry

    /// Nothing here shares a sub-shape between two parents, so this passed before #502 too.
    /// It is the control: it says the fix did not move the answer for shapes anyone actually has.
    @Test("Typed and generic spellings agree on primitives")
    func typedAndGenericAgreeOnPrimitives() {
        let fixtures: [(String, Shape)] = [
            ("box", Shape.box(width: 10, height: 5, depth: 3)!),
            ("sphere", Shape.sphere(radius: 5)!),
            ("cylinder", Shape.cylinder(radius: 3, height: 8)!),
        ]
        for (name, shape) in fixtures {
            #expect(shape.solidCount == shape.subShapeCount(ofType: .solid), "\(name) solids")
            #expect(shape.shellCount == shape.subShapeCount(ofType: .shell), "\(name) shells")
            #expect(shape.wireCount == shape.subShapeCount(ofType: .wire), "\(name) wires")
            #expect(shape.solids.count == shape.solidCount, "\(name) solids array")
            #expect(shape.shells.count == shape.shellCount, "\(name) shells array")
            #expect(shape.wires.count == shape.wireCount, "\(name) wires array")
        }
    }

    @Test("Typed and generic spellings agree on a hollow solid's two shells")
    func typedAndGenericAgreeOnHollowSolid() {
        // `box(origin:)` is corner-anchored, so the cavity is strictly inside the block and the
        // cut leaves a second, inner shell. (`box(width:height:depth:)` is centred on the
        // origin, where the same cavity would break the surface instead.)
        guard let hollow = Issue211OuterShell.hollowSolid() else {
            Issue.record("cut failed")
            return
        }
        #expect(hollow.shellCount == 2)
        #expect(hollow.shellCount == hollow.subShapeCount(ofType: .shell))
        #expect(hollow.shells.count == hollow.subShapes(ofType: .shell).count)
    }

    // MARK: - The same sub-shape reachable twice

    /// The plainest form: one `Shape` handed to `compound` twice. The explorer walk reported two
    /// solids for one body at one location; the map walk reported one. Now both report one.
    @Test("A body compounded with itself counts once")
    func bodyCompoundedWithItselfCountsOnce() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let doubled = Shape.compound([box, box]) else {
            Issue.record("compound failed")
            return
        }
        #expect(doubled.solidCount == 1)
        #expect(doubled.solids.count == 1)
        #expect(doubled.solidCount == doubled.subShapeCount(ofType: .solid))
        #expect(doubled.shellCount == doubled.subShapeCount(ofType: .shell))
        #expect(doubled.wireCount == doubled.subShapeCount(ofType: .wire))
    }

    /// #502's own example: one shell handle reused across two `solidFromShells` calls. The two
    /// solids are distinct objects, so the solid count stays 2; it is the shell that is one
    /// shell, seen from two parents.
    @Test("A shell reused by two solids counts once, and the solids still count twice")
    func shellReusedByTwoSolidsCountsOnce() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let shell = box.shells.first,
            let s1 = Shape.solidFromShells([shell]),
            let s2 = Shape.solidFromShells([shell]),
            let both = Shape.compound([s1, s2])
        else {
            Issue.record("could not build two solids over one shell")
            return
        }
        #expect(both.solidCount == 2)
        #expect(both.shellCount == 1)
        #expect(both.shellCount == both.subShapeCount(ofType: .shell))
        #expect(both.shells.count == both.subShapes(ofType: .shell).count)
    }

    /// The wire case, which needs two faces built over one wire, since a face's wire is otherwise
    /// never shared with a second face.
    @Test("A wire reused by two faces counts once")
    func wireReusedByTwoFacesCountsOnce() {
        guard let wire = Wire.rectangle(width: 10, height: 10),
            let planar = Shape.face(from: wire),
            let onPlane = Shape.face(
                from: Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!,
                boundary: wire),
            let both = Shape.compound([planar, onPlane])
        else {
            Issue.record("could not build two faces over one wire")
            return
        }
        #expect(both.subShapeCount(ofType: .face) == 2)
        #expect(both.wireCount == 1)
        #expect(both.wireCount == both.subShapeCount(ofType: .wire))
        #expect(both.wires.count == both.subShapes(ofType: .wire).count)
    }

    // MARK: - What deduplication must NOT collapse

    /// Deduplication is by `IsSame`, which compares the location as well as the underlying
    /// geometry. Two placements of one body are therefore two solids, not one; without this,
    /// the fix would silently break every assembly that instances a part.
    @Test("Two placements of one body count twice")
    func twoPlacementsOfOneBodyCountTwice() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let moved = box.translated(by: SIMD3(50, 0, 0)),
            let assembly = Shape.compound([box, moved])
        else {
            Issue.record("compound failed")
            return
        }
        #expect(assembly.solidCount == 2)
        #expect(assembly.solids.count == 2)
        #expect(assembly.subShapeCount(ofType: .solid) == 2)
        #expect(assembly.shellCount == 2)
        #expect(assembly.wireCount == 12)
    }

    /// Two genuinely different bodies, so nothing to collapse.
    @Test("Two distinct bodies count twice")
    func twoDistinctBodiesCountTwice() {
        let a = Shape.box(width: 10, height: 10, depth: 10)!
        let b = Shape.box(origin: SIMD3(50, 0, 0), width: 4, height: 4, depth: 4)!
        guard let compound = Shape.compound([a, b]) else {
            Issue.record("compound failed")
            return
        }
        #expect(compound.solidCount == 2)
        #expect(compound.solids.count == 2)
        #expect(compound.shellCount == 2)
        #expect(compound.wireCount == 12)
    }

    // MARK: - One enumeration, so one order

    /// `TopExp::MapShapes` is an explorer walk piped into an indexed map, so the deduplicated
    /// sequence is the explorer's sequence with later repeats removed. Both spellings must
    /// therefore hand back the same sub-shapes in the same order, element by element.
    @Test("Both spellings enumerate in the same order")
    func bothSpellingsEnumerateInTheSameOrder() {
        guard let hollow = Issue211OuterShell.hollowSolid(),
            let assembly = Shape.compound([hollow, hollow.translated(by: SIMD3(40, 0, 0))!])
        else {
            Issue.record("fixture failed")
            return
        }
        for type in [ShapeType.solid, .shell, .wire] {
            let typed: [Shape]
            switch type {
            case .solid: typed = assembly.solids
            case .shell: typed = assembly.shells
            default: typed = assembly.wires
            }
            let generic = assembly.subShapes(ofType: type)
            #expect(typed.count == generic.count, "\(type) count")
            guard typed.count == generic.count else { continue }
            for (i, pair) in zip(typed, generic).enumerated() {
                #expect(pair.0.isSame(as: pair.1), "\(type) index \(i) differs between spellings")
            }
        }
    }

    /// The indexed accessor reads out of the same enumeration as the array accessor.
    @Test("Indexed and array access return the same sub-shape")
    func indexedAndArrayAccessMatch() {
        let hollow = Issue211OuterShell.hollowSolid()!
        let shells = hollow.shells
        #expect(shells.count == 2)
        for i in 0..<shells.count {
            guard let indexed = hollow.subShape(type: .shell, index: i) else {
                Issue.record("no shell at \(i)")
                continue
            }
            #expect(indexed.isSame(as: shells[i]))
        }
        #expect(hollow.subShape(type: .shell, index: shells.count) == nil)
        #expect(hollow.subShape(type: .shell, index: -1) == nil)
    }

    // MARK: - The rest of the API already deduplicated, and still does

    /// `edgeCount` / `vertexCount` / `faceCount` were already map-backed. Stated here because it
    /// is the reason #502 resolves toward deduplication rather than away from it: a box has 12
    /// edges, not the 24 edge *occurrences* an explorer walk yields.
    @Test("A box has 12 edges and 8 vertices under every spelling")
    func boxEdgeAndVertexCountsAreDeduplicated() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        #expect(box.edgeCount == 12)
        #expect(box.subShapeCount(ofType: .edge) == 12)
        #expect(box.vertexCount == 8)
        #expect(box.subShapeCount(ofType: .vertex) == 8)
        #expect(box.subShapeCount(ofType: .face) == 6)
    }

    /// An out-of-domain `ShapeType` raw value reaches `TopAbs_ShapeEnum` as a cast; it must
    /// answer 0 rather than throw or crash.
    @Test("Unknown shape type counts zero")
    func unknownShapeTypeCountsZero() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.subShapeCount(ofType: .unknown) == 0)
        #expect(box.subShapes(ofType: .unknown).isEmpty)
        #expect(box.subShape(type: .unknown, index: 0) == nil)
        #expect(box.subShapeCount(ofType: .compound) == 0)
    }

    /// A shape with none of the requested type, on both spellings.
    @Test("A vertex has no solids, shells or wires")
    func vertexHasNoSolidsShellsOrWires() {
        let vertex = Shape.vertex(at: SIMD3(0, 0, 0))!
        #expect(vertex.solidCount == 0)
        #expect(vertex.solids.isEmpty)
        #expect(vertex.shellCount == 0)
        #expect(vertex.shells.isEmpty)
        #expect(vertex.wireCount == 0)
        #expect(vertex.wires.isEmpty)
        #expect(vertex.subShapeCount(ofType: .solid) == 0)
        #expect(vertex.subShapes(ofType: .wire).isEmpty)
    }
}
