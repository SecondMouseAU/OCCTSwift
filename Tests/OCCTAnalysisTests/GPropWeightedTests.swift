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

    /// #1583: a caller passing fewer weights than points used to read past the end of the
    /// `weights` array's backing storage inside the bridge loop.
    ///
    /// Now rejected up front.
    @Test func weightedCentroidLengthMismatchIsRejected() {
        let pts = [SIMD3(0.0, 0.0, 0.0), SIMD3(10.0, 0.0, 0.0), SIMD3(0.0, 10.0, 0.0)]

        let tooFewWeights = GeometryProperties.weightedCentroid(points: pts, weights: [1.0])
        #expect(tooFewWeights.mass == 0)
        #expect(tooFewWeights.centroid == nil)

        let tooManyWeights = GeometryProperties.weightedCentroid(
            points: pts, weights: [1.0, 1.0, 1.0, 1.0])
        #expect(tooManyWeights.mass == 0)
        #expect(tooManyWeights.centroid == nil)
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
