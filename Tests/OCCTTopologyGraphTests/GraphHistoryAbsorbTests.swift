import Testing
import Foundation
@testable import OCCTSwift

/// Carrying a durable face reference across a boolean split (issue #290).
///
/// The scenario throughout is the reporter's: a 10×10×10 box with a bar cut
/// across its top (Y ∈ [4, 6], full X width), splitting the single 10×10 top
/// face into two 10×4 strips. Assertions are geometric rather than count-only —
/// "two nodes came back" is not evidence they are the right two.
@Suite("Graph history absorb (#290)")
struct GraphHistoryAbsorbTests {

    /// The reporter's scenario, assembled once.
    struct Cut {
        let base: Shape
        let graph: TopologyGraph
        let root: TopologyGraph.NodeRef
        /// The top face's node, pinned before the cut.
        let pinnedTop: TopologyGraph.NodeRef
        let result: Shape
        let history: ShapeHistoryRef
    }

    static func makeCut() -> Cut? {
        guard let base = Shape.box(origin: SIMD3<Double>(0, 0, 0),
                                   width: 10, height: 10, depth: 10),
              let graph = TopologyGraph(shape: base),
              let rootNode = graph.findNode(for: base) else { return nil }

        let faces = base.faces()
        let centroids = base.measure().faceCentroids
        guard let topIndex = centroids.enumerated()
                .max(by: { $0.element.z < $1.element.z })?.offset,
              let topFace = Shape.fromFace(faces[topIndex]),
              let topNode = graph.findNode(for: topFace) else { return nil }

        guard let tool = Shape.box(origin: SIMD3<Double>(-1, 4, 8),
                                   width: 12, height: 2, depth: 4),
              let (result, history) = base.subtractedWithFullHistory(tool) else { return nil }

        return Cut(base: base,
                   graph: graph,
                   root: TopologyGraph.NodeRef(kind: rootNode.kind, index: rootNode.index),
                   pinnedTop: TopologyGraph.NodeRef(kind: topNode.kind, index: topNode.index),
                   result: result,
                   history: history)
    }

    /// Area of the face a node reconstructs to.
    static func faceArea(_ graph: TopologyGraph, _ node: TopologyGraph.NodeRef) -> Double? {
        guard let shape = graph.shape(nodeKind: node.kind, nodeIndex: node.index) else { return nil }
        let areas = shape.measure().faceAreas
        guard !areas.isEmpty else { return nil }
        return areas.reduce(0, +)
    }

    @Test("absorbing a boolean's history writes records into the input graph")
    func absorbWritesRecords() {
        guard let c = Self.makeCut() else { Issue.record("setup failed"); return }
        #expect(c.graph.historyRecordCount == 0, "graph should start with an empty history log")

        let added = c.graph.add(c.result, absorbing: c.history,
                                inputRoots: [c.root], operationName: "channel-cut")

        #expect(added != nil, "add should return the result's topology root")
        #expect(c.graph.historyRecordCount > 0, "absorb should have written history records")
    }

    /// The core of #290: the pre-cut face resolves to its two successor strips.
    @Test("pre-cut top face resolves to exactly two coplanar strips")
    func topFaceResolvesToTwoStrips() {
        guard let c = Self.makeCut() else { Issue.record("setup failed"); return }
        c.graph.add(c.result, absorbing: c.history,
                    inputRoots: [c.root], operationName: "channel-cut")

        // currentForms unions modified AND generated descendants, so the cut's new
        // section edges come back alongside the strips. Filter to faces.
        let strips = c.graph.currentForms(of: c.pinnedTop).filter { $0.kind == .face }
        #expect(strips.count == 2, "top face should survive the cut as two strips")

        // The strips must be the real geometry, not merely two arbitrary faces:
        // the 10x10 top minus a 10x2 channel leaves two 10x4 strips.
        for strip in strips {
            if let area = Self.faceArea(c.graph, strip) {
                #expect(abs(area - 40.0) < 1e-6, "each strip should be 10 x 4 = 40, got \(area)")
            } else {
                Issue.record("strip \(strip) did not reconstruct to a shape")
            }
        }

        let total = strips.compactMap { Self.faceArea(c.graph, $0) }.reduce(0, +)
        #expect(abs(total - 80.0) < 1e-6, "strips should total 80 (100 minus the 20 channel)")
    }

