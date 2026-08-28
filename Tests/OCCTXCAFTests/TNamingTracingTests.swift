import Foundation
import Testing

@testable import OCCTSwift

@Suite("TNaming, Forward and Backward Tracing")
struct TNamingTracingTests {

    @Test("Trace forward finds generated shape")
    func traceForward() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let label2 = doc.createLabel()!
        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere)

        let forward = doc.tracedForward(from: box, scope: label1)
        #expect(forward.count >= 1, "Should find at least one forward-traced shape")
    }

    @Test("Trace backward finds source shape")
    func traceBackward() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let label2 = doc.createLabel()!
        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere)

        let backward = doc.tracedBackward(from: sphere, scope: label2)
        #expect(backward.count >= 1, "Should find at least one backward-traced shape")
    }

    @Test("Multiple generations from same source")
    func multipleGenerations() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let label2 = doc.createLabel()!
        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere)

        let label3 = doc.createLabel()!
        let cyl = Shape.cylinder(radius: 3, height: 8)!
        doc.recordNaming(on: label3, evolution: .generated, oldShape: box, newShape: cyl)

        let forward = doc.tracedForward(from: box, scope: label1)
        #expect(forward.count >= 2, "Should find both generated shapes, got \(forward.count)")
    }

    @Test("Empty trace for unrelated shape")
    func emptyTraceForUnrelated() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let unrelated = Shape.sphere(radius: 7)!
        let forward = doc.tracedForward(from: unrelated, scope: label1)
        #expect(forward.isEmpty, "Unrelated shape should have no forward trace")
    }

    @Test("Trace through modification chain")
    func traceModificationChain() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label, evolution: .primitive, newShape: box)

        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label, evolution: .modify, oldShape: box, newShape: sphere)

        let forward = doc.tracedForward(from: box, scope: label)
        #expect(forward.count >= 1, "Should trace forward through modification")
    }

    @Test("Forward trace does not find source shape")
    func forwardTraceExcludesSource() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let label2 = doc.createLabel()!
        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere)

        let forward = doc.tracedForward(from: box, scope: label1)
        #expect(forward.count >= 1, "Should find generated shape")
        for shape in forward {
            #expect(!shape.isSame(as: box), "Forward trace should not include the source shape")
        }
    }

    @Test("Backward trace does not find generated shape")
    func backwardTraceExcludesGenerated() {
        let doc = Document.create()!
        let label1 = doc.createLabel()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        doc.recordNaming(on: label1, evolution: .primitive, newShape: box)

        let label2 = doc.createLabel()!
        let sphere = Shape.sphere(radius: 5)!
        doc.recordNaming(on: label2, evolution: .generated, oldShape: box, newShape: sphere)

        let backward = doc.tracedBackward(from: sphere, scope: label2)
        #expect(backward.count >= 1, "Should find source shape")
        for shape in backward {
            #expect(!shape.isSame(as: sphere), "Backward trace should not include the generated shape")
        }
    }
}
