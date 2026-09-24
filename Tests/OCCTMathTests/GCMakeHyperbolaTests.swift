import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeHyperbola Tests")
struct GCMakeHyperbolaTests {

    @Test func hyperbolaFromAxisAndRadii() throws {
        let h = try #require(Curve3D.gcHyperbola(
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 5))
        // Non-nil held for any hyperbola, including one with the radii swapped. Pin it
        // (kernel values from Scripts/repro/766-math-gc-ellipse-trimmed-direction/transcript.txt).
        #expect(simd_length(h.point(at: 0) - SIMD3(10, 0, 0)) < 1e-9)
        #expect(simd_length(h.point(at: 1) - SIMD3(15.4308063482, 5.87600596822, 0)) < 1e-9)
    }
}

