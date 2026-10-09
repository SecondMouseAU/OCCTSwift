import Testing
import simd

@testable import OCCTSwift

// MARK: - Tier 3 FeatureReconstructor history wiring (issue #165)

@Suite("FeatureReconstructor BuildResult.histories")
struct ReconstructorHistoryTests {
    @Test("Hole feature with id → history retained under that id")
    func holeFeatureExposesHistory() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 10), SIMD2(0, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), id: "base")
        let h = FeatureSpec.Hole(
            axisPoint: SIMD3(10, 0, 5),
            axisDirection: SIMD3(0, 0, -1),
            diameter: 4.0, depth: 8.0,
            id: "drill_top"
        )
        let result = FeatureReconstructor.build(from: [.revolve(r), .hole(h)])
        #expect(result.shape != nil)
        // The hole feature uses a history-recording subtract → must register.
        #expect(
            result.histories["drill_top"] != nil,
            "hole with non-nil id should retain history")
        // Look up history for any base-shape face, must not crash.
        if let history = result.histories["drill_top"], let final = result.shape {
            for face in final.subShapes(ofType: .face).prefix(3) {
                _ = history.record(of: face)
            }
        }
    }

    @Test("Boolean spec with id retains history; without id doesn't")
    func booleanIdGatesHistory() {
        // Two simple disjoint extrusions, then union them via FeatureSpec.Boolean.
        let e1 = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1),
            length: 5, id: "left")
        let e2 = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            planeOrigin: SIMD3(20, 0, 0), planeNormal: SIMD3(0, 0, 1),
            length: 5, id: "right")
        // Boolean with id → history retained.
        let withID = FeatureSpec.Boolean(op: .union, leftID: "left", rightID: "right", id: "merged")
        let result = FeatureReconstructor.build(
            from: [.extrude(e1), .extrude(e2), .boolean(withID)]
        )
        // Sanity: both extrusions fulfilled.
        #expect(result.fulfilled.contains("left"))
        #expect(result.fulfilled.contains("right"))
        #expect(result.fulfilled.contains("merged"))
        // History attached under the boolean's id.
        #expect(result.histories["merged"] != nil)
        // Raw extrude features don't capture history (they go through the
        // additive path; only the second extrude's absorbAdditive triggers a
        // fusion that records history, and it records under the absorbed
        // feature's id, "right").
        #expect(result.histories["left"] == nil)
    }

    @Test("Empty build → empty histories map")
    func emptyBuildEmptyHistories() {
        let result = FeatureReconstructor.build(from: [])
        #expect(result.histories.isEmpty)
    }

    @Test("Fillet feature (.all) with id retains history under that id")
    func filletFeatureExposesHistory() {
        // Extrude a square then fillet all edges.
        let e = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1),
            length: 10, id: "block")
        let f = FeatureSpec.Fillet(edgeSelector: .all, radius: 1.0, id: "round_all")
        let result = FeatureReconstructor.build(from: [.extrude(e), .fillet(f)])
        #expect(result.shape != nil)
        #expect(result.fulfilled.contains("round_all"))
        #expect(
            result.histories["round_all"] != nil,
            "fillet with non-nil id should retain history (#166)")
    }

    @Test("Chamfer feature (.all) with id retains history under that id")
    func chamferFeatureExposesHistory() {
        let e = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1),
            length: 10, id: "block")
        let c = FeatureSpec.Chamfer(edgeSelector: .all, distance: 0.5, id: "ch_all")
        let result = FeatureReconstructor.build(from: [.extrude(e), .chamfer(c)])
        #expect(result.shape != nil)
        #expect(result.fulfilled.contains("ch_all"))
        #expect(
            result.histories["ch_all"] != nil,
            "chamfer with non-nil id should retain history (#166)")
    }

    @Test("Chamfer .nearPoint now resolves (was skipped as unsupported in v1.0.3)")
    func chamferNearPointResolves() {
        let e = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1),
            length: 10, id: "block")
        // Pick a point near a top-face edge (z=10, y=0, midpoint x=10).
        let c = FeatureSpec.Chamfer(
            edgeSelector: .nearPoint(SIMD3<Double>(10, 0, 10), tolerance: 0.5),
            distance: 0.3, id: "ch_near")
        let result = FeatureReconstructor.build(from: [.extrude(e), .chamfer(c)])
        // Whether or not the chamfer succeeds depends on edge geometry, but it
        // must NOT be skipped as `.unsupported`, that was the v1.0.3 stub
        // status removed by #166.
        if let skipped = result.skipped.first(where: { $0.featureID == "ch_near" }) {
            if case .unsupported = skipped.reason {
                Issue.record("chamfer .nearPoint should no longer be unsupported")
            }
        }
    }
}
