import Foundation
import Testing
import simd

@testable import OCCTSwift

// #3196: at extreme scale OCCT's fuse answers a valid-looking solid that is only one operand.
// Measured through `FeatureReconstructor.build` on kernel.5: a cube of side s extruded onto a
// 10-unit box fuses correctly up to s = 1e9 (volume s^3) and answers the 10-unit box alone
// (volume 1000, valid, one solid) from s = 1e10 up, with the feature reported fulfilled.
@Suite("Issue3196 FeatureReconstructor huge operands")
struct Issue3196ReconstructorHugeOperandTests {
    private static func cube(_ s: Double, id: String) -> FeatureSpec.Extrude {
        FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(s, 0), SIMD2(s, s), SIMD2(0, s)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1), length: s, id: id)
    }

    private static let small = cube(10, id: "small")

    @Test("An extrude too large to fuse is skipped, never fulfilled with a volume of one operand")
    func hugeExtrudeIsSkipped() throws {
        // One test walks the scales: the cases are the point, not separate behaviours.
        for s in [1e10, 1e12, 1e15] {
            let result = FeatureReconstructor.build(
                from: [.extrude(Self.small), .extrude(Self.cube(s, id: "big"))])
            #expect(!result.fulfilled.contains("big"), "s=\(s)")
            #expect(result.fulfilled == ["small"], "s=\(s)")
            let skip = result.skipped.first { $0.featureID == "big" }
            if case .occtFailure(let why)? = skip?.reason {
                #expect(why.contains("union"), "s=\(s)")
                #expect(why.contains("volume"), "s=\(s)")
            } else {
                let got = String(describing: skip?.reason)
                Issue.record("s=\(s): expected an occtFailure skip, got \(got)")
            }
            #expect(skip?.stage == .additive, "s=\(s)")
            // The accumulated body is the small box, untouched.
            let volume = try #require(result.shape?.volume)
            #expect(abs(volume - 1000) < 1e-6, "s=\(s)")
        }
    }

    @Test("Control: extrudes up to 1e9 fuse and the volume is the big cube's")
    func scalesThatFuseAreFulfilled() throws {
        for s in [1.0, 10.0, 1e3, 1e6, 1e9] {
            let result = FeatureReconstructor.build(
                from: [.extrude(Self.small), .extrude(Self.cube(s, id: "big"))])
            #expect(result.fulfilled == ["small", "big"], "s=\(s)")
            #expect(result.skipped.isEmpty, "s=\(s)")
            let volume = try #require(result.shape?.volume)
            #expect(volume >= max(1000, s * s * s) * (1 - 1e-6), "s=\(s)")
            #expect(volume <= (1000 + s * s * s) * (1 + 1e-6), "s=\(s)")
        }
    }

    @Test("A union boolean between a small body and a huge input body is skipped too")
    func hugeBooleanUnionIsSkipped() throws {
        let s = 1e12
        let wire = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(s, 0, 0), SIMD3(s, s, 0), SIMD3(0, s, 0)], closed: true))
        let huge = try #require(Shape.extrude(profile: wire, direction: SIMD3(0, 0, 1), length: s))
        let spec = FeatureSpec.Boolean(
            op: .union, leftID: "small", rightID: FeatureReconstructor.inputBodySentinel, id: "op")
        let result = FeatureReconstructor.build(
            from: [.extrude(Self.small), .boolean(spec)], inputBody: huge)
        #expect(!result.fulfilled.contains("op"))
        let skip = result.skipped.first { $0.featureID == "op" }
        if case .occtFailure(let why)? = skip?.reason {
            #expect(why.contains("union") && why.contains("volume"))
        } else {
            Issue.record("expected an occtFailure skip, got \(String(describing: skip?.reason))")
        }
        #expect(skip?.stage == .additive)
    }

    @Test("Control: the same union at a scale that fuses is fulfilled")
    func moderateBooleanUnionIsFulfilled() throws {
        let base = try #require(Shape.box(width: 100, height: 100, depth: 100))
        let spec = FeatureSpec.Boolean(
            op: .union, leftID: "small", rightID: FeatureReconstructor.inputBodySentinel, id: "op")
        let result = FeatureReconstructor.build(
            from: [.extrude(Self.small), .boolean(spec)], inputBody: base)
        #expect(result.fulfilled.contains("op"))
        #expect(result.skipped.isEmpty)
    }

    @Test("Control: a hole into a 1e12 target is a consistent cut and stays fulfilled")
    func hugeHoleProbe() throws {
        let s = 1e12
        let wire = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(s, 0, 0), SIMD3(s, s, 0), SIMD3(0, s, 0)], closed: true))
        let huge = try #require(Shape.extrude(profile: wire, direction: SIMD3(0, 0, 1), length: s))
        let hole = FeatureSpec.Hole(
            axisPoint: SIMD3(5e11, 5e11, 0), axisDirection: SIMD3(0, 0, 1), diameter: 8, depth: 100,
            id: "h")
        let result = FeatureReconstructor.build(from: [.hole(hole)], inputBody: huge)
        #expect(result.fulfilled == ["h"])
        #expect(result.skipped.isEmpty)
        let volume = try #require(result.shape?.volume)
        #expect(abs(volume - 1e36) < 1e30)
    }
}
