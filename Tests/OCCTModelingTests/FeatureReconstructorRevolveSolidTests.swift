import Foundation
import Testing
import simd

@testable import OCCTSwift

// #3139: a `revolve` feature built from a closed profile must be a Solid, so the features that
// follow it (a hole above all) have material to act on. The tests assert on the solid count as
// well as the volume, because a closed shell reports a believable volume.
@Suite("Issue3139 FeatureReconstructor revolve is a solid")
struct Issue3139ReconstructorRevolveSolidTests {
    private static let revolveJSON = """
        {"kind":"revolve","id":"body",
         "profile_points_2d":[[0,0],[12,0],[12,60],[0,60]],
         "axis_origin":[0,0,0],"axis_direction":[0,0,1],"angle_deg":360}
        """
    private static let holeJSON = """
        {"kind":"hole","id":"bore","axis_point":[0,0,0],"axis_direction":[0,0,1],
         "diameter":8,"depth":60}
        """
    private static let extrudeJSON = """
        {"kind":"extrude","id":"body",
         "profile_points_2d":[[-12,-12],[12,-12],[12,12],[-12,12]],
         "plane_origin":[0,0,0],"plane_normal":[0,0,1],"length":60}
        """

    private func run(_ features: [String]) throws -> FeatureReconstructor.BuildResult {
        let json = "{\"features\":[\(features.joined(separator: ","))]}"
        return try FeatureReconstructor.buildJSON(Data(json.utf8))
    }

    @Test("A 360 degree revolve is a single Solid with the cylinder's volume")
    func revolveIsSolid() throws {
        let result = try run([Self.revolveJSON])
        let shape = try #require(result.shape)
        #expect(shape.shapeType == .solid)
        #expect(shape.subShapeCount(ofType: .solid) == 1)
        #expect(shape.subShapeCount(ofType: .face) == 3)
        #expect(result.fulfilled == ["body"])
        #expect(result.skipped.isEmpty)
        if let v = shape.volume {
            let expected = Double.pi * 12 * 12 * 60
            #expect(abs(v - expected) < expected * 1e-6)
        } else {
            Issue.record("revolve volume was nil")
        }
    }

    @Test("Revolve then hole cuts the bore: pi (R^2 - r^2) h")
    func revolveThenHole() throws {
        let result = try run([Self.revolveJSON, Self.holeJSON])
        let shape = try #require(result.shape)
        // A boolean cut answers a compound holding the one solid, so count solids, not the type.
        #expect(shape.subShapeCount(ofType: .solid) == 1)
        // Outer wall, two caps and the bore wall.
        #expect(shape.subShapeCount(ofType: .face) == 4)
        #expect(result.fulfilled == ["body", "bore"])
        #expect(result.skipped.isEmpty)
        if let v = shape.volume {
            let expected = Double.pi * (12 * 12 - 4 * 4) * 60
            #expect(abs(v - expected) < expected * 1e-6)
        } else {
            Issue.record("bored revolve volume was nil")
        }
    }

    @Test("Control: extrude then hole gives the same bore volume on a square block")
    func extrudeControl() throws {
        let result = try run([Self.extrudeJSON, Self.holeJSON])
        let shape = try #require(result.shape)
        #expect(shape.subShapeCount(ofType: .solid) == 1)
        if let v = shape.volume {
            let expected = 24.0 * 24.0 * 60 - Double.pi * 16 * 60
            #expect(abs(v - expected) < expected * 1e-6)
        } else {
            Issue.record("extrude volume was nil")
        }
    }

    @Test("A partial revolve of a closed profile is a Solid too")
    func partialRevolveIsSolid() throws {
        let json = """
            {"kind":"revolve","id":"wedge",
             "profile_points_2d":[[5,0],[12,0],[12,60],[5,60]],
             "axis_origin":[0,0,0],"axis_direction":[0,0,1],"angle_deg":90}
            """
        let shape = try #require(try run([json]).shape)
        #expect(shape.subShapeCount(ofType: .solid) == 1)
        if let v = shape.volume {
            let expected = Double.pi * (144 - 25) * 60 / 4
            #expect(abs(v - expected) < expected * 1e-6)
        } else {
            Issue.record("wedge volume was nil")
        }
    }

    @Test("A zero-area revolve profile is skipped, not reported fulfilled")
    func degenerateRevolveIsSkipped() {
        let spec = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(5, 0)],
            axisOrigin: SIMD3(30, 0, 0), axisDirection: SIMD3(0, 0, 1), angleDeg: 180,
            id: "sliver")
        let result = FeatureReconstructor.build(from: [.revolve(spec)])
        #expect(result.shape == nil)
        #expect(result.fulfilled.isEmpty)
        #expect(result.skipped.contains { $0.featureID == "sliver" })
    }

    @Test("A hole on a body with no solid is skipped, not reported fulfilled")
    func holeOnShellIsSkipped() throws {
        // A bare shell as the input body: cutting it yields no solid, so the hole did nothing.
        let wire = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(12, 0, 0), SIMD3(12, 0, 60), SIMD3(0, 0, 60)], closed: true))
        let shell = try #require(
            Shape.revolve(
                profile: wire, axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1)))
        #expect(shell.subShapeCount(ofType: .solid) == 0)
        let hole = FeatureSpec.Hole(
            axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), diameter: 8, depth: 60, id: "bore")
        let result = FeatureReconstructor.build(from: [.hole(hole)], inputBody: shell)
        #expect(!result.fulfilled.contains("bore"))
        #expect(result.skipped.contains { $0.featureID == "bore" })
    }
}