    @Test("splitOf resolves each strip by occurrence")
    func splitOfResolvesOccurrences() {
        guard let c = Self.makeCut() else { Issue.record("setup failed"); return }
        c.graph.add(c.result, absorbing: c.history,
                    inputRoots: [c.root], operationName: "channel-cut")

        let first = c.graph.resolve(.splitOf(original: .literal(c.pinnedTop), occurrence: 0))
        let second = c.graph.resolve(.splitOf(original: .literal(c.pinnedTop), occurrence: 1))

        switch (first, second) {
        case let (.success(a), .success(b)):
            #expect(a != b, "occurrences 0 and 1 should be distinct strips")
            #expect(a.kind == .face && b.kind == .face)
            if let areaA = Self.faceArea(c.graph, a), let areaB = Self.faceArea(c.graph, b) {
                #expect(abs(areaA - 40.0) < 1e-6, "strip 0 area \(areaA)")
                #expect(abs(areaB - 40.0) < 1e-6, "strip 1 area \(areaB)")
            }
        default:
            Issue.record("splitOf failed to resolve: \(first), \(second)")
        }
    }

    @Test("createdBy matches the operation label the absorb recorded")
    func createdByMatchesLabel() {
        guard let c = Self.makeCut() else { Issue.record("setup failed"); return }
        c.graph.add(c.result, absorbing: c.history,
                    inputRoots: [c.root], operationName: "channel-cut")

        let hit = c.graph.resolve(.createdBy(operationName: "channel-cut", kind: .face))
        if case .failure(let e) = hit {
            Issue.record("createdBy should resolve against the absorbed label, got \(e)")
        }

        // A label nothing recorded must not resolve.
        let miss = c.graph.resolve(.createdBy(operationName: "never-happened", kind: .face))
        if case .success(let n) = miss {
            Issue.record("an unrecorded label should not resolve, got \(n)")
        }
    }

    /// Without the absorb, none of the above works — this is what #290 reported.
    @Test("without absorbing, the graph log stays empty and recipes do not resolve")
    func withoutAbsorbNothingResolves() {
        guard let c = Self.makeCut() else { Issue.record("setup failed"); return }
        // Deliberately no add(_:absorbing:...).
        #expect(c.graph.historyRecordCount == 0)
        #expect(c.graph.currentForms(of: c.pinnedTop).isEmpty,
                "no history recorded, so no successors")

        let r = c.graph.resolve(.splitOf(original: .literal(c.pinnedTop), occurrence: 0))
        if case .success = r {
            Issue.record("splitOf must not resolve with an empty history log")
        }
    }

    @Test("a node the operation never touched is neither derived nor deleted")
    func untouchedNodeIsNotDeleted() {
        guard let c = Self.makeCut() else { Issue.record("setup failed"); return }
        c.graph.add(c.result, absorbing: c.history,
                    inputRoots: [c.root], operationName: "channel-cut")

        // The bottom face (z = 0) is nowhere near the channel.
        let faces = c.base.faces()
        let centroids = c.base.measure().faceCentroids
        guard let bottomIndex = centroids.enumerated()
                .min(by: { $0.element.z < $1.element.z })?.offset,
              let bottomFace = Shape.fromFace(faces[bottomIndex]),
              let bottomNode = c.graph.findNode(for: bottomFace) else {
            Issue.record("bottom face lookup failed"); return
        }
        let bottom = TopologyGraph.NodeRef(kind: bottomNode.kind, index: bottomNode.index)

        #expect(!c.graph.historyIsDeleted(bottom),
                "an untouched face must not be reported as deleted")
    }
}
