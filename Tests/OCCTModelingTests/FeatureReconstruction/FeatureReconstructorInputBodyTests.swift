import Testing
import simd

@testable import OCCTSwift

// MARK: - #87: FeatureReconstructor.inputBody chaining

@Suite("FeatureReconstructor inputBody (#87)")
struct FeatureReconstructorInputBodyTests {

    @Test("nil inputBody is byte-for-byte identical to current behaviour")
    func nilInputBodyMatchesBaseline() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), id: "base")
        let baseline = FeatureReconstructor.build(from: [.revolve(r)])
        let withNil = FeatureReconstructor.build(from: [.revolve(r)], inputBody: nil)
        #expect(baseline.fulfilled == withNil.fulfilled)
        #expect(baseline.skipped.count == withNil.skipped.count)
        #expect((baseline.shape == nil) == (withNil.shape == nil))
    }

    @Test("Empty specs + inputBody returns the input as the result")
    func emptySpecsWithInput() {
        let box = Shape.box(width: 20, height: 20, depth: 10)!
        let result = FeatureReconstructor.build(from: [], inputBody: box)
        #expect(result.shape != nil)
        // Volume preserved, no features applied.
        if let s = result.shape {
            let box1 = box.bounds!
            let box2 = s.bounds!
            #expect(abs(box1.min.x - box2.min.x) < 1e-9)
            #expect(abs(box1.max.x - box2.max.x) < 1e-9)
        }
    }

    @Test("Hole subtracts from inputBody without an additive seed")
    func holeOnInputBody() {
        let plate = Shape.box(width: 50, height: 50, depth: 5)!
        let plateBoundsBefore = plate.bounds!
        let h = FeatureSpec.Hole(
            axisPoint: SIMD3(25, 25, 0),
            axisDirection: SIMD3(0, 0, 1),
            diameter: 5.0, depth: 10.0, id: "mount_hole")
        let result = FeatureReconstructor.build(from: [.hole(h)], inputBody: plate)
        #expect(result.fulfilled.contains("mount_hole"))
        #expect(result.shape != nil)
        // Outer bbox unchanged (hole is internal).
        if let s = result.shape {
            let after = s.bounds!
            #expect(abs(plateBoundsBefore.min.x - after.min.x) < 1e-6)
            #expect(abs(plateBoundsBefore.max.z - after.max.z) < 1e-6)
        }
    }

    @Test("@input sentinel resolves in boolean leftID")
    func sentinelResolvesInBoolean() {
        let plate = Shape.box(width: 30, height: 30, depth: 3)!
        // Build a slot solid via extrude, then subtract it from @input.
        let slot = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(10, 10), SIMD2(20, 10), SIMD2(20, 20), SIMD2(10, 20)],
            planeOrigin: SIMD3(0, 0, 0),
            planeNormal: SIMD3(0, 0, 1),
            length: 10,
            id: "slot")
        let cut = FeatureSpec.Boolean(
            op: .subtract,
            leftID: FeatureReconstructor.inputBodySentinel,
            rightID: "slot",
            id: "cut_slot")
        let result = FeatureReconstructor.build(
            from: [.extrude(slot), .boolean(cut)],
            inputBody: plate)
        #expect(result.fulfilled.contains("slot"))
        #expect(result.fulfilled.contains("cut_slot"))
        #expect(result.shape != nil)
    }

    @Test("@input not registered when inputBody is nil, boolean skips with unresolvedRef")
    func sentinelAbsentWhenNoInput() {
        let slot = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(5, 0), SIMD2(5, 5), SIMD2(0, 5)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1), length: 5, id: "slot")
        let cut = FeatureSpec.Boolean(
            op: .subtract,
            leftID: FeatureReconstructor.inputBodySentinel,
            rightID: "slot",
            id: "cut_slot")
        let result = FeatureReconstructor.build(
            from: [.extrude(slot), .boolean(cut)],
            inputBody: nil)
        // Should skip the boolean with unresolvedRef on `@input`.
        let skip = result.skipped.first { $0.featureID == "cut_slot" }
        #expect(skip != nil)
        if case .unresolvedRef(let msg)? = skip?.reason {
            #expect(msg.contains(FeatureReconstructor.inputBodySentinel))
        } else {
            Issue.record("expected unresolvedRef reason for missing @input")
        }
    }

    @Test("Sheet-metal Builder output → reconstructor cuts a mounting hole")
    func chainSheetMetalThenHole() throws {
        let base = SheetMetal.Flange(
            id: "base",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 30), SIMD2(0, 30)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "upright",
            profile: [SIMD2(0, 0), SIMD2(40, 0), SIMD2(40, 25), SIMD2(0, 25)],
            origin: SIMD3<Double>(0, 30, 0),
            normal: SIMD3<Double>(0, 1, 0),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 0, 1))
        let bracket = try SheetMetal.Builder(thickness: 2.0).build(
            flanges: [base, upright],
            bends: [SheetMetal.Bend(from: "base", to: "upright", radius: 1.5)])

        let h1 = FeatureSpec.Hole(
            axisPoint: SIMD3(10, 10, 0),
            axisDirection: SIMD3(0, 0, 1),
            diameter: 4.0, depth: 5.0, id: "mount_a")
        let h2 = FeatureSpec.Hole(
            axisPoint: SIMD3(30, 10, 0),
            axisDirection: SIMD3(0, 0, 1),
            diameter: 4.0, depth: 5.0, id: "mount_b")
        let result = FeatureReconstructor.build(
            from: [.hole(h1), .hole(h2)],
            inputBody: bracket)
        #expect(result.fulfilled.contains("mount_a"))
        #expect(result.fulfilled.contains("mount_b"))
        #expect(result.shape != nil)
    }

    @Test("buildJSON forwards inputBody through to build")
    func buildJSONForwardsInput() throws {
        let plate = Shape.box(width: 20, height: 20, depth: 4)!
        let json = """
            {
              "features": [
                {
                  "kind": "hole",
                  "axis_point": [10, 10, 0],
                  "axis_direction": [0, 0, 1],
                  "diameter": 3.0,
                  "depth": 6.0,
                  "id": "h"
                }
              ]
            }
            """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json, inputBody: plate)
        #expect(result.fulfilled.contains("h"))
        #expect(result.shape != nil)
    }

    @Test("Additive feature unions onto inputBody")
    func additiveOntoInputBody() {
        let baseplate = Shape.box(width: 30, height: 30, depth: 5)!
        // Add a tab on top via extrude.
        let tab = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(5, 5), SIMD2(15, 5), SIMD2(15, 15), SIMD2(5, 15)],
            planeOrigin: SIMD3(0, 0, 5),
            planeNormal: SIMD3(0, 0, 1),
            length: 5,
            id: "tab")
        let result = FeatureReconstructor.build(
            from: [.extrude(tab)],
            inputBody: baseplate)
        #expect(result.fulfilled.contains("tab"))
        #expect(result.shape != nil)
        // Combined bbox extends past z=5 (the tab adds 5mm above the plate).
        if let s = result.shape, let b = s.bounds {
            #expect(b.max.z > 9.0)
        }
    }
}
