import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GProp Weighted Tests")
struct GPropWeightedTests {

    @Test func weightedCentroid() {
        let pts = [SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0)]
        let wts = [1.0, 3.0]
        let (mass, centroid) = GeometryProperties.weightedCentroid(points: pts, weights: wts)
        #expect(abs(mass - 4.0) < 0.01)
        if let c = centroid {
            #expect(abs(c.x - 7.5) < 0.01)
        } else {
            Issue.record("two positively-weighted points have a centroid")
        }
    }

    @Test func barycentre() {
        let pts = [SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0), SIMD3(0.0, 10.0, 0.0)]
        if let c = GeometryProperties.barycentre(pts) {
            #expect(abs(c.x - 10.0 / 3.0) < 0.1)
            #expect(abs(c.y - 10.0 / 3.0) < 0.1)
        } else {
            Issue.record("a three-point set has a barycentre")
        }
    }
}
