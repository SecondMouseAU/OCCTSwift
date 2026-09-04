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

    // #1438: gapCount used to be `gaps += wireAnalysis.CheckGaps3d()`, and CheckGaps3d() returns
    // one bool for the WHOLE wire (true if ANY edge-to-edge junction has a gap), so a wire with 2
    // independent gaps reported 1, not 2. Build a face from a wire assembled via the raw
    // TopoDS_Builder API (BRep_Builder::Add, no connectivity enforcement, unlike
    // BRepLib_MakeWire/Wire.wireFromEdges) out of 3 line edges with 2 real 3D gaps between them
    // and 1 exact join, so ShapeAnalysis_Wire's per-edge distance check has real, deliberate gaps
    // to find regardless of how they got there topologically.
    @Test("gapCount counts each gap, not each wire with a gap")
    func gapCountCountsEachGap() {
        guard let w1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)),
            let w2 = Wire.line(from: SIMD3(10, 1, 0), to: SIMD3(5, 10, 0)),  // 1.0 gap from w1's end
            let w3 = Wire.line(from: SIMD3(5.5, 10, 0), to: SIMD3(0, 0, 0))  // 0.5 gap from w2's end
        else {
            Issue.record("failed to build the 3 line wires")
            return
        }
        guard let e1 = w1.edges().first, let e2 = w2.edges().first, let e3 = w3.edges().first
        else {
            Issue.record("failed to extract edges from the line wires")
            return
        }
        guard let e1Shape = Shape.fromEdge(e1), let e2Shape = Shape.fromEdge(e2),
            let e3Shape = Shape.fromEdge(e3), let rawWireShape = Shape.builderMakeWire()
        else {
            Issue.record("failed to build the raw wire / convert edges to shapes")
            return
        }
        rawWireShape.builderAdd(e1Shape)
        rawWireShape.builderAdd(e2Shape)
        rawWireShape.builderAdd(e3Shape)

        guard let wire = Wire(rawWireShape) else {
            Issue.record("raw wire shape did not convert back to a Wire")
            return
        }
        guard let face = Shape.face(from: wire, planar: true) else {
            Issue.record("failed to build a face from the gappy wire")
            return
        }

        let analysis = face.analyze(tolerance: 0.01)
        #expect(analysis != nil)
        #expect(analysis?.gapCount == 2)
    }
}
