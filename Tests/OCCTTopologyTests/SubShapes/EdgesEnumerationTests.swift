import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// Regression for #3526: `Shape.edges()` rebuilt the whole indexed sub-shape map once per edge.
///
/// It was `(0..<edgeCount).map { edge(at: $0) }`, and every `edge(at:)` maps the shape with
/// `TopExp::MapShapes` to read one entry and throws the map away, so enumerating E edges cost E
/// maps: quadratic, 1.4 s on a 3,883-edge shape where `faces()` took 0.5 ms. `faces()` and
/// `vertices()` map once. `edges()` now maps once too (`OCCTShapeGetEdges`).
///
/// Three halves, because the fix has to keep what the slow form guaranteed and add what it lacked:
///
/// 1. **Same answer.** On every shape in the battery the bulk enumeration is, element for element,
///    the per-index path (`edge(at:)`): the same count, the same order, the same index, the same
///    sub-shape including its orientation. A faster `edges()` that reorders, drops or duplicates
///    an entry shifts every later ordinal (#979), and the output of a wrong one looks plausible.
/// 2. **Owned handles.** Each element owns its own handle, no element shares one, and the array the
///    bridge returns frees as a container only. A bridge that freed the handles with the array, or
///    wrote one twice, is a double free that only a later deallocation reaches.
/// 3. **Linear cost.** The per-edge cost of `edges()` does not grow with the edge count. The first
///    two halves cannot see this one at all: the quadratic form returned exactly the same array.
@Suite("Shape.edges() reads the edge map once")
struct EdgesEnumerationTests {

    // MARK: - Fixtures

    /// The names `battery()` must produce, declared apart from the builder so that a fixture
    /// which stops being built is a failure and not a smaller loop (a fallible factory that `?? x`s
    /// or skips its entry reads as a shorter list, and every assertion below walks the list).
    static let batteryNames: Set<String> = [
        "box", "filletedBox", "cylinder", "sphere", "cone", "lBracket", "boxWithItself",
        "splitBoxCompound", "compoundOf20Boxes", "bareEdge", "bareFace", "emptiedSolid",
        "vertexCompound", "vertex", "nullified",
    ]

    /// A box cut into two solids that share the cut face and the edges around it, so some edge is
    /// reached from more than one parent and the deduplicated map is shorter than the walk.
    static func splitBoxCompound() throws -> Shape {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let halves = try #require(box.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1)))
        return try #require(Shape.compound(halves))
    }

