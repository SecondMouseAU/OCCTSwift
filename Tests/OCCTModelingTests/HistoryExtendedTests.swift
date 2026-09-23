import Testing
import simd

@testable import OCCTSwift

// #766: these tests used to skip every assertion when a History or a box failed to build (`if let`
// on all of them), and `replaceGeneratedModified` could not see the replace at all: it added an
// entry, replaced it, and asserted only `hasGenerated`/`hasModified`, which the add alone already
// made true. The fixtures are now required, and the replace test checks that the entry left is
// the replacement, as BRepTools_History reports for the same input
// (Scripts/repro/766-modeling-history-extended).

@Suite("v0.122.0, History Extended")
struct HistoryExtendedTests {
    @Test("Merge histories")
    func mergeHistories() throws {
        let history1 = try #require(Shape.History())
        let history2 = try #require(Shape.History())
        let b1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b2 = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let b3 = try #require(Shape.box(width: 3, height: 3, depth: 3))
        history1.addModified(initial: b1, modified: b2)
        history2.addGenerated(initial: b2, generated: b3)
        history1.merge(history2)
        #expect(history1.hasModified)
        #expect(history1.hasGenerated)  // only the merge can put a generated entry in history1
    }

    @Test("Replace generated and modified")
    func replaceGeneratedModified() throws {
        let history = try #require(Shape.History())
        let b1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b2 = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let b3 = try #require(Shape.box(width: 3, height: 3, depth: 3))
        history.addGenerated(initial: b1, generated: b2)
        history.replaceGenerated(initial: b1, generated: b3)
        #expect(history.hasGenerated)
        let generated = history.generatedShapes(of: b1)
        #expect(generated.count == 1)
        #expect(generated.first?.isSame(as: b3) == true)

        history.addModified(initial: b1, modified: b2)
        history.replaceModified(initial: b1, modified: b3)
        #expect(history.hasModified)
        let modified = history.modifiedShapes(of: b1)
        #expect(modified.count == 1)
        #expect(modified.first?.isSame(as: b3) == true)
    }

    @Test("Get modified and generated shapes")
    func getModifiedGeneratedShapes() throws {
        let history = try #require(Shape.History())
        let b1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b2 = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let b3 = try #require(Shape.box(width: 3, height: 3, depth: 3))
        history.addModified(initial: b1, modified: b2)
        let modified = history.modifiedShapes(of: b1)
        #expect(modified.count == 1)

        history.addGenerated(initial: b1, generated: b3)
        let generated = history.generatedShapes(of: b1)
        #expect(generated.count == 1)
    }
}
