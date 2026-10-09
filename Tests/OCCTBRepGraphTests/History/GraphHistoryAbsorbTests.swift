import Foundation
import Testing

@testable import OCCTSwift

/// Carrying a durable face reference across a boolean split (issue #290).
///
/// The scenario throughout is the reporter's: a 10×10×10 box with a bar cut
/// across its top (Y ∈ [4, 6], full X width), splitting the single 10×10 top
/// face into two 10×4 strips. Assertions are geometric rather than count-only,
/// "two nodes came back" is not evidence they are the right two.
///
/// The order of the records is pinned by `Issue3038AbsorbOrderTests`; the tests here pin sets,
/// areas and positions, and a record's own contents, so they hold whatever that order is.
@Suite("Graph history absorb (#290)")
struct GraphHistoryAbsorbTests {

    /// A cut of the box, with the graph built from the box and the faces worth watching pinned
    /// before the cut.
    struct Cut {
        let base: Shape
        let graph: BRepGraph
        let root: BRepGraph.NodeRef
        /// The top face's node (z = 10), pinned before the cut.
        let pinnedTop: BRepGraph.NodeRef
        /// The bottom face's node (z = 0), pinned before the cut.
        let pinnedBottom: BRepGraph.NodeRef
        /// The same two faces as sub-shapes of `base`, for asking the boolean's own history.
        let topShape: Shape
        let bottomShape: Shape
        /// How many faces, edges and vertices the graph held before the result was added: the
        /// original nodes are the leading indices of each kind.
        let baseFaces: Int
        let baseEdges: Int
        let baseVertices: Int
        let result: Shape
        let history: ShapeHistoryRef
    }

    /// The 10×10×10 box with its corner at the origin, minus a box at `toolOrigin` of `toolSize`.
    static func makeCut(toolOrigin: SIMD3<Double>, toolSize: SIMD3<Double>) throws -> Cut {
        let base = try #require(
            Shape.box(origin: SIMD3<Double>(0, 0, 0), width: 10, height: 10, depth: 10),
            "base box")
        let graph = try #require(BRepGraph(shape: base), "graph of the base box")
        let rootNode = try #require(graph.findNode(for: base), "root node of the base box")
        let baseFaces = graph.faceCount
        let baseEdges = graph.edgeCount
        let baseVertices = graph.vertexCount

        let faces = base.faces()
        let centroids = base.measure().faceCentroids
        let heights = centroids.enumerated().compactMap { i, centroid in
            centroid.map { (index: i, z: $0.z) }
        }
        try #require(heights.count == faces.count, "every face of the base box has a centroid")
        let topIndex = try #require(heights.max(by: { $0.z < $1.z })?.index, "top face")
        let bottomIndex = try #require(heights.min(by: { $0.z < $1.z })?.index, "bottom face")

        let topShape = try #require(Shape.fromFace(faces[topIndex]), "top face shape")
        let bottomShape = try #require(Shape.fromFace(faces[bottomIndex]), "bottom face shape")
        let topNode = try #require(graph.findNode(for: topShape), "top face node")
        let bottomNode = try #require(graph.findNode(for: bottomShape), "bottom face node")

