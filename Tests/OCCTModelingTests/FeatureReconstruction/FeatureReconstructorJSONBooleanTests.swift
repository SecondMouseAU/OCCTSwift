import Testing
import simd

@testable import OCCTSwift

// MARK: - #88: FeatureReconstructor.buildJSON boolean decoding

@Suite("FeatureReconstructor JSON boolean (#88)")
struct FeatureReconstructorJSONBooleanTests {

    @Test("JSON boolean subtract referencing @input cuts the input body")
    func jsonBooleanSubtractAtInput() throws {
        let plate = Shape.box(width: 40, height: 40, depth: 5)!
        let plateBoundsBefore = plate.bounds!
        let json = """
            {
              "features": [
                {
                  "kind": "extrude",
                  "id": "slot",
                  "profile_points_2d": [[10, 10], [20, 10], [20, 20], [10, 20]],
                  "plane_origin": [0, 0, 0],
                  "plane_normal": [0, 0, 1],
                  "length": 10
                },
                {
                  "kind": "boolean",
                  "id": "cut_slot",
                  "op": "subtract",
                  "left": "@input",
                  "right": "slot"
                }
              ]
            }
            """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json, inputBody: plate)
        #expect(result.fulfilled.contains("slot"))
        #expect(
            result.fulfilled.contains("cut_slot"),
            "expected cut_slot to be fulfilled, was: \(result.fulfilled)")
        #expect(result.shape != nil)
        // Outer bbox unchanged (slot is internal).
        if let s = result.shape, let after = s.bounds {
            #expect(abs(plateBoundsBefore.max.x - after.max.x) < 1e-6)
            #expect(abs(plateBoundsBefore.max.y - after.max.y) < 1e-6)
        }
    }

    @Test("JSON boolean union of two extruded profiles")
    func jsonBooleanUnion() throws {
        let json = """
            {
              "features": [
                {
                  "kind": "extrude",
                  "id": "a",
                  "profile_points_2d": [[0, 0], [10, 0], [10, 10], [0, 10]],
                  "plane_origin": [0, 0, 0],
                  "plane_normal": [0, 0, 1],
                  "length": 5
                },
                {
                  "kind": "extrude",
                  "id": "b",
                  "profile_points_2d": [[5, 5], [15, 5], [15, 15], [5, 15]],
                  "plane_origin": [0, 0, 0],
                  "plane_normal": [0, 0, 1],
                  "length": 5
                },
                {
                  "kind": "boolean",
                  "id": "ab_union",
                  "op": "union",
                  "left": "a",
                  "right": "b"
                }
              ]
            }
            """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json)
        #expect(result.fulfilled.contains("ab_union"))
    }

    @Test("JSON boolean with bad op rawValue is reported as unsupported skip")
    func jsonBooleanBadOpReported() throws {
        let plate = Shape.box(width: 20, height: 20, depth: 5)!
        let json = """
            {
              "features": [
                {
                  "kind": "boolean",
                  "id": "bad_op",
                  "op": "smush",
                  "left": "@input",
                  "right": "@input"
                }
              ]
            }
            """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json, inputBody: plate)
        let skip = result.skipped.first { $0.featureID == "bad_op" }
        #expect(skip != nil)
        if case .unsupported(let detail)? = skip?.reason {
            #expect(detail.contains("smush"))
        } else {
            Issue.record("expected unsupported skip for bad boolean op")
        }
    }

    @Test("Unknown JSON kind with id is reported as unsupported skip")
    func unknownKindReported() throws {
        let json = """
            {
              "features": [
                {
                  "kind": "extrude",
                  "id": "good",
                  "profile_points_2d": [[0, 0], [5, 0], [5, 5], [0, 5]],
                  "plane_origin": [0, 0, 0],
                  "plane_normal": [0, 0, 1],
                  "length": 1
                },
                {
                  "kind": "shrubbery",
                  "id": "ni"
                }
              ]
            }
            """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json)
        #expect(result.fulfilled.contains("good"))
        let skip = result.skipped.first { $0.featureID == "ni" }
        #expect(skip != nil)
        if case .unsupported(let detail)? = skip?.reason {
            #expect(detail.contains("shrubbery"))
        } else {
            Issue.record("expected unsupported skip for unknown kind")
        }
    }

    @Test("Unknown JSON kind without id is silently ignored (matches kernel policy)")
    func unknownKindWithoutIdIgnored() throws {
        let json = """
            {
              "features": [
                { "kind": "shrubbery" }
              ]
            }
            """.data(using: .utf8)!
        let result = try FeatureReconstructor.buildJSON(json)
        #expect(result.fulfilled.isEmpty)
        #expect(result.skipped.isEmpty)
        #expect(result.shape == nil)
    }
}