    /// Every shape the enumeration is compared on.
    ///
    /// Each is built with `#require`, so a fixture that stops being buildable fails here rather
    /// than shortening the battery.
    static func battery() throws -> [(name: String, shape: Shape)] {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        var shapes: [(name: String, shape: Shape)] = []

        shapes.append(("box", box))
        shapes.append(("filletedBox", try #require(box.filleted(radius: 1))))
        shapes.append(("cylinder", try #require(Shape.cylinder(radius: 5, height: 10))))
        shapes.append(("sphere", try #require(Shape.sphere(radius: 5))))
        shapes.append(
            ("cone", try #require(Shape.cone(bottomRadius: 5, topRadius: 0, height: 10))))

        // Two fused boxes: faces meet along edges that belong to both, and one edge is concave.
        let plate = try #require(Shape.box(width: 40, height: 40, depth: 10))
        let wall = try #require(Shape.box(width: 10, height: 40, depth: 40))
        shapes.append(("lBracket", try #require(plate.union(wall))))

        // One TShape reached twice: 24 edge occurrences collapse to the 12 distinct edges.
        shapes.append(("boxWithItself", try #require(Shape.compound([box, box]))))
        shapes.append(("splitBoxCompound", try splitBoxCompound()))

        let row = try (0..<20).map { i in
            try #require(box.translated(by: SIMD3(Double(i) * 20, 0, 0)))
        }
        shapes.append(("compoundOf20Boxes", try #require(Shape.compound(row))))

        // A bare edge enumerates as itself and a bare face as its own boundary.
        let firstEdge = try #require(box.edge(at: 0))
        shapes.append(("bareEdge", try #require(Shape.fromEdge(firstEdge))))
        let firstFace = try #require(box.face(at: 0))
        shapes.append(("bareFace", try #require(Shape.fromFace(firstFace))))

        // No edge to enumerate, three different ways of having none.
        shapes.append(("emptiedSolid", try #require(box.emptied)))
        // (`Shape.compound([])` answers nil, so a compound with no edge is a compound of vertices.)
        let corner = try #require(Shape.vertex(at: SIMD3(1, 2, 3)))
        let other = try #require(Shape.vertex(at: SIMD3(4, 5, 6)))
        shapes.append(("vertexCompound", try #require(Shape.compound([corner, other]))))
        shapes.append(("vertex", corner))
        shapes.append(("nullified", try #require(box.nullified)))

        return shapes
    }

    // MARK: - The fixtures mean their names

    @Test("The battery holds exactly the shapes it declares")
    func batteryMembership() throws {
        let built = try Self.battery()
        #expect(Set(built.map { $0.name }) == Self.batteryNames)
        #expect(built.count == Self.batteryNames.count, "a name was built twice")
    }

    /// The fixtures exist to put shared and repeated edges in front of the enumeration.
    ///
    /// A fixture that has stopped doing that proves nothing about it, so the sharing is measured
    /// rather than assumed. Each box edge borders two faces, so every solid's face walk visits its
    /// edges twice and that proves nothing about sharing between parents; what does is a compound
    /// whose parts, counted one by one, hold more edges than the compound has distinct edges.
    @Test("The sharing fixtures really share edges, and the edgeless ones really have none")
    func fixturesMeanTheirNames() throws {
        let byName = Dictionary(
            uniqueKeysWithValues: try Self.battery().map { ($0.name, $0.shape) })

        func edge(_ name: String) throws -> Int {
            try #require(byName[name], "no fixture named \(name)").edgeCount
        }
        func occurrences(_ name: String) throws -> Int {
            try #require(byName[name], "no fixture named \(name)").contents.edges
        }

        #expect(try edge("box") == 12)
        #expect(
            try occurrences("box") > edge("box"),
            "each box edge is reached once per adjacent face, so the walk is longer than the map")

        // One TShape handed in twice: the walk visits every edge twice as often as a lone box's,
        // and the map still holds 12.
        #expect(try edge("boxWithItself") == 12, "the same TShape twice is still 12 edges")
        #expect(
            try occurrences("boxWithItself") == 2 * occurrences("box"),
            "boxWithItself no longer reaches the same box twice")

        // Two solids sharing the cut face: counted one solid at a time they hold more edges than
        // the compound has, because the cut face's four edges belong to both.
        let split = try #require(byName["splitBoxCompound"])
        let solids = split.solids
        #expect(solids.count == 2, "the split should leave two solids")
        #expect(
            solids.map { $0.edgeCount }.reduce(0, +) > split.edgeCount,
            "the two halves share no edge, so the fixture no longer exercises sharing")

        #expect(try edge("compoundOf20Boxes") == 240)
        #expect(try edge("bareEdge") == 1)
        #expect(try edge("lBracket") > 12, "the fuse should leave more edges than one box")
        // A fillet puts curved edges where there were none: more edges than the 12 it started with.
        #expect(try edge("filletedBox") > 12)

        for name in ["emptiedSolid", "vertexCompound", "vertex", "nullified"] {
            #expect(try edge(name) == 0, "\(name) should have no edge")
        }
    }

    // MARK: - Same answer as the per-index path

    /// The bulk enumeration against the per-index path it replaced, element for element.
    static func expectSameAsPerIndex(_ name: String, _ shape: Shape) throws {
        let count = shape.edgeCount
        let bulk = shape.edges()

        #expect(bulk.count == count, "\(name): edges() returned \(bulk.count) of \(count)")

        var perIndex: [Edge] = []
        for k in 0..<count {
            perIndex.append(try #require(shape.edge(at: k), "\(name): edge(at: \(k)) is nil"))
        }
        #expect(perIndex.count == count)

        for (k, pair) in zip(bulk, perIndex).enumerated() {
            let (fromBulk, fromIndex) = pair
            #expect(fromBulk.index == k, "\(name): edges()[\(k)].index is \(fromBulk.index)")
            #expect(fromIndex.index == k, "\(name): edge(at: \(k)).index is \(fromIndex.index)")
            guard let a = Shape.fromEdge(fromBulk), let b = Shape.fromEdge(fromIndex) else {
                Issue.record("\(name): could not wrap edge \(k) as a shape")
                continue
            }
            #expect(
                a.isSame(as: b), "\(name): edges()[\(k)] is a different edge from edge(at: \(k))")
            // IsEqual also compares orientation, which the two must agree on: both read the one map.
            #expect(a.isEqual(to: b), "\(name): edges()[\(k)] carries another orientation")
            #expect(
                abs(fromBulk.length - fromIndex.length) <= 1e-12,
                "\(name): edges()[\(k)] measures \(fromBulk.length), edge(at:) \(fromIndex.length)")
        }
    }

    @Test("edges() is the per-index path, element for element, on every shape in the battery")
    func edgesEqualThePerIndexPath() throws {
        for (name, shape) in try Self.battery() {
            try Self.expectSameAsPerIndex(name, shape)
        }
    }

    /// The same comparison on a large shape, where a bulk path that restarted or wrapped an index
    /// would be wrong only past the first few entries.
    @Test("edges() is the per-index path on a shape with thousands of edges")
    func edgesEqualThePerIndexPathAtScale() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let parts = try (0..<60).map { i in
            try #require(
                box.translated(by: SIMD3(Double(i % 8) * 20, Double(i / 8) * 20, 0)))
        }
        let compound = try #require(Shape.compound(parts))
        #expect(compound.edgeCount == 720)
        try Self.expectSameAsPerIndex("compoundOf60Boxes", compound)
    }

    @Test("edges() agrees with faces() and vertices() on how many entries the map holds")
    func edgesFacesAndVerticesAgreeWithTheirCounts() throws {
        for (name, shape) in try Self.battery() {
            #expect(shape.edges().count == shape.edgeCount, "\(name): edges()")
            #expect(shape.faces().count == shape.faceCount, "\(name): faces()")
            #expect(shape.vertices().count == shape.vertexCount, "\(name): vertices()")
        }
    }

    // MARK: - Never a short array

    @Test("An edgeless shape answers an empty array, not a failure")
    func edgelessShapesAnswerEmpty() throws {
        let byName = Dictionary(
            uniqueKeysWithValues: try Self.battery().map { ($0.name, $0.shape) })
        for name in ["emptiedSolid", "vertexCompound", "vertex", "nullified"] {
            let shape = try #require(byName[name], "no fixture named \(name)")
            #expect(shape.edgeCount == 0)
            #expect(shape.edges().isEmpty, "\(name) has no edges")
        }
    }

    /// The Swift side refuses a hole rather than shifting every later ordinal.
    ///
    /// That only holds if the bridge never hands one over: every slot of the array it returns is
    /// filled, and the count it reports is the whole enumeration. Read here at the bridge, where a
    /// short write is visible, because `edges()` turns a hole into an empty array and so cannot
    /// tell a refused enumeration from an empty shape.
    @Test("The bridge fills every slot of the whole enumeration, in one call")
    func theBridgeHandsBackTheWholeEnumeration() throws {
        for (name, shape) in try Self.battery() {
            var count: Int32 = -1
            let array = OCCTShapeGetEdges(shape.handle, &count)

            if shape.edgeCount == 0 {
                #expect(array == nil, "\(name): an edgeless shape has no array to return")
                #expect(count == 0, "\(name): count must be written even when there is no array")
                continue
            }

            let edges = try #require(array, "\(name): OCCTShapeGetEdges answered nothing")
            #expect(Int(count) == shape.edgeCount, "\(name): wrote \(count) of \(shape.edgeCount)")
            for i in 0..<Int(count) {
                #expect(edges[i] != nil, "\(name): slot \(i) is null")
                if let edge = edges[i] { OCCTEdgeRelease(edge) }
            }
            OCCTFreeEdgeArrayOnly(edges)
        }
    }

    @Test("A null shape or a null count answers nothing and writes a zero count")
    func nullArgumentsAnswerNothing() throws {
        var count: Int32 = -1
        #expect(OCCTShapeGetEdges(nil, &count) == nil)
        #expect(count == 0, "a refused call must not leave a stale count behind")

        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(OCCTShapeGetEdges(box.handle, nil) == nil)

        // A null array to free is not an error either.
        OCCTFreeEdgeArrayOnly(nil)
    }

    // MARK: - Owned handles

    @Test("Every element owns a handle of its own")
    func everyElementOwnsADistinctHandle() throws {
        for (name, shape) in try Self.battery() {
            let edges = shape.edges()
            let handles = Set(edges.map { $0.handle })
            // The handles are read off the elements, so the elements must outlive the read.
            defer { withExtendedLifetime(edges) {} }
            #expect(
                handles.count == edges.count,
                "\(name): two elements share one handle, so the second deallocation frees it twice"
            )
        }
    }

    /// Elements outlive the array container, the parent shape and a second enumeration of it.
    ///
    /// An array freed together with its handles (or handles that borrow the parent) is a
    /// use-after-free that reads plausible numbers until the memory is reused, so the check reads
    /// every element after all three have gone and compares against lengths taken beforehand.
    @Test("Elements stay valid after the array, the parent and a repeat enumeration are gone")
    func elementsOutliveTheirParent() throws {
        func enumerate() throws -> (edges: [Edge], lengths: [Double]) {
            let shape = try #require(
                Shape.box(width: 10, height: 20, depth: 30)?.filleted(radius: 1))
            let edges = shape.edges()
            let lengths = edges.map { $0.length }
            // A second enumeration of the same parent, dropped immediately: its elements release
            // theirs, and must not take the first enumeration's down with them.
            _ = shape.edges()
            return (edges, lengths)
        }

        let (edges, lengths) = try enumerate()
        #expect(!edges.isEmpty)
        #expect(edges.map { $0.length } == lengths)
        for (k, edge) in edges.enumerated() { #expect(edge.index == k) }
    }

    @Test("Enumerating repeatedly leaves no handle behind that a later call can trip over")
    func repeatedEnumerationIsStable() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for _ in 0..<200 {
            let edges = box.edges()
            #expect(edges.count == 12)
        }
    }

    // MARK: - Linear cost

    /// The per-edge cost of `edges()` at two sizes.
    ///
    /// Complexity class, not wall clock: it is a ratio of two measurements taken in the same
    /// process, with a bound loose enough that load moves both sides together, the arrangement
    /// the `allEdgePolylines` guard (#275) uses for the same defect.
    ///
    /// Each size is timed as repeated passes until the clock can see them, and the smallest of
    /// three such batches is kept. Repeating matters on a fast runtime, where a 108-edge pass
    /// finishes inside `Date()`'s resolution and reads 0 (#2894); taking the smallest batch keeps
    /// one descheduled slice from reading as growth.
    static func perEdgeCost(boxes count: Int) throws -> (cost: Double, edges: Int) {
        let box = try #require(Shape.box(width: 1, height: 1, depth: 1))
        let parts = try (0..<count).map { i in
            try #require(box.translated(by: SIMD3(Double(i % 20) * 2, Double(i / 20) * 2, 0)))
        }
        let compound = try #require(Shape.compound(parts))
        let edgeCount = compound.edgeCount

        let floor = 0.010
        var smallest = Double.infinity
        for _ in 0..<3 {
            var passes = 0
            var elapsed = 0.0
            let start = Date()
            while elapsed < floor {
                #expect(compound.edges().count == edgeCount)
                passes += 1
                elapsed = Date().timeIntervalSince(start)
            }
            smallest = min(smallest, elapsed / Double(edgeCount * passes))
        }
        return (smallest, edgeCount)
    }

    @Test("edges() per-edge cost does not grow with the number of edges")
    func edgesScalesLinearly() throws {
        let small = try Self.perEdgeCost(boxes: 9)  // 108 edges
        let large = try Self.perEdgeCost(boxes: 400)  // 4,800 edges

        // The comparison means nothing unless the large shape is far larger than the small one.
        #expect(large.edges >= small.edges * 40)

        // Linear: the per-edge cost stays roughly constant. The per-index form rebuilt the whole
        // map for every edge, so its per-edge cost grew with the edge count, about 44x here.
        #expect(
            large.cost < small.cost * 8,
            "per-edge cost grew \(large.cost / small.cost)x from \(small.edges) to \(large.edges) edges, edges() looks quadratic again"
        )
    }
}