        let tool = try #require(
            Shape.box(
                origin: toolOrigin, width: toolSize.x, height: toolSize.y, depth: toolSize.z),
            "tool box")
        let (result, history) = try #require(base.subtractedWithFullHistory(tool), "the cut")

        return Cut(
            base: base,
            graph: graph,
            root: BRepGraph.NodeRef(kind: rootNode.kind, index: rootNode.index),
            pinnedTop: BRepGraph.NodeRef(kind: topNode.kind, index: topNode.index),
            pinnedBottom: BRepGraph.NodeRef(kind: bottomNode.kind, index: bottomNode.index),
            topShape: topShape,
            bottomShape: bottomShape,
            baseFaces: baseFaces,
            baseEdges: baseEdges,
            baseVertices: baseVertices,
            result: result,
            history: history)
    }

    /// The reporter's channel: a 12 × 2 × 4 bar through the top, leaving two 10 × 4 strips.
    static func makeChannelCut() throws -> Cut {
        try makeCut(toolOrigin: SIMD3<Double>(-1, 4, 8), toolSize: SIMD3<Double>(12, 2, 4))
    }

    /// A slab: a 12 × 12 × 4 tool that removes z ∈ [8, 10] across the whole box, consuming the top.
    static func makeSlabCut() throws -> Cut {
        try makeCut(toolOrigin: SIMD3<Double>(-1, -1, 8), toolSize: SIMD3<Double>(12, 12, 4))
    }

    /// Absorbs the cut into its own graph and returns the result's topology root.
    @discardableResult
    static func absorb(_ c: Cut, as label: String = "channel-cut") throws -> BRepGraph.NodeRef {
        try #require(
            c.graph.add(
                c.result, absorbing: c.history, inputRoots: [c.root], operationName: label),
            "add should return the result's topology root")
    }

    static func shape(_ graph: BRepGraph, _ node: BRepGraph.NodeRef) throws -> Shape {
        try #require(
            graph.shape(nodeKind: node.kind, nodeIndex: node.index), "shape of node \(node)")
    }

    /// Area of the face a node reconstructs to.
    static func faceArea(_ graph: BRepGraph, _ node: BRepGraph.NodeRef) throws -> Double {
        let areas = try shape(graph, node).measure().faceAreas
        try #require(!areas.isEmpty, "node \(node) reconstructs to a shape with no face")
        return areas.reduce(0, +)
    }

    /// Area centroid of the face a node reconstructs to.
    static func faceCentroid(
        _ graph: BRepGraph, _ node: BRepGraph.NodeRef
    ) throws -> SIMD3<Double> {
        let centroids = try shape(graph, node).measure().faceCentroids
        return try #require(centroids.first ?? nil, "centroid of node \(node)")
    }

    /// Parameter midpoint and length of the edge a node reconstructs to.
    static func edgeMidpointAndLength(
        _ graph: BRepGraph, _ node: BRepGraph.NodeRef
    ) throws -> (midpoint: SIMD3<Double>, length: Double) {
        let edgeShape = try shape(graph, node)
        let edge = try #require(edgeShape.edges().first, "edge of node \(node)")
        let bounds = try #require(edge.parameterBounds, "bounds of the edge of node \(node)")
        let midpoint = try #require(
            edge.point(at: (bounds.first + bounds.last) / 2), "midpoint of the edge of node \(node)"
        )
        return (midpoint, edge.length)
    }

    /// How many records `Absorb` should write for `c`.
    ///
    /// Counted from the boolean's own history rather than from the absorb: one per tracked input
    /// (solid, face, edge, vertex) for each of Modified and Generated it has images for, and one
    /// batch record for every deletion together. A removed input writes only into the batch
    /// (`BRepGraph_LayerHistory::Absorb`).
    static func expectedRecordCount(_ c: Cut) -> Int {
        var inputs: [Shape] = [c.base]
        for type in [ShapeType.face, .edge, .vertex] {
            inputs.append(contentsOf: c.base.subShapes(ofType: type))
        }
        var count = 0
        var anyDeleted = false
        for input in inputs {
            let record = c.history.record(of: input)
            if record.isDeleted {
                anyDeleted = true
                continue
            }
            if !record.modified.isEmpty { count += 1 }
            if !record.generated.isEmpty { count += 1 }
        }
        return count + (anyDeleted ? 1 : 0)
    }

    @Test("absorbing a boolean's history writes records into the input graph")
    func absorbWritesRecords() throws {
        let c = try Self.makeChannelCut()
        #expect(c.graph.historyRecordCount == 0, "graph should start with an empty history log")

        let added = try Self.absorb(c)

        // The root the absorb returns is the RESULT's, not the input root the graph already held:
        // it rebuilds to the cut solid, 1000 less the 10 x 2 x 2 channel.
        #expect(added != c.root)
        let addedShape = try Self.shape(c.graph, added)
        let volume = try #require(addedShape.volume, "volume of the added root")
        #expect(abs(volume - 960.0) < 1e-6, "cut solid volume \(volume)")

        // The log holds exactly the records the boolean's own history accounts for, not merely
        // some.
        let expected = Self.expectedRecordCount(c)
        #expect(expected > 0, "the cut must have images to record")
        #expect(c.graph.historyRecordCount == expected)

        // Every record carries the label and is numbered by its position in the log, and the
        // channel consumes nothing, so the deleted set stays empty.
        for i in 0..<c.graph.historyRecordCount {
            let record = try #require(c.graph.historyRecord(at: i), "record \(i)")
            #expect(record.operationName == "channel-cut", "record \(i)")
            #expect(record.sequenceNumber == i, "record \(i)")
        }
        #expect(c.graph.historyDeletedNodes.isEmpty)
    }

    /// The core of #290: the pre-cut face resolves to its two successor strips.
    @Test("pre-cut top face resolves to exactly two coplanar strips")
    func topFaceResolvesToTwoStrips() throws {
        let c = try Self.makeChannelCut()
        try Self.absorb(c)

        // currentForms unions modified AND generated descendants, so the cut's new section edges
        // come back alongside the strips: two faces and two edges, and nothing else.
        let forms = c.graph.currentForms(of: c.pinnedTop)
        let strips = forms.filter { $0.kind == .face }
        let sections = forms.filter { $0.kind == .edge }
        #expect(strips.count == 2, "top face should survive the cut as two strips")
        #expect(sections.count == 2, "the walls of the channel cross the top in two edges")
        #expect(forms.count == strips.count + sections.count, "only faces and edges come back")

        // The strips must be the real geometry, not merely two arbitrary faces: the 10x10 top
        // minus a 10x2 channel leaves two 10x4 strips, still in the plane z = 10, either side
        // of the channel (area centroids at y = 2 and y = 8).
        var stripY: [Double] = []
        var total = 0.0
        for strip in strips {
            let area = try Self.faceArea(c.graph, strip)
            #expect(abs(area - 40.0) < 1e-6, "each strip should be 10 x 4 = 40, got \(area)")
            total += area
            let centroid = try Self.faceCentroid(c.graph, strip)
            #expect(abs(centroid.x - 5.0) < 1e-6, "strip \(strip) centroid \(centroid)")
            #expect(abs(centroid.z - 10.0) < 1e-6, "strip \(strip) centroid \(centroid)")
            stripY.append(centroid.y)
        }
        #expect(abs(total - 80.0) < 1e-6, "strips should total 80 (100 minus the 20 channel)")
        stripY.sort()
        try #require(stripY.count == 2)
        #expect(abs(stripY[0] - 2.0) < 1e-6, "strip centroids in y: \(stripY)")
        #expect(abs(stripY[1] - 8.0) < 1e-6, "strip centroids in y: \(stripY)")

        // The generated edges are the channel walls meeting the top: y = 4 and y = 6, each the
        // full 10 wide, midway along x and in the plane z = 10.
        var sectionY: [Double] = []
        for section in sections {
            let (midpoint, length) = try Self.edgeMidpointAndLength(c.graph, section)
            #expect(abs(length - 10.0) < 1e-6, "section edge length \(length)")
            #expect(abs(midpoint.x - 5.0) < 1e-6, "section edge midpoint \(midpoint)")
            #expect(abs(midpoint.z - 10.0) < 1e-6, "section edge midpoint \(midpoint)")
            sectionY.append(midpoint.y)
        }
        sectionY.sort()
        try #require(sectionY.count == 2)
        #expect(abs(sectionY[0] - 4.0) < 1e-6, "section edges in y: \(sectionY)")
        #expect(abs(sectionY[1] - 6.0) < 1e-6, "section edges in y: \(sectionY)")
    }

    @Test("splitOf resolves each strip by occurrence")
    func splitOfResolvesOccurrences() throws {
        let c = try Self.makeChannelCut()
        try Self.absorb(c)

        let first = try c.graph.resolve(.splitOf(original: .literal(c.pinnedTop), occurrence: 0))
            .get()
        let second = try c.graph.resolve(.splitOf(original: .literal(c.pinnedTop), occurrence: 1))
            .get()
        #expect(first != second, "occurrences 0 and 1 should be distinct strips")
        #expect(first.kind == .face && second.kind == .face)

        // The two it names are exactly the strips currentForms reports (the order between them
        // is OCCT's and is not pinned), each the 10 x 4 strip on its own side of the channel.
        let strips = Set(c.graph.currentForms(of: c.pinnedTop).filter { $0.kind == .face })
        #expect(Set([first, second]) == strips)
        var stripY: [Double] = []
        for strip in [first, second] {
            let area = try Self.faceArea(c.graph, strip)
            #expect(abs(area - 40.0) < 1e-6, "strip \(strip) area \(area)")
            stripY.append(try Self.faceCentroid(c.graph, strip).y)
        }
        stripY.sort()
        #expect(abs(stripY[0] - 2.0) < 1e-6, "strip centroids in y: \(stripY)")
        #expect(abs(stripY[1] - 8.0) < 1e-6, "strip centroids in y: \(stripY)")

        // Only two pieces: occurrence 2 is out of range, and says how many there are.
        let past = TopologyRef.splitOf(original: .literal(c.pinnedTop), occurrence: 2)
        #expect(
            c.graph.resolve(past)
                == .failure(.occurrenceOutOfRange(past, available: 2, requested: 2)))
    }

    @Test("createdBy matches the operation label the absorb recorded")
    func createdByMatchesLabel() throws {
        let c = try Self.makeChannelCut()
        try Self.absorb(c)

        // Every record the absorb wrote carries the label.
        let labelled = c.graph.historyRecords.filter { $0.operationName == "channel-cut" }
        #expect(labelled.count == c.graph.historyRecordCount)

        // The faces the absorb recorded as replacements, read straight from the records. Their
        // ORDER is not stable between runs (#3038), so only the set is pinned: the two notched
        // walls (100 less the 2 x 2 notch = 96 each) and the top's two strips (40 each).
        var recorded = Set<BRepGraph.NodeRef>()
        for record in labelled {
            for replacements in record.mapping.values {
                for replacement in replacements where replacement.kind == .face {
                    recorded.insert(replacement)
                }
            }
        }
        var areas: [Double] = []
        for face in recorded {
            areas.append(try Self.faceArea(c.graph, face))
        }
        areas.sort()
        try #require(areas.count == 4, "recorded face areas \(areas)")
        let expectedAreas: [Double] = [40.0, 40.0, 96.0, 96.0]
        for (area, expected) in zip(areas, expectedAreas) {
            #expect(abs(area - expected) < 1e-6, "recorded face areas \(areas)")
        }

        // createdBy enumerates exactly those faces, one per occurrence, and the forward walk adds
        // nothing because no later operation touched the result.
        var resolved = Set<BRepGraph.NodeRef>()
        for occurrence in 0..<recorded.count {
            let asCreated = try c.graph.resolve(
                .createdBy(
                    operationName: "channel-cut", kind: .face, occurrence: occurrence,
                    leafOccurrence: nil)
            ).get()
            let walked = try c.graph.resolve(
                .createdBy(operationName: "channel-cut", kind: .face, occurrence: occurrence)
            ).get()
            #expect(walked == asCreated, "occurrence \(occurrence)")
            resolved.insert(asCreated)
        }
        #expect(resolved == recorded, "createdBy found \(resolved), the records name \(recorded)")
        let past = TopologyRef.createdBy(
            operationName: "channel-cut", kind: .face, occurrence: recorded.count)
        let pastFailure = TopologyResolutionError.occurrenceOutOfRange(
            past, available: recorded.count, requested: recorded.count)
        #expect(c.graph.resolve(past) == .failure(pastFailure))

        // A label nothing recorded must not resolve, and says which one it looked for.
        let miss = c.graph.resolve(.createdBy(operationName: "never-happened", kind: .face))
        #expect(miss == .failure(.operationNotFound("never-happened")))

        // Another operation's records in the same log are not the absorb's: they resolve under
        // their own label and leave the absorb's candidates as they were.
        let foreign = BRepGraph.NodeRef(kind: .face, index: 999)
        c.graph.recordHistory(
            operationName: "other-op", original: .sentinel, replacements: [foreign])
        #expect(
            c.graph.resolve(.createdBy(operationName: "other-op", kind: .face)) == .success(foreign)
        )
        #expect(c.graph.resolve(past) == .failure(pastFailure), "still four candidates")
    }

    /// Without the absorb, none of the above works, this is what #290 reported.
    @Test("without absorbing, the graph log stays empty and recipes do not resolve")
    func withoutAbsorbNothingResolves() throws {
        let c = try Self.makeChannelCut()
        // Deliberately no add(_:absorbing:...) yet.
        #expect(c.graph.historyRecordCount == 0)
        #expect(c.graph.currentForms(of: c.pinnedTop) == [], "no history recorded, no successors")

        let split = TopologyRef.splitOf(original: .literal(c.pinnedTop), occurrence: 0)
        #expect(c.graph.resolve(split) == .failure(.noCurrentDescendant(split)))
        let created = TopologyRef.createdBy(operationName: "channel-cut", kind: .face)
        #expect(c.graph.resolve(created) == .failure(.operationNotFound("channel-cut")))

        // The control, on the same graph and with the same two recipes: the absorb is the only
        // thing that changes, and it is what makes them resolve.
        try Self.absorb(c)
        #expect(c.graph.historyRecordCount == Self.expectedRecordCount(c))
        #expect(!c.graph.currentForms(of: c.pinnedTop).isEmpty)
        let nowSplit = try c.graph.resolve(split).get()
        #expect(nowSplit.kind == .face)
        let nowCreated = try c.graph.resolve(created).get()
        #expect(nowCreated.kind == .face)
    }

    @Test("a node the operation never touched is neither derived nor deleted")
    func untouchedNodeIsNotDeleted() throws {
        let c = try Self.makeChannelCut()
        try Self.absorb(c)

        // The bottom face (z = 0) is nowhere near the channel: no record names it, nothing derives
        // from it, it is not deleted, and "where did it end up" answers itself.
        #expect(!c.graph.hasHistoryRecord(for: c.pinnedBottom), "no record names it")
        #expect(!c.graph.historyIsDeleted(c.pinnedBottom))
        #expect(c.graph.currentForms(of: c.pinnedBottom) == [], "nothing derives from it")
        #expect(c.graph.findDerivedOrSelf(of: c.pinnedBottom) == [c.pinnedBottom])

        // The control on the same graph: the top face the channel cut through IS named and does
        // have successors, and it is still not deleted, because splitting is not consuming.
        #expect(c.graph.hasHistoryRecord(for: c.pinnedTop))
        #expect(!c.graph.currentForms(of: c.pinnedTop).isEmpty)
        #expect(!c.graph.historyIsDeleted(c.pinnedTop), "split, not consumed")

        // The channel keeps an image of every node the box had, so nothing at all is deleted.
        for index in 0..<c.baseFaces {
            let face = BRepGraph.NodeRef(kind: .face, index: index)
            #expect(!c.graph.historyIsDeleted(face), "face \(index)")
        }
        for index in 0..<c.baseEdges {
            let edge = BRepGraph.NodeRef(kind: .edge, index: index)
            #expect(!c.graph.historyIsDeleted(edge), "edge \(index)")
        }
        for index in 0..<c.baseVertices {
            let vertex = BRepGraph.NodeRef(kind: .vertex, index: index)
            #expect(!c.graph.historyIsDeleted(vertex), "vertex \(index)")
        }
        #expect(c.graph.historyDeletedNodes.isEmpty)
    }

    @Test("a face the operation consumed is reported deleted, and only what it consumed")
    func consumedFaceIsReportedDeleted() throws {
        // A slab removes z in [8, 10] across the whole box, so the top face has no image at all.
        let c = try Self.makeSlabCut()
        let added = try Self.absorb(c, as: "slab-cut")
        let addedShape = try Self.shape(c.graph, added)
        let volume = try #require(addedShape.volume, "volume of the added root")
        #expect(abs(volume - 800.0) < 1e-6, "slab cut volume \(volume)")

        // The boolean's own verdict, the second construction: the top is consumed, the bottom not.
        #expect(c.history.record(of: c.topShape).isDeleted)
        #expect(!c.history.record(of: c.bottomShape).isDeleted)
        #expect(c.graph.historyIsDeleted(c.pinnedTop))
        #expect(!c.graph.historyIsDeleted(c.pinnedBottom))
        #expect(c.graph.currentForms(of: c.pinnedTop) == [], "a consumed face has no successors")
        #expect(c.graph.findDerivedOrSelf(of: c.pinnedTop) == [], "consumed, not untouched")

        // What the slab consumes is everything lying in the plane z = 10: the top face, its four
        // edges and its four corners. Everything else survives, shortened or untouched. That is a
        // truth table over every node the box had, derived from where each one sits.
        for index in 0..<c.baseFaces {
            let node = BRepGraph.NodeRef(kind: .face, index: index)
            let z = try Self.faceCentroid(c.graph, node).z
            #expect(
                c.graph.historyIsDeleted(node) == (abs(z - 10.0) < 1e-9), "face \(index), z \(z)")
        }
        for index in 0..<c.baseEdges {
            let node = BRepGraph.NodeRef(kind: .edge, index: index)
            let z = try Self.edgeMidpointAndLength(c.graph, node).midpoint.z
            #expect(
                c.graph.historyIsDeleted(node) == (abs(z - 10.0) < 1e-9), "edge \(index), z \(z)")
        }
        for index in 0..<c.baseVertices {
            let node = BRepGraph.NodeRef(kind: .vertex, index: index)
            let z = c.graph.vertexPoint(index).z
            #expect(
                c.graph.historyIsDeleted(node) == (abs(z - 10.0) < 1e-9), "vertex \(index), z \(z)")
        }

        // And the deleted set reports the same nine, one face, four edges and four vertices.
        let deleted = c.graph.historyDeletedNodes
        #expect(deleted.count == 9)
        #expect(deleted.contains(c.pinnedTop))
        #expect(deleted.filter { $0.kind == .face }.count == 1)
        #expect(deleted.filter { $0.kind == .edge }.count == 4)
        #expect(deleted.filter { $0.kind == .vertex }.count == 4)
        for node in deleted {
            #expect(c.graph.historyIsDeleted(node), "\(node) is in the deleted set")
        }
    }
}
