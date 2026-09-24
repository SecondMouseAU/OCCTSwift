import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values probed on the pinned kernel: Scripts/repro/766-extrema-extpels-plane/transcript.txt.
@Suite("Extrema_ExtPElS Point-Plane")
struct ExtremaExtPElSPlaneTests {
    @Test func pointToPlane() {
        let results = ExtremaPointSurface.pointToPlane(
            point: SIMD3(0, 0, 10),
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1)
        )
        // A point and a plane have exactly one extremum: the perpendicular foot.
        #expect(results.count == 1)
        guard let first = results.first else { return }
        #expect(abs(first.squareDistance - 100) < 1e-12, "got \(first.squareDistance)")
        #expect(simd_length(first.point1 - SIMD3(0, 0, 10)) < 1e-12, "got \(first.point1)")
        #expect(simd_length(first.point2 - SIMD3(0, 0, 0)) < 1e-12, "got \(first.point2)")
    }
}
