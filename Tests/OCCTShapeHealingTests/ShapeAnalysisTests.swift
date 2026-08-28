import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.13.0 Shape Healing & Analysis Tests

@Suite("Shape Analysis Tests")
struct ShapeAnalysisTests {

    @Test("Analyze valid box")
    func analyzeValidBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let analysis = box.analyze(tolerance: 0.001)

        #expect(analysis != nil)
        #expect(analysis!.hasInvalidTopology == false)
        // A valid box may have gap counts due to wire analysis heuristics,
        // but should have no invalid topology
        #expect(box.isValid)
    }

    @Test("Analyze shape for small features")
    func analyzeForSmallFeatures() {
        // Create a box - should have no small features
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let analysis = box.analyze(tolerance: 0.001)

        #expect(analysis != nil)
        #expect(analysis!.smallEdgeCount == 0)
        #expect(analysis!.smallFaceCount == 0)
    }

    @Test("Analysis result properties")
    func analysisResultProperties() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let analysis = box.analyze()!

        #expect(analysis.totalProblems >= 0)
        // Check that totalProblems is consistent with component counts. freeFaceCount is
        // deliberately excluded: it is a derived summary of the same scan freeEdgeCount already
        // counts (this shell has at least one free edge), not an independent defect, so including
        // both would double-count one open shell's boundary gap (#717 review, the totalProblems double-count).
        // hasSelfIntersection is nil here (selfIntersectionTimeout defaults to nil, #772), so it
        // contributes 0, same as the pre-#772 formula, but is included explicitly so this test
        // stays a true mirror of totalProblems's implementation rather than a numeric coincidence.
        let expectedTotal =
            analysis.smallEdgeCount + analysis.smallFaceCount + analysis.gapCount
            + analysis.freeEdgeCount + (analysis.hasInvalidTopology ? 1 : 0)
            + (analysis.hasSelfIntersection == true ? 1 : 0)
        #expect(analysis.totalProblems == expectedTotal)
        #expect(analysis.hasSelfIntersection == nil)
    }
}
