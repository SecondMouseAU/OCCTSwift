import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.142 / #62: FeatureReconstructor

@Suite("v0.142 FeatureReconstructor")
struct FeatureReconstructorTests {
    @Test("Empty specs produces empty result")
    func empty() {
        let result = FeatureReconstructor.build(from: [])
        #expect(result.shape == nil)
        #expect(result.fulfilled.isEmpty)
        #expect(result.skipped.isEmpty)
    }

    @Test("Revolve produces a solid")
    func revolve() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(5, 0), SIMD2(10, 0), SIMD2(10, 5), SIMD2(5, 5)],
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angleDeg: 360,
            id: "rev_1")
        let result = FeatureReconstructor.build(from: [.revolve(r)])
        #expect(result.shape != nil)
        #expect(result.fulfilled == ["rev_1"])
    }

    @Test("Revolve then hole: staged dispatch")
    func revolveThenHole() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 10), SIMD2(0, 10)],
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            id: "base")
        let h = FeatureSpec.Hole(
            axisPoint: SIMD3(10, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            diameter: 5.0,
            depth: 20.0,
            id: "hole_1")
        let result = FeatureReconstructor.build(from: [.revolve(r), .hole(h)])
        #expect(result.shape != nil)
        #expect(result.fulfilled.contains("base"))
        #expect(result.fulfilled.contains("hole_1"))
    }

    @Test("Thread spec lands in annotations, not geometry")
    func threadAnnotationOnly() {
        let t = FeatureSpec.Thread(holeRef: "hole_1", spec: "M5x0.8", id: "thread_1")
        let result = FeatureReconstructor.build(from: [.thread(t)])
        #expect(result.annotations.count == 1)
        if case .thread(let spec, let holeRef, _) = result.annotations.first?.kind {
            #expect(spec == "M5x0.8")
            #expect(holeRef == "hole_1")
        } else {
            Issue.record("expected thread annotation")
        }
    }

    @Test("Underdetermined revolve skipped without aborting")
    func underdeterminedSkipped() {
        let bad = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(1, 0)],  // only 2 points
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "bad")
        let good = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(5, 0), SIMD2(10, 0), SIMD2(10, 5)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "good")
        let result = FeatureReconstructor.build(from: [.revolve(bad), .revolve(good)])
        #expect(result.skipped.contains { $0.featureID == "bad" })
        #expect(result.fulfilled.contains("good"))
        #expect(result.shape != nil)
    }

    @Test("Fillet with uniform radius applies after additive stage")
    func uniformFillet() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 10), SIMD2(0, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "base")
        let f = FeatureSpec.Fillet(edgeSelector: .all, radius: 1.0, id: "fillet_all")
        let result = FeatureReconstructor.build(from: [.revolve(r), .fillet(f)])
        // Uniform fillet may or may not succeed on the revolved solid depending on
        // edge configuration. Test passes either way, checks no crash + graceful skip.
        if !result.fulfilled.contains("fillet_all") {
            #expect(result.skipped.contains { $0.featureID == "fillet_all" })
        }
    }

    // The `EdgeSelector.onFeature is unsupported in v1` test was deleted in
    // v1.0.0: `.onFeature` is wired up in FeatureReconstructor (see the
    // `filletOnFeature` test for positive coverage); the contradictory
    // assertion here was a stale tracker for a temporary v1 limitation.

    @Test("JSON front end parses a revolve")
    func jsonRevolve() throws {
        let json = """
            {
              "features": [
                {
                  "kind": "revolve",
                  "profile_points_2d": [[5, 0], [10, 0], [10, 5]],
                  "axis_origin": [0, 0, 0],
                  "axis_direction": [0, 0, 1],
                  "angle_deg": 360,
                  "id": "rev_1"
                }
              ]
            }
            """
        let data = json.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(data)
        #expect(result.fulfilled == ["rev_1"])
        #expect(result.shape != nil)
    }
}
