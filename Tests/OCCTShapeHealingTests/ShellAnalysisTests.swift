import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis_Shell Tests")
struct ShellAnalysisTests {
    @Test func analyzeBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let result = box.analyzeShell()
            #expect(!result.hasOrientationProblems)
            #expect(!result.hasFreeEdges)
            #expect(!result.hasBadEdges)
            #expect(result.freeEdgeCount == 0)
        }
    }

    @Test func analyzeSphere() {
        if let sphere = Shape.sphere(radius: 5) {
            let result = sphere.analyzeShell()
            #expect(!result.hasOrientationProblems)
        }
    }
}
