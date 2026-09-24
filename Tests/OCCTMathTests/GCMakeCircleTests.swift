import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.105.0 Tests

@Suite("GC_MakeCircle Tests")
struct GCMakeCircleTests {

    @Test func circleFromAxisAndRadius() {
        let c = Curve3D.gcCircle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5)
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
            // isClosed holds for every circle. Pin it (kernel values from
            // Scripts/repro/766-math-gc-circle-cone-cylinder/transcript.txt).
            #expect(simd_length(c.point(at: 0) - SIMD3(5, 0, 0)) < 1e-9)
            #expect(simd_length(c.point(at: .pi / 2) - SIMD3(0, 5, 0)) < 1e-9)
        }
    }

    @Test func circleFrom3Points() {
        let c = Curve3D.gcCircle(p1: SIMD3(1, 0, 0), p2: SIMD3(0, 1, 0), p3: SIMD3(-1, 0, 0))
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
            // isClosed holds for every circle. Pin it (kernel values from
            // Scripts/repro/766-math-gc-circle-cone-cylinder/transcript.txt).
            #expect(simd_length(c.point(at: 0) - SIMD3(1, 0, 0)) < 1e-9)
            #expect(simd_length(c.point(at: .pi / 2) - SIMD3(0, 1, 0)) < 1e-9)
        }
    }

    @Test func circleCenterNormal() {
        let c = Curve3D.gcCircleCenterNormal(
            center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 10)
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
            // isClosed holds for every circle. Pin it (kernel values from
            // Scripts/repro/766-math-gc-circle-cone-cylinder/transcript.txt).
            #expect(simd_length(c.point(at: 0) - SIMD3(11, 2, 3)) < 1e-9)
            #expect(simd_length(c.point(at: .pi / 2) - SIMD3(1, 12, 3)) < 1e-9)
        }
    }

    @Test func circleParallel() {
        let c = Curve3D.gcCircleParallel(
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1),
            radius: 5, distance: 3)
        #expect(c != nil)
        if let c = c {
            #expect(c.isClosed)
            // isClosed holds for every circle. Pin it (kernel values from
            // Scripts/repro/766-math-gc-circle-cone-cylinder/transcript.txt).
            #expect(simd_length(c.point(at: 0) - SIMD3(8, 0, 0)) < 1e-9)
            #expect(simd_length(c.point(at: .pi / 2) - SIMD3(0, 8, 0)) < 1e-9)
        }
    }
}

