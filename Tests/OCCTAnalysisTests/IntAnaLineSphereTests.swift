import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values probed on the pinned kernel: Scripts/repro/766-intana-line-sphere/transcript.txt.
@Suite("IntAna LineSphere Tests")
struct IntAnaLineSphereTests {

    @Test func lineThroughSphere() {
        let r = IntAna.lineSphere(
            lineOrigin: SIMD3(-10, 0, 0), lineDir: SIMD3(1, 0, 0),
            sphereCenter: SIMD3(0, 0, 0), sphereAxis: SIMD3(0, 0, 1), radius: 5)
        #expect(r.points.count == 2)
        #expect(!r.isParallel)
        guard r.points.count == 2, r.params.count == 2 else { return }
        // The kernel reports the exit point first: (5, 0, 0) at parameter 15 along the line,
        // then the entry point (-5, 0, 0) at parameter 5. Compared as a set, because the order
        // is IntAna's and not something the test is about.
        let pairs = zip(r.points, r.params).sorted { $0.1 < $1.1 }
        #expect(simd_length(pairs[0].0 - SIMD3(-5, 0, 0)) < 1e-12, "got \(pairs[0].0)")
        #expect(abs(pairs[0].1 - 5) < 1e-12, "got \(pairs[0].1)")
        #expect(simd_length(pairs[1].0 - SIMD3(5, 0, 0)) < 1e-12, "got \(pairs[1].0)")
        #expect(abs(pairs[1].1 - 15) < 1e-12, "got \(pairs[1].1)")
    }

    @Test func lineMissesSphere() {
        let r = IntAna.lineSphere(
            lineOrigin: SIMD3(0, 100, 0), lineDir: SIMD3(1, 0, 0),
            sphereCenter: SIMD3(0, 0, 0), sphereAxis: SIMD3(0, 0, 1), radius: 5)
        #expect(r.points.count == 0)
        #expect(!r.isParallel)
    }
}
