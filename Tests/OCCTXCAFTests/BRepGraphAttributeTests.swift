import Foundation
import Testing

@testable import OCCTSwift

// MARK: - BRepGraph attribute store + Codable snapshot (#168)

@Suite("BRepGraph Attributes")
struct BRepGraphAttributeTests {

    /// Attach mixed attribute types to face/edge/vertex nodes and read them back.
    @Test func attachAndReadMixedAttributes() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let graph = try #require(BRepGraph(shape: box))

        let faceNode = BRepGraph.NodeRef(kind: .face, index: 0)
        let edgeNode = BRepGraph.NodeRef(kind: .edge, index: 0)
        let vertexNode = BRepGraph.NodeRef(kind: .vertex, index: 0)
        let otherFace = BRepGraph.NodeRef(kind: .face, index: 1)

        graph.setAttribute("residualRMS", .double(0.042), for: faceNode)
        graph.setAttribute("surfaceType", .string("plane"), for: faceNode)
        graph.setAttribute("params", .doubles([0, 0, 1, 5]), for: faceNode)
        graph.setAttribute("sharp", .bool(true), for: edgeNode)
        graph.setAttribute("regionTriangles", .ints([3, 7, 11, 19]), for: vertexNode)

        #expect(graph.attribute("residualRMS", for: faceNode)?.doubleValue == 0.042)
        #expect(graph.attribute("surfaceType", for: faceNode)?.stringValue == "plane")
        #expect(graph.attribute("params", for: faceNode)?.doublesValue == [0, 0, 1, 5])
        #expect(graph.attribute("sharp", for: edgeNode)?.boolValue == true)
        #expect(graph.attribute("regionTriangles", for: vertexNode)?.intsValue == [3, 7, 11, 19])
        #expect(graph.attribute("missing", for: faceNode) == nil)
        #expect(graph.attributes.annotatedNodeCount == 3)

        // The value comes back as the case it was stored as, and the unwrap accessors answer nil
        // for any other case instead of coercing.
        #expect(graph.attribute("residualRMS", for: faceNode) == .double(0.042))
        #expect(graph.attribute("residualRMS", for: faceNode)?.intValue == nil)
        #expect(graph.attribute("residualRMS", for: faceNode)?.stringValue == nil)
        #expect(graph.attribute("sharp", for: edgeNode)?.intValue == nil)

        // An attribute belongs to its node: a key set on a node is absent from the same index of
        // another node, and from the same index of another kind.
        #expect(graph.attribute("residualRMS", for: otherFace) == nil)
        #expect(graph.attribute("residualRMS", for: edgeNode) == nil)
        #expect(graph.attribute("sharp", for: faceNode) == nil)
        #expect(graph.attribute("sharp", for: vertexNode) == nil)
        #expect(Set(graph.attributes[faceNode].keys) == ["residualRMS", "surfaceType", "params"])
        #expect(Set(graph.attributes[edgeNode].keys) == ["sharp"])
        #expect(Set(graph.attributes[vertexNode].keys) == ["regionTriangles"])

        // One key on three kinds at the same index keeps three values.
        graph.setAttribute("tag", .int(1), for: faceNode)
        graph.setAttribute("tag", .int(2), for: edgeNode)
        graph.setAttribute("tag", .int(3), for: vertexNode)
        #expect(graph.attribute("tag", for: faceNode)?.intValue == 1)
        #expect(graph.attribute("tag", for: edgeNode)?.intValue == 2)
        #expect(graph.attribute("tag", for: vertexNode)?.intValue == 3)
        #expect(graph.attribute("tag", for: otherFace) == nil)
        #expect(graph.attributes.annotatedNodeCount == 3)

