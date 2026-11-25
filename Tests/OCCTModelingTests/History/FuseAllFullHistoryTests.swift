import Testing

@testable import OCCTSwift

/// The history-keeping `fuseAll` returns the plain result and every argument's history (#3560).
///
/// `fuseAllWithFullHistory(_:)` returns `fuseAll(_:)`'s result with the General Fuse history of
/// every argument. The fixture is two 10 mm cubes touching on the plane x = 0: `a` spans x in [-10, 0] and `b`
/// spans x in [0, 10]. A sub-shape is named by its bounds, never by an enumeration index.
@Suite("fuseAll with full history (#3560)")
struct FuseAllFullHistoryTests {

    static func close(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ t: Double = 1e-6) -> Bool {
        abs(a.x - b.x) <= t && abs(a.y - b.y) <= t && abs(a.z - b.z) <= t
    }

    /// The one face of `shape` whose bounds are `min`...`max`.
    static func face(of shape: Shape, min: SIMD3<Double>, max: SIMD3<Double>) throws -> Shape {
        let found = shape.subShapes(ofType: .face).filter { f in
            guard let b = f.bounds else { return false }
            return close(b.min, min) && close(b.max, max)
        }
        try #require(found.count == 1, "exactly one face of bounds \(min)...\(max)")
        return found[0]
    }

    /// How many sub-shapes of `shape` `isSame(as:)` `s`.
    static func occurrences(of s: Shape, in shape: Shape) -> Int {
        shape.subShapes(ofType: s.shapeType).filter { $0.isSame(as: s) }.count
    }

    /// Two cubes touching on x = 0.
    static func touchingCubes() throws -> (a: Shape, b: Shape) {
        let a = try #require(
            Shape.box(origin: SIMD3(-10, 0, 0), width: 10, height: 10, depth: 10), "cube a")
        let b = try #require(
            Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10), "cube b")
        return (a, b)
    }

    static let boundaryMin = SIMD3<Double>(0, 0, 0)
    static let boundaryMax = SIMD3<Double>(0, 10, 10)

    @Test("the result is fuseAll's")
    func resultIsFuseAlls() throws {
        let (a, b) = try Self.touchingCubes()
        let plain = try #require(Shape.fuseAll([a, b]))
        let kept = try #require(Shape.fuseAllWithFullHistory([a, b]))
        #expect(kept.result.shapeType == plain.shapeType)
        #expect(kept.result.solids.count == plain.solids.count)
        #expect(kept.result.faceCount == plain.faceCount)
        #expect(abs((kept.result.volume ?? 0) - (plain.volume ?? 0)) < 1e-9)
        // General Fuse: the two cubes, now sharing one face, 2000 mm^3 between them.
        #expect(kept.result.solids.count == 2)
        #expect(kept.result.faceCount == 11)
        #expect(abs((kept.result.volume ?? 0) - 2000) < 1e-6)
        #expect(Shape.fuseAllWithFullHistory([a]) == nil)
    }

    /// The two faces on x = 0 become one face of the result, and both inputs map to it.
    ///
    /// The merged face is held by both solids of the result, and neither input face survives.
    @Test("a face on the shared boundary maps to its merged image")
    func boundaryFaceMapsToMergedImage() throws {
        let (a, b) = try Self.touchingCubes()
        let r = try #require(Shape.fuseAllWithFullHistory([a, b]))
        let fromA = try Self.face(of: a, min: Self.boundaryMin, max: Self.boundaryMax)
        let fromB = try Self.face(of: b, min: Self.boundaryMin, max: Self.boundaryMax)
        let recA = r.history.record(of: fromA)
        let recB = r.history.record(of: fromB)
        #expect(!recA.isDeleted && !recB.isDeleted)
        try #require(recA.modified.count == 1 && recB.modified.count == 1)
        let merged = recA.modified[0]
        #expect(merged.isSame(as: recB.modified[0]))
        let mb = try #require(merged.bounds)
        #expect(Self.close(mb.min, Self.boundaryMin) && Self.close(mb.max, Self.boundaryMax))
        #expect(Self.occurrences(of: merged, in: r.result) == 1)
        #expect(r.result.solids.filter { Self.occurrences(of: merged, in: $0) == 1 }.count == 2)
        // Neither input face is itself in the result: each was replaced by the merged face.
        #expect(Self.occurrences(of: fromA, in: r.result) == 0)
        #expect(Self.occurrences(of: fromB, in: r.result) == 0)
    }

    /// A face away from the boundary is untouched: an empty record, and a face of the result.
    ///
    /// The faces are `a`'s at x = -10 and `b`'s at x = 10. The boundary faces in the same history
    /// are the control.
    @Test("a face away from the boundary maps to itself")
    func untouchedFaceMapsToItself() throws {
        let (a, b) = try Self.touchingCubes()
        let r = try #require(Shape.fuseAllWithFullHistory([a, b]))
        let farA = try Self.face(of: a, min: SIMD3(-10, 0, 0), max: SIMD3(-10, 10, 10))
        let farB = try Self.face(of: b, min: SIMD3(10, 0, 0), max: SIMD3(10, 10, 10))
        for face in [farA, farB] {
            let rec = r.history.record(of: face)
            #expect(rec.modified.isEmpty)
            #expect(rec.generated.isEmpty)
            #expect(!rec.isDeleted)
            #expect(Self.occurrences(of: face, in: r.result) == 1)
        }
        let fromB = try Self.face(of: b, min: Self.boundaryMin, max: Self.boundaryMax)
        #expect(r.history.record(of: fromB).modified.count == 1)
    }

    /// Absorbed into a graph, the history carries the second argument's sub-shapes too.
    ///
    /// A graph walks only the arguments the bridge lists (`BRepTools_History`'s argument list), so
    /// this is the one place that list is observable: the second cube's boundary face resolves to
    /// the merged face, as the first cube's does.
    @Test("an absorbed history carries the second argument's sub-shapes")
    func absorbedHistoryCoversEveryArgument() throws {
        let (a, b) = try Self.touchingCubes()
        let both = try #require(Shape.compound([a, b]))
        let graph = try #require(BRepGraph(shape: both))
        let rootNode = try #require(graph.findNode(for: both))
        let root = BRepGraph.NodeRef(kind: rootNode.kind, index: rootNode.index)
        let fromA = try Self.face(of: a, min: Self.boundaryMin, max: Self.boundaryMax)
        let fromB = try Self.face(of: b, min: Self.boundaryMin, max: Self.boundaryMax)
        let nodeA = try #require(graph.findNode(for: fromA))
        let nodeB = try #require(graph.findNode(for: fromB))

        let r = try #require(Shape.fuseAllWithFullHistory([a, b]))
        try #require(
            graph.add(r.result, absorbing: r.history, inputRoots: [root], operationName: "fuse")
                != nil)

        let formsA = graph.currentForms(of: BRepGraph.NodeRef(kind: nodeA.kind, index: nodeA.index))
            .filter { $0.kind == .face }
        let formsB = graph.currentForms(of: BRepGraph.NodeRef(kind: nodeB.kind, index: nodeB.index))
            .filter { $0.kind == .face }
        try #require(formsB.count == 1, "the second argument's boundary face has one successor")
        #expect(formsA == formsB)
        let merged = try #require(graph.shape(nodeKind: formsB[0].kind, nodeIndex: formsB[0].index))
        let mb = try #require(merged.bounds)
        #expect(Self.close(mb.min, Self.boundaryMin) && Self.close(mb.max, Self.boundaryMax))
    }
}
