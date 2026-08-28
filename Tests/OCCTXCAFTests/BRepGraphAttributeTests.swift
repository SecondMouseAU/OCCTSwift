import Foundation
import Testing

@testable import OCCTSwift

// MARK: - BRepGraph attribute store + Codable snapshot (#168)

@Suite("BRepGraph Attributes")
struct BRepGraphAttributeTests {

    /// Attach mixed attribute types to face/edge/vertex nodes and read them back.
    @Test func attachAndReadMixedAttributes() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let graph = BRepGraph(shape: box)
        else { return }

        let faceNode = BRepGraph.NodeRef(kind: .face, index: 0)
        let edgeNode = BRepGraph.NodeRef(kind: .edge, index: 0)
        let vertexNode = BRepGraph.NodeRef(kind: .vertex, index: 0)

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
    }

    /// Clearing the last attribute on a node drops the node entry entirely.
    @Test func clearingLastAttributeDropsNode() {
        guard let box = Shape.box(width: 5, height: 5, depth: 5),
            let graph = BRepGraph(shape: box)
        else { return }
        let node = BRepGraph.NodeRef(kind: .face, index: 1)
        graph.setAttribute("a", .int(1), for: node)
        graph.setAttribute("b", .int(2), for: node)
        #expect(graph.attributes.annotatedNodeCount == 1)
        graph.attributes.clear("a", for: node)
        #expect(graph.attribute("b", for: node)?.intValue == 2)
        #expect(graph.attributes.annotatedNodeCount == 1)
        graph.attributes.clear("b", for: node)
        #expect(graph.attributes.annotatedNodeCount == 0)
    }

    /// snapshot() -> JSON encode -> decode -> init(snapshot:) reproduces every attribute
    /// on the correct node.
    @Test func snapshotJSONRoundTrip() throws {
        guard let box = Shape.box(width: 12, height: 8, depth: 4),
            let graph = BRepGraph(shape: box)
        else { return }

        let f0 = BRepGraph.NodeRef(kind: .face, index: 0)
        let f3 = BRepGraph.NodeRef(kind: .face, index: 3)
        let v2 = BRepGraph.NodeRef(kind: .vertex, index: 2)
        graph.setAttribute("residualRMS", .double(0.001), for: f0)
        graph.setAttribute("decision", .string("human"), for: f3)
        graph.setAttribute("mirror", .bool(true), for: f3)
        graph.setAttribute("tris", .ints([1, 2, 3]), for: v2)

        let snap = try graph.snapshot()
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(GraphSnapshot.self, from: data)
        let restored = try BRepGraph(snapshot: decoded)

        #expect(restored.faceCount == graph.faceCount)
        #expect(restored.vertexCount == graph.vertexCount)
        #expect(restored.attribute("residualRMS", for: f0)?.doubleValue == 0.001)
        #expect(restored.attribute("decision", for: f3)?.stringValue == "human")
        #expect(restored.attribute("mirror", for: f3)?.boolValue == true)
        #expect(restored.attribute("tris", for: v2)?.intsValue == [1, 2, 3])
        #expect(restored.attributes == graph.attributes)
    }

    /// With the canonical (`.sortedKeys`) encoder the store is byte-stable across encodes,
    /// the contract for diffable, versionable snapshots.
    @Test func encodingIsDeterministic() throws {
        guard let box = Shape.box(width: 3, height: 3, depth: 3),
            let graph = BRepGraph(shape: box)
        else { return }
        for i in 0..<graph.faceCount {
            graph.setAttribute("idx", .int(i), for: BRepGraph.NodeRef(kind: .face, index: i))
        }
        let encoder = GraphSnapshot.canonicalEncoder()
        let a = try encoder.encode(graph.attributes)
        let b = try encoder.encode(graph.attributes)
        #expect(a == b)
    }

    /// NodeRef indexing is deterministic across rebuilds of the same BREP, the property the
    /// snapshot round-trip relies on. Verify a node index resolves to the same geometry.
    @Test func nodeIndexingDeterministicAcrossRebuild() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let g1 = BRepGraph(shape: box),
            let brep = box.toBREPString(),
            let box2 = Shape.fromBREPString(brep),
            let g2 = BRepGraph(shape: box2)
        else { return }

        #expect(g1.faceCount == g2.faceCount)
        #expect(g1.edgeCount == g2.edgeCount)
        #expect(g1.vertexCount == g2.vertexCount)

        // Same vertex index must map to the same point in both builds.
        for i in 0..<g1.vertexCount {
            let p1 = g1.vertexPoint(i)
            let p2 = g2.vertexPoint(i)
            #expect(abs(p1.x - p2.x) < 1e-9)
            #expect(abs(p1.y - p2.y) < 1e-9)
            #expect(abs(p1.z - p2.z) < 1e-9)
        }
    }

    /// A snapshot from a newer format version is rejected.
    @Test func futureFormatVersionRejected() {
        guard let box = Shape.box(width: 2, height: 2, depth: 2),
            let brep = box.toBREPString()
        else { return }
        let future = GraphSnapshot(
            brep: brep, attributes: NodeAttributeStore(),
            formatVersion: GraphSnapshot.currentFormatVersion + 1)
        #expect(throws: GraphSnapshotError.self) {
            _ = try BRepGraph(snapshot: future)
        }
    }

    /// Invalid BREP in a snapshot throws rather than crashing.
    @Test func invalidBREPThrows() {
        let bad = GraphSnapshot(brep: "not a brep", attributes: NodeAttributeStore())
        #expect(throws: GraphSnapshotError.self) {
            _ = try BRepGraph(snapshot: bad)
        }
    }
}
