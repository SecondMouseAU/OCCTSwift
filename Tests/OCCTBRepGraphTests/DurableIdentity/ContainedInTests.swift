import Foundation
import Testing
import simd

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
        if case .failure(.occurrenceOutOfRange) = graph.resolve(faceBogus) {
        } else {
            Issue.record("expected occurrenceOutOfRange")
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
        if case .failure(.ancestorMissing) = result {
        } else {
            Issue.record("expected ancestorMissing")
        }
    }
}
