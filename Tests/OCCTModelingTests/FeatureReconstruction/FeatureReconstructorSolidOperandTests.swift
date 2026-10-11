import Foundation
import Testing

@testable import OCCTSwift

// #3174: the union-failure branch of `absorbAdditive` lost its fixture when #3139 made a zero-area
// revolve skip earlier, and `applyBoolean` accepted operands with no solid. Measured: two valid
// solids always fuse (disjoint, touching, identical, huge all succeed), so the one input that
// reaches the branch is a solid-less current body, a bare shell supplied as `inputBody`.
@Suite("Issue3174 FeatureReconstructor solid operands")
struct Issue3174ReconstructorSolidOperandTests {
    private static func bareShell() throws -> Shape {
        let wire = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(12, 0, 0), SIMD3(12, 0, 60), SIMD3(0, 0, 60)], closed: true))
        let shell = try #require(
            Shape.revolve(profile: wire, axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1)))
        #expect(shell.subShapeCount(ofType: .solid) == 0)
        return shell
    }

    private static let box = FeatureSpec.Extrude(
        profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
        planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1), length: 10, id: "boss")

    @Test("absorbAdditive: a solid fused into a bare-shell body is skipped with the union reason")
    func unionIntoShellIsSkipped() throws {
        let shell = try Self.bareShell()
        let result = FeatureReconstructor.build(from: [.extrude(Self.box)], inputBody: shell)
        #expect(!result.fulfilled.contains("boss"))
        let skip = result.skipped.first { $0.featureID == "boss" }
        if case .occtFailure(let why)? = skip?.reason {
            #expect(why == "boolean union failed")
        } else {
            Issue.record("expected an occtFailure skip, got \(String(describing: skip?.reason))")
        }
        #expect(skip?.stage == .additive)
        // The body so far is untouched, not replaced by the unfused boss.
        #expect(result.shape?.subShapeCount(ofType: .solid) == 0)
    }

    @Test("Control: the same boss on a solid input body fuses and is fulfilled")
    func unionIntoSolidSucceeds() throws {
        let base = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let result = FeatureReconstructor.build(from: [.extrude(Self.box)], inputBody: base)
        #expect(result.fulfilled == ["boss"])
        #expect(result.skipped.isEmpty)
    }

    @Test("applyBoolean: every op on a solid-less operand is skipped, never fulfilled")
    func booleanOnShellIsSkipped() throws {
        let shell = try Self.bareShell()
        let compoundOfShell = try #require(Shape.compound([shell]))
        // One operand is a compound of a shell, the other a bare shell; both have no solid.
        // Only the input body can be a solid-less named shape through the public API, so both
        // operands address it; the left operand is checked first.
        for body in [shell, compoundOfShell] {
            for op in [FeatureSpec.Boolean.Op.union, .subtract, .intersect] {
                let spec = FeatureSpec.Boolean(
                    op: op, leftID: FeatureReconstructor.inputBodySentinel,
                    rightID: FeatureReconstructor.inputBodySentinel, id: "op")
                let result = FeatureReconstructor.build(from: [.boolean(spec)], inputBody: body)
                #expect(!result.fulfilled.contains("op"), "\(op)")
                let skip = result.skipped.first { $0.featureID == "op" }
                if case .underDetermined(let why)? = skip?.reason {
                    #expect(why.contains("left operand"), "\(op)")
                    #expect(why.contains("no solid"), "\(op)")
                } else {
                    let got = String(describing: skip?.reason)
                    Issue.record("\(op): expected underDetermined, got \(got)")
                }
            }
        }
    }

    @Test("applyBoolean: an empty compound operand is skipped")
    func booleanOnEmptyCompoundIsSkipped() throws {
        // `Shape.compound([])` is nil, so build the empty compound from a cut that removes everything.
        let a = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let empty = try #require(a.subtracting(b))
        #expect(empty.subShapeCount(ofType: .solid) == 0)
        let spec = FeatureSpec.Boolean(
            op: .union, leftID: FeatureReconstructor.inputBodySentinel,
            rightID: FeatureReconstructor.inputBodySentinel, id: "op")
        let result = FeatureReconstructor.build(from: [.boolean(spec)], inputBody: empty)
        #expect(!result.fulfilled.contains("op"))
        #expect(result.skipped.contains { $0.featureID == "op" })
    }

    @Test("Control: a boolean between two solids is still fulfilled")
    func booleanOnSolidsStillWorks() throws {
        let base = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let spec = FeatureSpec.Boolean(
            op: .subtract, leftID: FeatureReconstructor.inputBodySentinel, rightID: "boss",
            id: "cut")
        let result = FeatureReconstructor.build(
            from: [.extrude(Self.box), .boolean(spec)], inputBody: base)
        #expect(result.fulfilled.contains("cut"))
        #expect(!result.skipped.contains { $0.featureID == "cut" })
    }
}
