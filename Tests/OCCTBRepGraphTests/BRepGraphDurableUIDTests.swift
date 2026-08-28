import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Durable Identity (UID / RefUID / ItemUID), OCCT 8.0.0p1

@Suite("BRepGraph Durable UID")
struct BRepGraphDurableUIDTests {
    // Face kind ordinal in BRepGraph_NodeId::Kind is 2.
    private let faceKind = 2

    @Test func nodeUIDRoundTrip() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let graph = BRepGraph(shape: box) else { return }
        #expect(graph.faceCount == 6)

        // Every face should yield a valid UID that round-trips back to the same node.
        for i in 0..<graph.faceCount {
            guard let uid = graph.uid(ofNodeKind: faceKind, index: i) else {
                Issue.record("face \(i) had no UID")
                continue
            }
            #expect(uid.isValid)
            #expect(graph.contains(uid: uid))
            if let resolved = graph.node(forUID: uid) {
                #expect(resolved.kind == faceKind)
                #expect(resolved.index == i)
            } else {
                Issue.record("UID for face \(i) did not resolve")
            }
        }
    }

    /// A UID minted by a *different* graph must not resolve, the case that matters, and the one
    /// that silently returned a wrong node before #295. Its counter is in range for the foreign
    /// graph (counters restart at 1 per graph), so nothing but provenance can reject it.
    @Test func uidFromAnotherGraphDoesNotResolve() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let cyl = Shape.cylinder(radius: 3, height: 7),
            let boxGraph = BRepGraph(shape: box),
            let cylGraph = BRepGraph(shape: cyl)
        else { return }

        guard let boxFaceUID = boxGraph.uid(ofNodeKind: faceKind, index: 2) else {
            Issue.record("box face 2 had no UID")
            return
        }
        // Precondition for the test to be meaningful: the counter is one the cylinder graph
        // would consider perfectly valid, and did resolve to a cylinder face before the fix.
        #expect(boxFaceUID.counter <= UInt32(cylGraph.faceCount))

        #expect(cylGraph.node(forUID: boxFaceUID) == nil)
        #expect(!cylGraph.contains(uid: boxFaceUID))
        // ...while it still resolves in the graph that minted it.
        #expect(boxGraph.node(forUID: boxFaceUID) != nil)
    }

    /// Two graphs over the *same* shape are still two graphs: identity is the instance, not the
    /// geometry. This is the case a consumer is most likely to assume works.
    @Test func uidDoesNotCrossIdenticallyBuiltGraphs() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let a = BRepGraph(shape: box),
            let b = BRepGraph(shape: box)
        else { return }
        #expect(a.instanceID != b.instanceID)
        guard let uid = a.uid(ofNodeKind: faceKind, index: 1) else { return }
        #expect(b.node(forUID: uid) == nil)
        #expect(!b.contains(uid: uid))
    }

    /// Mean sampled position + normal, a signature that actually distinguishes a box's faces.
    /// (A single grid corner does not: adjacent faces share corners.)
    private func faceSignature(
        _ g: BRepGraph, _ i: Int,
        shift: SIMD3<Double> = .zero
    ) -> String? {
        guard let s = g.sampleFaceUVGrid(faceIndex: i, uSamples: 3, vSamples: 3),
            !s.positions.isEmpty, !s.normals.isEmpty
        else { return nil }
        var c = SIMD3<Double>(0, 0, 0)
        for p in s.positions { c += p }
        c = c / Double(s.positions.count) - shift
        var n = SIMD3<Double>(0, 0, 0)
        for v in s.normals { n += v }
        n /= Double(s.normals.count)
        return String(format: "c(%.3f,%.3f,%.3f) n(%.3f,%.3f,%.3f)", c.x, c.y, c.z, n.x, n.y, n.z)
    }

    /// A full `copy()` INHERITS the source's identity, so every source UID still resolves, and
    /// resolves to the geometrically same face. This is the kernel's own contract, not an
    /// accident: `BRepGraph_Copy::Perform` transplants the UID counter space, the Generation and
    /// the GraphGUID into the target. Guards the #295 provenance check against over-rejecting.
    @Test func uidSurvivesAFullCopyAndNamesTheSameFace() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let graph = BRepGraph(shape: box),
            let copy = graph.copy()
        else { return }
        #expect(copy.instanceID == graph.instanceID)  // a copy is the same identity
        #expect(copy.faceCount == graph.faceCount)

        // The signature must actually discriminate, or the assertions below prove nothing.
        let sigs = (0..<graph.faceCount).compactMap { faceSignature(graph, $0) }
        #expect(Set(sigs).count == graph.faceCount)

        for i in 0..<graph.faceCount {
            guard let uid = graph.uid(ofNodeKind: faceKind, index: i) else { continue }
            guard let r = copy.node(forUID: uid) else {
                Issue.record("face \(i)'s UID stopped resolving through copy()")
                continue
            }
            #expect(faceSignature(graph, i) == faceSignature(copy, r.index))
        }
    }

    /// `translated()` copies the graph wholesale too, so identity and UID correspondence carry
    /// across exactly as with `copy()`, the faces are merely moved.
    @Test func uidSurvivesATranslationAndNamesTheSameFace() {
        let d = SIMD3<Double>(100, 200, 300)
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let graph = BRepGraph(shape: box),
            let moved = graph.translated(dx: d.x, dy: d.y, dz: d.z)
        else { return }
        #expect(moved.instanceID == graph.instanceID)
        for i in 0..<graph.faceCount {
            guard let uid = graph.uid(ofNodeKind: faceKind, index: i) else { continue }
            guard let r = moved.node(forUID: uid) else {
                Issue.record("face \(i)'s UID stopped resolving through translated()")
                continue
            }
            #expect(faceSignature(graph, i) == faceSignature(moved, r.index, shift: d))
        }
    }

    /// `copyFace()` is the opposite case: it lifts ONE face into an empty graph without
    /// transplanting the counter space, so the extracted face restarts at counter 1, the
    /// source's face-0 counter. Before #295 a source UID resolved here and returned the wrong
    /// face. The extracted graph gets a fresh identity, so it now returns nil.
    @Test func uidDoesNotCrossACopiedOutFace() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let graph = BRepGraph(shape: box),
            let lifted = graph.copyFace(3)
        else { return }
        #expect(lifted.instanceID != graph.instanceID)
        #expect(lifted.faceCount == 1)
        // The lifted face IS source face 3, sitting at index 0.
        #expect(faceSignature(lifted, 0) == faceSignature(graph, 3))

        // Source face 0's counter (1) is in range here and used to return face 3.
        guard let uidFace0 = graph.uid(ofNodeKind: faceKind, index: 0) else { return }
        #expect(uidFace0.counter == 1)
        #expect(lifted.node(forUID: uidFace0) == nil)
        #expect(!lifted.contains(uid: uidFace0))
    }

    /// An out-of-range counter must not resolve either. Stamped with this graph's own id, so it
    /// tests the counter path rather than being rejected on provenance first.
    @Test func outOfRangeCounterDoesNotResolve() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let graph = BRepGraph(shape: box) else { return }

        let bogus = BRepGraph.GraphUID(kind: faceKind, counter: 999_999, graphID: graph.instanceID)
        #expect(!graph.contains(uid: bogus))
        #expect(graph.node(forUID: bogus) == nil)

        // The invalid sentinel (counter 0) is never valid.
        let invalid = BRepGraph.GraphUID(kind: faceKind, counter: 0, graphID: graph.instanceID)
        #expect(!invalid.isValid)
        #expect(!graph.contains(uid: invalid))
    }

    /// A UID with no provenance, hand-built, or decoded from a pre-#295 payload, resolves nowhere,
    /// even when its counter names a real node in the graph asked.
    @Test func unstampedUIDResolvesNowhere() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let graph = BRepGraph(shape: box) else { return }
        guard let real = graph.uid(ofNodeKind: faceKind, index: 0) else { return }

        let unstamped = BRepGraph.GraphUID(kind: real.kind, counter: real.counter, graphID: 0)
        #expect(unstamped.isValid)  // the counter is a real one...
        #expect(graph.node(forUID: unstamped) == nil)  // ...but it names no graph
        #expect(!graph.contains(uid: unstamped))
    }

    /// The property the UID exists for: it survives a mutation that renumbers indices, within the
    /// graph that minted it. Guards against the #295 provenance check over-rejecting.
    @Test func uidSurvivesCompactionOfItsOwnGraph() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box),
            let uid = graph.uid(ofNodeKind: faceKind, index: 3)
        else { return }
        let idBefore = graph.instanceID
        graph.compact()
        #expect(graph.instanceID == idBefore)  // compaction mutates in place; same instance
        #expect(graph.contains(uid: uid))
        #expect(graph.node(forUID: uid) != nil)
    }

    /// Provenance travels through `Codable`; a pre-#295 payload (no `graphID`) still decodes,
    /// as an unstamped UID rather than a decode failure.
    @Test func uidCodableCarriesProvenance() throws {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box),
            let uid = graph.uid(ofNodeKind: faceKind, index: 0)
        else { return }

        let round = try JSONDecoder().decode(
            BRepGraph.GraphUID.self,
            from: try JSONEncoder().encode(uid))
        #expect(round == uid)
        #expect(round.graphID == graph.instanceID)
        #expect(graph.node(forUID: round) != nil)

        let legacy = Data(#"{"kind":2,"counter":1}"#.utf8)
        let decoded = try JSONDecoder().decode(BRepGraph.GraphUID.self, from: legacy)
        #expect(decoded.graphID == 0)
        #expect(graph.node(forUID: decoded) == nil)
    }

    /// RefUIDs and ItemUIDs restart their counters per graph exactly as node UIDs do, and carry
    /// the same provenance.
    @Test func refAndItemUIDsDoNotCrossGraphs() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let cyl = Shape.cylinder(radius: 3, height: 7),
            let boxGraph = BRepGraph(shape: box),
            let cylGraph = BRepGraph(shape: cyl)
        else { return }

        // Ref kind 1 == Face reference entry.
        if let refUID = boxGraph.uid(ofRefKind: 1, index: 0) {
            #expect(boxGraph.ref(forUID: refUID) != nil)
            #expect(cylGraph.ref(forUID: refUID) == nil)
            #expect(!cylGraph.contains(uid: refUID))
        }

        if let itemUID = boxGraph.itemUID(ofNodeKind: faceKind, index: 2) {
            #expect(boxGraph.item(forUID: itemUID) != nil)
            #expect(cylGraph.item(forUID: itemUID) == nil)
            #expect(boxGraph.contains(uid: itemUID))
            #expect(!cylGraph.contains(uid: itemUID))
        }
    }

    @Test func itemUIDOfNode() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let graph = BRepGraph(shape: box) else { return }
        guard graph.faceCount > 0 else { return }

        if let item = graph.itemUID(ofNodeKind: faceKind, index: 0) {
            #expect(item.isValid)
            #expect(item.domain == 1)  // 1 == Node domain
            if let resolved = graph.item(forUID: item) {
                #expect(resolved.domain == 1)
                #expect(resolved.kind == faceKind)
                #expect(resolved.index == 0)
            } else {
                Issue.record("item UID did not resolve")
            }
        }
    }
}
