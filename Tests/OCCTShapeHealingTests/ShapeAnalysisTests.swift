import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.13.0 Shape Healing & Analysis Tests

@Suite("Shape Analysis Tests")
struct ShapeAnalysisTests {

    // #766: the three tests below force-unwrapped inside `#expect` (`analysis!.x`); they now
    // require the result and pin the kernel's counts on the same box at the same tolerance
    // (Scripts/repro/766-healing-shapeanalysis/probe.mm): no small edges or faces, valid
    // topology, and 24 per-junction 3D gaps. That last number is ShapeAnalysis_Wire::CheckGap3d
    // on every box face wire, which the kernel reports the same way through the same calls; it is
    // pinned as measured and flagged in the #766 PR as a finding, not endorsed as correct.
    @Test("Analyze valid box")
    func analyzeValidBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let analysis = try #require(box.analyze(tolerance: 0.001))
        #expect(analysis.hasInvalidTopology == false)
        #expect(analysis.freeEdgeCount == 0)
        #expect(box.isValid)
    }

    @Test("Analyze shape for small features")
    func analyzeForSmallFeatures() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let analysis = try #require(box.analyze(tolerance: 0.001))
        #expect(analysis.smallEdgeCount == 0)
        #expect(analysis.smallFaceCount == 0)
    }

    @Test("Analysis result properties")
    func analysisResultProperties() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let analysis = try #require(box.analyze())
        // freeFaceCount is deliberately excluded from totalProblems (#717 review), and
        // hasSelfIntersection is nil here (#772), contributing 0.
        let expectedTotal =
            analysis.smallEdgeCount + analysis.smallFaceCount + analysis.gapCount
            + analysis.freeEdgeCount + (analysis.hasInvalidTopology ? 1 : 0)
            + (analysis.hasSelfIntersection == true ? 1 : 0)
        #expect(analysis.totalProblems == expectedTotal)
        #expect(analysis.hasSelfIntersection == nil)
        #expect(analysis.gapCount == 24)
        #expect(analysis.totalProblems == 24)
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

        // Kernel: 2 (one per gap) on the same face and tolerance.
        let analysis = face.analyze(tolerance: 0.01)
        #expect(analysis != nil)
        #expect(analysis?.gapCount == 2)
    }
}