        // Setting a key again replaces it, and the node's other attributes stay.
        graph.setAttribute("residualRMS", .double(0.5), for: faceNode)
        #expect(graph.attribute("residualRMS", for: faceNode)?.doubleValue == 0.5)
        #expect(graph.attribute("surfaceType", for: faceNode)?.stringValue == "plane")
        #expect(graph.attributes[faceNode].count == 4)
    }

    /// Clearing the last attribute on a node drops the node entry entirely.
    @Test func clearingLastAttributeDropsNode() throws {
        let box = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let graph = try #require(BRepGraph(shape: box))
        let node = BRepGraph.NodeRef(kind: .face, index: 1)
        let other = BRepGraph.NodeRef(kind: .face, index: 2)
        graph.setAttribute("a", .int(1), for: node)
        graph.setAttribute("b", .int(2), for: node)
        graph.setAttribute("a", .int(10), for: other)
        #expect(graph.attributes.annotatedNodeCount == 2)

        graph.attributes.clear("a", for: node)
        #expect(graph.attribute("a", for: node) == nil)
        #expect(graph.attribute("b", for: node)?.intValue == 2)
        // Only that key, only on that node: the other node's "a" is still there.
        #expect(graph.attribute("a", for: other)?.intValue == 10)
        #expect(graph.attributes.annotatedNodeCount == 2)

        // Clearing a key the node does not carry changes nothing.
        graph.attributes.clear("absent", for: node)
        #expect(graph.attribute("b", for: node)?.intValue == 2)
        #expect(graph.attributes.annotatedNodeCount == 2)

        graph.attributes.clear("b", for: node)
        #expect(graph.attributes.annotatedNodeCount == 1)
        #expect(graph.attributes[node].isEmpty)
        #expect(graph.attribute("a", for: other)?.intValue == 10)

        // removeAll drops a node's whole entry and leaves the others.
        graph.setAttribute("x", .bool(false), for: node)
        graph.setAttribute("y", .bool(true), for: node)
        graph.attributes.removeAll(for: node)
        #expect(graph.attributes[node].isEmpty)
        #expect(graph.attributes.annotatedNodeCount == 1)
        #expect(graph.attribute("a", for: other)?.intValue == 10)
    }

    /// snapshot() -> JSON encode -> decode -> init(snapshot:) reproduces every attribute
    /// on the correct node.
    @Test func snapshotJSONRoundTrip() throws {
        let box = try #require(Shape.box(width: 12, height: 8, depth: 4))
        let graph = try #require(BRepGraph(shape: box))

        let f0 = BRepGraph.NodeRef(kind: .face, index: 0)
        let f3 = BRepGraph.NodeRef(kind: .face, index: 3)
        let v2 = BRepGraph.NodeRef(kind: .vertex, index: 2)
        graph.setAttribute("residualRMS", .double(0.001), for: f0)
        graph.setAttribute("decision", .string("human"), for: f3)
        graph.setAttribute("mirror", .bool(true), for: f3)
        graph.setAttribute("tris", .ints([1, 2, 3]), for: v2)

        let snap = try graph.snapshot()
        #expect(snap.formatVersion == GraphSnapshot.currentFormatVersion)
        #expect(!snap.brep.isEmpty)
        #expect(snap.attributes == graph.attributes)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(GraphSnapshot.self, from: data)
        #expect(decoded == snap)
        let restored = try BRepGraph(snapshot: decoded)

        // A box: six faces, twelve edges, eight vertices.
        #expect(restored.faceCount == 6)
        #expect(restored.edgeCount == 12)
        #expect(restored.vertexCount == 8)
        #expect(restored.faceCount == graph.faceCount)
        #expect(restored.vertexCount == graph.vertexCount)
        #expect(restored.attribute("residualRMS", for: f0)?.doubleValue == 0.001)
        #expect(restored.attribute("decision", for: f3)?.stringValue == "human")
        #expect(restored.attribute("mirror", for: f3)?.boolValue == true)
        #expect(restored.attribute("tris", for: v2)?.intsValue == [1, 2, 3])
        // On the correct node and no other, and nothing more than was written.
        #expect(restored.attribute("residualRMS", for: f3) == nil)
        #expect(restored.attribute("decision", for: f0) == nil)
        #expect(restored.attributes.annotatedNodeCount == 3)
        #expect(restored.attributes == graph.attributes)

        // The restored graph carries its source, so it can be snapshotted again unchanged.
        let again = try restored.snapshot()
        #expect(again.attributes == snap.attributes)
        #expect(again.formatVersion == snap.formatVersion)
    }

    /// With the canonical (`.sortedKeys`) encoder the store is byte-stable across encodes,
    /// the contract for diffable, versionable snapshots.
    @Test func encodingIsDeterministic() throws {
        let box = try #require(Shape.box(width: 3, height: 3, depth: 3))
        let graph = try #require(BRepGraph(shape: box))
        for i in 0..<graph.faceCount {
            graph.setAttribute("idx", .int(i), for: BRepGraph.NodeRef(kind: .face, index: i))
        }
        let encoder = GraphSnapshot.canonicalEncoder()
        let a = try encoder.encode(graph.attributes)
        let b = try encoder.encode(graph.attributes)
        #expect(a == b)

        // Two encodes of one value agree in-process whatever the order is, because a dictionary
        // iterates the same way twice, so equality alone proves nothing about the contract. The
        // contract is the order itself: nodes by kind then index, keys in sorted order, object
        // keys sorted. Written out by hand for a store filled in a deliberately different order
        // (a later kind, a later index and a later key first).
        let face3 = BRepGraph.NodeRef(kind: .face, index: 3)
        let edge0 = BRepGraph.NodeRef(kind: .edge, index: 0)
        let vertex2 = BRepGraph.NodeRef(kind: .vertex, index: 2)
        var store = NodeAttributeStore()
        store.set("z", .doubles([1, 2]), for: vertex2)
        store.set("k", .bool(true), for: edge0)
        store.set("b", .int(2), for: face3)
        store.set("a", .string("x"), for: face3)
        let json = try #require(String(data: try encoder.encode(store), encoding: .utf8))
        let expected =
            #"[{"attrs":[{"key":"a","value":{"string":{"_0":"x"}}},{"key":"b","value":{"int":{"_0":2}}}],"node":{"index":3,"kind":2}},"#
            + #"{"attrs":[{"key":"k","value":{"bool":{"_0":true}}}],"node":{"index":0,"kind":4}},"#
            + #"{"attrs":[{"key":"z","value":{"doubles":{"_0":[1,2]}}}],"node":{"index":2,"kind":5}}]"#
        #expect(json == expected)

        // And it decodes back to the store it came from.
        let back = try JSONDecoder().decode(NodeAttributeStore.self, from: Data(json.utf8))
        #expect(back == store)
    }

    /// NodeRef indexing is deterministic across rebuilds of the same BREP, the property the
    /// snapshot round-trip relies on.
    ///
    /// Verify a node index resolves to the same geometry.
    @Test func nodeIndexingDeterministicAcrossRebuild() throws {
        // 10.5 x 20.25 x 30.5: halves that are not whole numbers (5.25, 10.125, 15.25, exact in
        // binary), so a coordinate truncated to an integer is not the corner.
        let box = try #require(Shape.box(width: 10.5, height: 20.25, depth: 30.5))
        let g1 = try #require(BRepGraph(shape: box))
        let brep = try #require(box.toBREPString())
        let box2 = try #require(Shape.fromBREPString(brep))
        let g2 = try #require(BRepGraph(shape: box2))

        #expect(g1.faceCount == 6)
        #expect(g1.edgeCount == 12)
        #expect(g1.vertexCount == 8)
        #expect(g1.faceCount == g2.faceCount)
        #expect(g1.edgeCount == g2.edgeCount)
        #expect(g1.vertexCount == g2.vertexCount)

        // Same vertex index must map to the same point in both builds, and the point is a real
        // corner of the 10.5 x 20.25 x 30.5 box centred on the origin. Comparing the two builds alone
        // would pass for an accessor that answered the same point (or the wrong vertex) for
        // every index, so the eight corners are written out in the order this kernel numbers
        // them (x slowest, z fastest), which is measured and is what makes the check
        // index-by-index.
        let corners: [(Double, Double, Double)] = [
            (-5.25, -10.125, -15.25), (-5.25, -10.125, 15.25), (-5.25, 10.125, -15.25),
            (-5.25, 10.125, 15.25), (5.25, -10.125, -15.25), (5.25, -10.125, 15.25),
            (5.25, 10.125, -15.25), (5.25, 10.125, 15.25),
        ]
        // The count is required before the index is used, so a count that over-reports fails
        // above instead of indexing past the list.
        for i in 0..<min(g1.vertexCount, corners.count) {
            let p1 = g1.vertexPoint(i)
            let p2 = g2.vertexPoint(i)
            #expect(abs(p1.x - p2.x) < 1e-9)
            #expect(abs(p1.y - p2.y) < 1e-9)
            #expect(abs(p1.z - p2.z) < 1e-9)
            #expect(abs(p1.x - corners[i].0) < 1e-9, "vertex \(i) x \(p1.x)")
            #expect(abs(p1.y - corners[i].1) < 1e-9, "vertex \(i) y \(p1.y)")
            #expect(abs(p1.z - corners[i].2) < 1e-9, "vertex \(i) z \(p1.z)")
        }
    }

    /// A snapshot from a newer format version is rejected.
    @Test func futureFormatVersionRejected() throws {
        let box = try #require(Shape.box(width: 2, height: 2, depth: 2))
        let brep = try #require(box.toBREPString())
        let next = GraphSnapshot.currentFormatVersion + 1

        // Control: the same snapshot at the current version restores, so the refusal below is
        // the version's and not a snapshot that cannot be restored for another reason.
        let current = GraphSnapshot(brep: brep, attributes: NodeAttributeStore())
        let restored = try BRepGraph(snapshot: current)
        #expect(restored.faceCount == 6)

        let future = GraphSnapshot(
            brep: brep, attributes: NodeAttributeStore(), formatVersion: next)
        // The specific error, carrying the version it saw.
        #expect(throws: GraphSnapshotError.unsupportedFormatVersion(next)) {
            _ = try BRepGraph(snapshot: future)
        }
    }

    /// Invalid BREP in a snapshot throws rather than crashing.
    @Test func invalidBREPThrows() {
        let bad = GraphSnapshot(brep: "not a brep", attributes: NodeAttributeStore())
        #expect(throws: GraphSnapshotError.invalidBREP) {
            _ = try BRepGraph(snapshot: bad)
        }
    }
}
