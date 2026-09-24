import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtSS Tests")
struct ExtremaExtSSTests {
    // Values probed on the pinned kernel: Scripts/repro/766-extrema-extss/transcript.txt.
    // Before #766's execution pass both fixtures sat inside `if let`, so nil surfaces passed with
    // nothing asserted, and `sphereDistance` read its distance only `if !result.isParallel &&
    // result.count >= 1`, so a bridge reporting the spheres as parallel, or reporting no extrema,
    // passed it.
    @Test func parallelPlanes() {
        guard let p1 = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
            let p2 = Surface.plane(origin: SIMD3(0, 0, 7), normal: SIMD3(0, 0, 1))
        else {
            Issue.record("Surface.plane returned nil")
            return
        }
        let result = p1.extremaSS(other: p2)
        #expect(result.isDone)
        #expect(result.isParallel)
        // A parallel result carries no individual extrema.
        #expect(result.count == 0)
    }

    @Test func sphereDistance() {
        guard let s1 = Surface.sphere(center: SIMD3(0, 0, 0), radius: 3.0),
            let s2 = Surface.sphere(center: SIMD3(10, 0, 0), radius: 2.0)
        else {
            Issue.record("Surface.sphere returned nil")
            return
        }
        let result = s1.extremaSS(other: s2)
        #expect(result.isDone)
        #expect(!result.isParallel)
        // Two extrema along the centre line: nearest 10 - 3 - 2 = 5, farthest 10 + 3 + 2 = 15.
        #expect(result.count == 2)
        let near = s1.extremaSSPoint(other: s2, index: 1)
        #expect(abs(near.squareDistance.squareRoot() - 5.0) < 1e-9, "got \(near.squareDistance)")
        #expect(simd_length(near.point1 - SIMD3(3, 0, 0)) < 1e-6, "got \(near.point1)")
        #expect(simd_length(near.point2 - SIMD3(8, 0, 0)) < 1e-6, "got \(near.point2)")
        let far = s1.extremaSSPoint(other: s2, index: 2)
        #expect(abs(far.squareDistance.squareRoot() - 15.0) < 1e-9, "got \(far.squareDistance)")
    }

    /// #1502 finding 2: `OCCTExtremaExtSSPoint` called `Extrema_POnSurf::Parameter(u, v)` for
    /// both points but only stored `u` (into the shared `OCCTExtremaPointPair.param1`/`param2`,
    /// designed for a curve's single parameter), silently discarding both points' V. Fixed with a
    /// dedicated `ExtremaSurfacePointPair` result carrying `(u, v)` for each point.
    ///
    /// The two sphere centres here are offset in Z as well as X, so the closest points do NOT sit
    /// on either sphere's equator (V = 0): a fixture where the true V happened to be 0 could pass
    /// even against the pre-fix code, which left V permanently defaulted to 0.
    @Test func bothPointsCarryTheirOwnUV() throws {
        let s1 = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 3))
        let s2 = try #require(Surface.sphere(center: SIMD3(10, 0, 5), radius: 2))

        let ss = s1.extremaSS(other: s2)
        #expect(ss.isDone)
        #expect(!ss.isParallel)
        try #require(ss.count >= 1)

        let pair = s1.extremaSSPoint(other: s2, index: 1)

        // Independently known geometry: the true closest distance between the two spheres is
        // |centre1 - centre2| - r1 - r2 = sqrt(125) - 3 - 2.
        let expectedDistance = 125.0.squareRoot() - 5.0
        #expect(abs(pair.squareDistance.squareRoot() - expectedDistance) < 1e-6)

        // The regression check: each surface, evaluated at the (u, v) the fix now returns,
        // reproduces the 3D point Extrema_ExtSS itself measured. Before the fix v1/v2 were
        // always 0 (never written), so this round-trip only holds by accident if V happens to be
        // 0 too -- ruled out by the offset fixture above.
        let reconstructed1 = s1.point(atU: pair.u1, v: pair.v1)
        let reconstructed2 = s2.point(atU: pair.u2, v: pair.v2)
        #expect(simd_length(reconstructed1 - pair.point1) < 1e-6)
        #expect(simd_length(reconstructed2 - pair.point2) < 1e-6)

        // And confirm this fixture actually exercises a non-trivial V on both sides.
        #expect(abs(pair.v1) > 1e-3)
        #expect(abs(pair.v2) > 1e-3)
    }
}
