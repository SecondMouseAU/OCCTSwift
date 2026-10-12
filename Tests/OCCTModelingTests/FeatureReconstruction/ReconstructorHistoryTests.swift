import Testing

@testable import OCCTSwift

// MARK: - Tier 3 FeatureReconstructor history wiring (issue #165)

@Suite("FeatureReconstructor BuildResult.histories")
struct ReconstructorHistoryTests {
    @Test("Hole feature with id → history retained under that id")
    func holeFeatureExposesHistory() throws {
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
        // #3332: the old body asserted `shape != nil` and that a history existed, then called
        // `record(of:)` on the RESULT's faces and discarded every answer. The hole starts at
        // z = 5, inside the radius-20, height-10 revolve, and runs 8 mm down: it leaves through
        // the bottom at z = 0 after 5 mm, so pi * 2^2 * 5 comes off pi * 20^2 * 10 = 12566.37.
        #expect(result.fulfilled == ["base", "drill_top"])
        #expect(result.skipped.isEmpty)
        #expect(result.histories.keys.sorted() == ["drill_top"])
        let shape = try #require(result.shape)
        #expect(shape.isValid)
        let volume = try #require(shape.volume)
        #expect(abs(volume - (Double.pi * 400 * 10 - Double.pi * 4 * 5)) < 1e-3)
    }

    // #3332: the history of a reconstructor feature answers for the faces of the body that FEATURE
    // received. The hole above receives a body built inside the reconstructor, which a caller
    // cannot hold, so no identity lookup is possible there. Handing the same feature an
    // `inputBody` the caller owns makes it checkable: the plate's side faces are untouched, and
    // its top and bottom faces (the hole goes through) are each modified into the pierced face.
    @Test("Hole on an input body: history answers for the caller's own faces")
    func holeHistoryOnInputBody() throws {
        let plate = try #require(Shape.box(width: 40, height: 40, depth: 10))
        let hole = FeatureSpec.Hole(
            axisPoint: SIMD3(0, 0, 8), axisDirection: SIMD3(0, 0, -1),
            diameter: 4.0, depth: 20.0, id: "drill")
        let result = FeatureReconstructor.build(from: [.hole(hole)], inputBody: plate)
        #expect(result.fulfilled == ["drill"])
        let shape = try #require(result.shape)
        let volume = try #require(shape.volume)
        #expect(abs(volume - (40 * 40 * 10 - Double.pi * 4 * 10)) < 1e-3)

        let history = try #require(result.histories["drill"])
        var modified = 0
        var untouched = 0
        for face in plate.subShapes(ofType: .face) {
            let record = history.record(of: face)
            #expect(!record.isDeleted)
            if record.modified.count == 1 {
                modified += 1
                let centre = try #require(face.center)
                #expect(abs(abs(centre.z) - 5) < 1e-6, "only the top and bottom faces are pierced")
            } else {
                untouched += 1
                #expect(record.modified.isEmpty)
                #expect(record.generated.isEmpty)
            }
        }
        #expect(modified == 2)
        #expect(untouched == 4)
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
        // #3332: the whole result is empty, not just its history map (measured).
        #expect(result.shape == nil)
        #expect(result.fulfilled.isEmpty)
        #expect(result.skipped.isEmpty)
        #expect(result.annotations.isEmpty)
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
    func chamferNearPointResolves() throws {
        let e = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1),
            length: 10, id: "block")
        // Pick a point near a top-face edge (z=10, y=0, midpoint x=10).
        let c = FeatureSpec.Chamfer(
            edgeSelector: .nearPoint(SIMD3<Double>(10, 0, 10), tolerance: 0.5),
            distance: 0.3, id: "ch_near")
        let result = FeatureReconstructor.build(from: [.extrude(e), .chamfer(c)])
        // #3332: the old body only recorded when the chamfer was skipped as `.unsupported` (the
        // v1.0.3 stub status removed by #166), so a chamfer skipped for ANY other reason, or one
        // that cut nothing, passed. The point is the midpoint of the block's top front edge, a
        // 20 mm line, so one 0.3 mm chamfer takes 0.5 * 0.3 * 0.3 * 20 = 0.9 mm^3 off the
        // 4000 mm^3 block.
        #expect(result.fulfilled == ["block", "ch_near"])
        #expect(result.skipped.isEmpty)
        let shape = try #require(result.shape)
        #expect(shape.isValid)
        let volume = try #require(shape.volume)
        #expect(abs(volume - (4000 - 0.9)) < 1e-6)
        #expect(shape.faceCount == 7)
        #expect(result.histories["ch_near"] != nil)
    }
}
