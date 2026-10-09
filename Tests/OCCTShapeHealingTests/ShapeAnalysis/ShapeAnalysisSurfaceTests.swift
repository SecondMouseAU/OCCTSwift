import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis_Surface Tests")
struct ShapeAnalysisSurfaceTests {

    @Test func projectPointOnPlane() {
        if let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            let result = s.projectPointUV(SIMD3(5, 3, 0))
            #expect(abs(result.u - 5.0) < 1e-4)
            #expect(abs(result.v - 3.0) < 1e-4)
            #expect(result.gap < 1e-6)
        }
    }

    @Test func projectPointOffPlane() {
        if let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            let result = s.projectPointUV(SIMD3(0, 0, 10))
            #expect(abs(result.gap - 10.0) < 1e-4)
        }
    }

    @Test func planeHasNoSingularities() {
        if let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            #expect(!s.hasSingularitiesSA())
            #expect(s.singularityCountSA() == 0)
        }
    }

    @Test func planeIsNotClosed() {
        if let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            #expect(!s.isUClosedSA())
            #expect(!s.isVClosedSA())
        }
    }
}
