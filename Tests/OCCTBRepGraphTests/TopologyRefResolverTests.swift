import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.141 / #72 Phase 1: TopologyRef recipes + resolver

@Suite("v0.141 TopologyRef resolver")
struct TopologyRefResolverTests {
    @Test("Literal reference to a valid node resolves to itself")
    func literalValid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let node = BRepGraph.NodeRef(kind: .face, index: 2)
        let result = graph.resolve(.literal(node))
        switch result {
        case .success(let r): #expect(r == node)
        case .failure(let e): Issue.record("unexpected error: \(e)")
        }
    }

    @Test("Literal reference to an invalid node fails")
    func literalInvalid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let result = graph.resolve(.literal(.sentinel))
        if case .failure(.invalid) = result {
        } else {
            Issue.record("expected .invalid error")
        }
    }

    @Test("createdBy resolves to the recorded replacement")
    func createdByBasic() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let newFace = BRepGraph.NodeRef(kind: .face, index: 100)
        graph.recordHistory(
            operationName: "Extrude_1",
            original: .sentinel,
            replacements: [newFace])
        let result = graph.resolve(.createdBy(operationName: "Extrude_1", kind: .face))
        switch result {
        case .success(let r): #expect(r == newFace)
        case .failure(let e): Issue.record("resolve failed: \(e)")
        }
    }

    @Test("createdBy with unknown operation fails with operationNotFound")
    func createdByMissingOp() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let result = graph.resolve(.createdBy(operationName: "Nonexistent", kind: .face))
        if case .failure(.operationNotFound(let name)) = result {
            #expect(name == "Nonexistent")
        } else {
            Issue.record("expected operationNotFound")
        }
    }

    @Test("createdBy with occurrence out of range fails cleanly")
    func createdByOutOfRange() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let only = BRepGraph.NodeRef(kind: .face, index: 100)
        graph.recordHistory(operationName: "Op", original: .sentinel, replacements: [only])
        let result = graph.resolve(.createdBy(operationName: "Op", kind: .face, occurrence: 5))
        if case .failure(.occurrenceOutOfRange(_, let available, let requested)) = result {
            #expect(available == 1)
            #expect(requested == 5)
        } else {
            Issue.record("expected occurrenceOutOfRange")
        }
    }

    @Test("createdBy walks forward through subsequent history to currentForm")
    func createdByForwardWalk() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        // op1 creates face 10; op2 modifies face 10 → face 11.
        let created = BRepGraph.NodeRef(kind: .face, index: 10)
        let current = BRepGraph.NodeRef(kind: .face, index: 11)
        graph.recordHistory(operationName: "Create", original: .sentinel, replacements: [created])
        graph.recordHistory(operationName: "Modify", original: created, replacements: [current])
        // Asking for "face created by Create" should give the CURRENT form (face 11),
        // not the historical one (face 10).
        let result = graph.resolve(.createdBy(operationName: "Create", kind: .face))
        switch result {
        case .success(let r): #expect(r == current)
        case .failure(let e): Issue.record("resolve failed: \(e)")
        }
    }

    @Test("splitOf picks the Nth replacement of a split original")
    func splitOf() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let orig = BRepGraph.NodeRef(kind: .edge, index: 3)
        let a = BRepGraph.NodeRef(kind: .edge, index: 30)
        let b = BRepGraph.NodeRef(kind: .edge, index: 31)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b])
        let result = graph.resolve(.splitOf(original: .literal(orig), occurrence: 1))
        switch result {
        case .success(let r): #expect(r == b)
        case .failure(let e): Issue.record("resolve failed: \(e)")
        }
    }

    @Test("splitOf with occurrence out of range fails cleanly")
    func splitOfOutOfRange() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        let orig = BRepGraph.NodeRef(kind: .edge, index: 3)
        let a = BRepGraph.NodeRef(kind: .edge, index: 30)
        let b = BRepGraph.NodeRef(kind: .edge, index: 31)
        graph.recordHistory(operationName: "SplitEdge", original: orig, replacements: [a, b])
        let result = graph.resolve(.splitOf(original: .literal(orig), occurrence: 5))
        if case .failure(.occurrenceOutOfRange(_, let available, let requested)) = result {
            #expect(available == 2)
            #expect(requested == 5)
        } else {
            Issue.record("expected occurrenceOutOfRange")
        }
    }

    @Test("Ancestor resolution failure propagates")
    func ancestorMissing() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        // splitOf references an operation that never happened → should fail.
        let result = graph.resolve(
            .splitOf(
                original: .createdBy(operationName: "Nonexistent", kind: .edge),
                occurrence: 0))
        if case .failure(.ancestorMissing) = result {
        } else {
            Issue.record("expected ancestorMissing")
        }
    }
}
