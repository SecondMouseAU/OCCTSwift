import Foundation
import Testing

@testable import OCCTSwift

@Suite("v0.142 .containedIn now resolves")
struct ContainedInTests {
    @Test("Face contained in a box solid resolves")
    func faceInSolid() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let solid = TopologyRef.literal(.init(kind: .solid, index: 0))
        let firstFace = TopologyRef.containedIn(parent: solid, kind: .face, occurrence: 0)
        switch graph.resolve(firstFace) {
        case .success(let face):
            #expect(face.kind == .face)
        case .failure(let e): Issue.record("containedIn failed: \(e)")
        }
    }

    @Test("Occurrence out of range in containedIn")
    func faceInSolidOOB() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let solid = TopologyRef.literal(.init(kind: .solid, index: 0))
        let faceBogus = TopologyRef.containedIn(parent: solid, kind: .face, occurrence: 999)
        if case .failure(.occurrenceOutOfRange(_, let available, let requested)) = graph.resolve(
            faceBogus)
        {
            // A box solid has six faces, and 999 is what was asked for.
            #expect(available == 6)
            #expect(requested == 999)
        } else {
            Issue.record("expected occurrenceOutOfRange")
        }

        // The boundary: the last face (occurrence 5) resolves and the one past it does not.
        let last = TopologyRef.containedIn(parent: solid, kind: .face, occurrence: 5)
        if case .success(let face) = graph.resolve(last) {
            #expect(face.kind == .face)
        } else {
            Issue.record("occurrence 5 of 6 must resolve")
        }
        let pastEnd = TopologyRef.containedIn(parent: solid, kind: .face, occurrence: 6)
        if case .failure(.occurrenceOutOfRange(_, let available, let requested)) = graph.resolve(
            pastEnd)
        {
            #expect(available == 6)
            #expect(requested == 6)
        } else {
            Issue.record("occurrence 6 of 6 must not resolve")
        }
    }

    @Test("Ancestor resolution failure propagates in containedIn")
    func ancestorMissing() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        graph.isHistoryEnabled = true
        graph.clearHistory()
        // containedIn references a parent recipe that never resolves → should fail.
        let bogusParent = TopologyRef.createdBy(operationName: "Nonexistent", kind: .solid)
        let result = graph.resolve(.containedIn(parent: bogusParent, kind: .face, occurrence: 0))
        if case .failure(.ancestorMissing(let missing)) = result {
            // The failure names the parent recipe that did not resolve, not some other ref.
            #expect(missing == bogusParent)
        } else {
            Issue.record("expected ancestorMissing")
        }

        // The control: the same occurrence under a parent that does resolve is a success.
        let solid = TopologyRef.literal(.init(kind: .solid, index: 0))
        if case .success = graph.resolve(.containedIn(parent: solid, kind: .face, occurrence: 0)) {
        } else {
            Issue.record("containedIn under a resolvable parent must resolve")
        }
    }
}
