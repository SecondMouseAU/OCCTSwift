import Testing
import simd

@testable import OCCTSwift

@Suite("Transform / pattern *WithFullHistory (issue #331)")
struct TransformPatternFullHistoryTests {
    @Test("Translate: every input face is Modified exactly once, none deleted")
    func translateHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let r = box.translatedWithFullHistory(by: SIMD3(5, 0, 0)) else {
            Issue.record("translate should succeed")
            return
        }
        #expect(r.result.isValid)
        #expect(abs(r.result.volume! - box.volume!) < 1e-6)
        for face in box.subShapes(ofType: .face) {
            let rec = r.history.record(of: face)
            #expect(!rec.isDeleted)
            #expect(rec.modified.count == 1)
        }
    }

    @Test("Rotate: every input face is Modified exactly once, none deleted")
    func rotateHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let r = box.rotatedWithFullHistory(axis: SIMD3(0, 0, 1), angle: .pi / 4) else {
            Issue.record("rotate should succeed")
            return
        }
        #expect(r.result.isValid)
        for face in box.subShapes(ofType: .face) {
            let rec = r.history.record(of: face)
            #expect(!rec.isDeleted)
            #expect(rec.modified.count == 1)
        }
    }

    @Test("Scale: every input face is Modified exactly once; result volume scales by factor^3")
    func scaleHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let r = box.scaledWithFullHistory(by: 2.0) else {
            Issue.record("scale should succeed")
            return
        }
        #expect(r.result.isValid)
        #expect(abs(r.result.volume! - box.volume! * 8) < 1e-3)
        for face in box.subShapes(ofType: .face) {
            let rec = r.history.record(of: face)
            #expect(!rec.isDeleted)
            #expect(rec.modified.count == 1)
        }
    }

    @Test("Mirror: every input face is Modified exactly once, none deleted")
    func mirrorHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let r = box.mirroredWithFullHistory(planeNormal: SIMD3(1, 0, 0)) else {
            Issue.record("mirror should succeed")
            return
        }
        #expect(r.result.isValid)
        for face in box.subShapes(ofType: .face) {
            let rec = r.history.record(of: face)
            #expect(!rec.isDeleted)
            #expect(rec.modified.count == 1)
        }
    }

    @Test("Linear pattern: each input face maps to exactly `count` instance faces")
    func linearPatternHistory() {
        let hole = Shape.cylinder(radius: 3, height: 10)!
        let count = 4
        guard
            let r = hole.linearPatternWithFullHistory(
                direction: SIMD3(20, 0, 0), spacing: 20, count: count)
        else {
            Issue.record("linear pattern should succeed")
            return
        }
        #expect(r.result.isValid)
        for face in hole.subShapes(ofType: .face) {
            let rec = r.history.record(of: face)
            #expect(!rec.isDeleted)
            #expect(
                rec.modified.count == count,
                "expected \(count) pattern-instance faces, got \(rec.modified.count)")
        }
    }

    @Test("Circular pattern: each input face maps to exactly `count` instance faces")
    func circularPatternHistory() {
        let hole = Shape.cylinder(radius: 3, height: 10)!.translated(by: SIMD3(20, 0, 0))!
        let count = 6
        guard
            let r = hole.circularPatternWithFullHistory(
                axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: count
            )
        else {
            Issue.record("circular pattern should succeed")
            return
        }
        #expect(r.result.isValid)
        for face in hole.subShapes(ofType: .face) {
            let rec = r.history.record(of: face)
            #expect(!rec.isDeleted)
            #expect(
                rec.modified.count == count,
                "expected \(count) pattern-instance faces, got \(rec.modified.count)")
        }
    }

    @Test("A translate's history can be absorbed into a BRepGraph (issue #290 integration)")
    func translateHistoryAbsorbsIntoGraph() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let graph = BRepGraph(shape: box),
            let root = graph.findNode(for: box)
        else {
            Issue.record("graph setup failed")
            return
        }
        guard let r = box.translatedWithFullHistory(by: SIMD3(5, 0, 0)) else {
            Issue.record("translate should succeed")
            return
        }
        #expect(graph.historyRecordCount == 0)
        let added = graph.add(
            r.result, absorbing: r.history,
            inputRoots: [BRepGraph.NodeRef(kind: root.kind, index: root.index)],
            operationName: "translate")
        #expect(
            added != nil, "add(absorbing:) should succeed for a translate's synthesized history")
        #expect(graph.historyRecordCount > 0, "absorb should have written history records")
    }

    @Test("Linear pattern with a zero-length direction fails gracefully (does not crash)")
    func linearPatternZeroDirectionDoesNotCrash() {
        let hole = Shape.cylinder(radius: 3, height: 10)!
        let r = hole.linearPatternWithFullHistory(direction: .zero, spacing: 20, count: 4)
        #expect(r == nil)
    }

    @Test("Circular pattern with a zero-length axis direction fails gracefully (does not crash)")
    func circularPatternZeroAxisDoesNotCrash() {
        let hole = Shape.cylinder(radius: 3, height: 10)!
        let r = hole.circularPatternWithFullHistory(
            axisPoint: .zero, axisDirection: .zero, count: 6)
        #expect(r == nil)
    }

    @Test("A linear pattern's history can be absorbed into a BRepGraph (issue #290 integration)")
    func linearPatternHistoryAbsorbsIntoGraph() {
        let hole = Shape.cylinder(radius: 3, height: 10)!
        guard let graph = BRepGraph(shape: hole),
            let root = graph.findNode(for: hole)
        else {
            Issue.record("graph setup failed")
            return
        }
        guard
            let r = hole.linearPatternWithFullHistory(
                direction: SIMD3(20, 0, 0), spacing: 20, count: 3)
        else {
            Issue.record("linear pattern should succeed")
            return
        }
        #expect(graph.historyRecordCount == 0)
        let added = graph.add(
            r.result, absorbing: r.history,
            inputRoots: [BRepGraph.NodeRef(kind: root.kind, index: root.index)],
            operationName: "linearPattern")
        #expect(added != nil, "add(absorbing:) should succeed for a pattern's synthesized history")
        #expect(graph.historyRecordCount > 0, "absorb should have written history records")
    }
}
