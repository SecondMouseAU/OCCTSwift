import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapeanalysis/probe.mm (transcript.txt beside it).
// Before #766 every test sat inside `if let`, silently green if the plane failed to build.
@Suite("ShapeAnalysis_Surface Tests")
struct ShapeAnalysisSurfaceTests {
    private func plane() throws -> Surface {
        try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
    }

    @Test func projectPointOnPlane() throws {
        let result = try plane().projectPointUV(SIMD3(5, 3, 0))
        #expect(abs(result.u - 5.0) < 1e-9)
        #expect(abs(result.v - 3.0) < 1e-9)
        #expect(result.gap < 1e-9)
    }

    @Test func projectPointOffPlane() throws {
        let result = try plane().projectPointUV(SIMD3(0, 0, 10))
        #expect(abs(result.gap - 10.0) < 1e-9)
        #expect(abs(result.u) < 1e-9 && abs(result.v) < 1e-9)
    }

    @Test func planeHasNoSingularities() throws {
        let s = try plane()
        #expect(!s.hasSingularitiesSA())
        #expect(s.singularityCountSA() == 0)
    }

    @Test func planeIsNotClosed() throws {
        let s = try plane()
        #expect(!s.isUClosedSA())
        #expect(!s.isVClosedSA())
    }
}
