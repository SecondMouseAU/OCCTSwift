import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are ShapeAnalysis_Shell's own answers on the same shapes, from
// Scripts/repro/766-healing-small-files/probe.mm (transcript.txt beside it). Before #766 both tests
// sat inside `if let` (silently green on a failed fixture) and the sphere test checked one flag.
@Suite("ShapeAnalysis_Shell Tests")
struct ShellAnalysisTests {
    @Test func analyzeBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = box.analyzeShell()
        #expect(!result.hasOrientationProblems)
        #expect(!result.hasFreeEdges)
        #expect(!result.hasBadEdges)
        #expect(result.hasConnectedEdges)
        #expect(result.freeEdgeCount == 0)
    }

    @Test func analyzeSphere() throws {
        // Kernel: no orientation problem, no free or bad edges, connected edges present.
        let sphere = try #require(Shape.sphere(radius: 5))
        let result = sphere.analyzeShell()
        #expect(!result.hasOrientationProblems)
        #expect(!result.hasFreeEdges)
        #expect(!result.hasBadEdges)
        #expect(result.hasConnectedEdges)
        #expect(result.freeEdgeCount == 0)
    }
}
