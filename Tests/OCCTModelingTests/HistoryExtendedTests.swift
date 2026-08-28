import Testing
import simd

@testable import OCCTSwift

@Suite("v0.122.0, History Extended")
struct HistoryExtendedTests {
    @Test("Merge histories")
    func mergeHistories() {
        let h1 = Shape.History()
        let h2 = Shape.History()
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 5, height: 5, depth: 5)
        let box3 = Shape.box(width: 3, height: 3, depth: 3)
        if let history1 = h1, let history2 = h2,
            let b1 = box1, let b2 = box2, let b3 = box3
        {
            history1.addModified(initial: b1, modified: b2)
            history2.addGenerated(initial: b2, generated: b3)
            history1.merge(history2)
            #expect(history1.hasModified)
            #expect(history1.hasGenerated)
        }
    }

    @Test("Replace generated and modified")
    func replaceGeneratedModified() {
        let h = Shape.History()
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 5, height: 5, depth: 5)
        let box3 = Shape.box(width: 3, height: 3, depth: 3)
        if let history = h, let b1 = box1, let b2 = box2, let b3 = box3 {
            history.addGenerated(initial: b1, generated: b2)
            history.replaceGenerated(initial: b1, generated: b3)
            #expect(history.hasGenerated)

            history.addModified(initial: b1, modified: b2)
            history.replaceModified(initial: b1, modified: b3)
            #expect(history.hasModified)
        }
    }

    @Test("Get modified and generated shapes")
    func getModifiedGeneratedShapes() {
        let h = Shape.History()
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 5, height: 5, depth: 5)
        let box3 = Shape.box(width: 3, height: 3, depth: 3)
        if let history = h, let b1 = box1, let b2 = box2, let b3 = box3 {
            history.addModified(initial: b1, modified: b2)
            let modified = history.modifiedShapes(of: b1)
            #expect(modified.count == 1)

            history.addGenerated(initial: b1, generated: b3)
            let generated = history.generatedShapes(of: b1)
            #expect(generated.count == 1)
        }
    }
}
