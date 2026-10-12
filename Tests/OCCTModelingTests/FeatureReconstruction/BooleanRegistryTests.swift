import Testing

@testable import OCCTSwift

// MARK: - v0.143 D3: Named-shape registry for FeatureSpec.Boolean

@Suite("v0.143 FeatureSpec.Boolean named-shape registry")
struct BooleanRegistryTests {
    @Test("Boolean union of two named revolves")
    func unionNamedRevolves() {
        let a = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(5, 0), SIMD2(5, 5)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "a")
        let b = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(10, 0), SIMD2(15, 0), SIMD2(15, 5)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "b")
        let u = FeatureSpec.Boolean(op: .union, leftID: "a", rightID: "b", id: "u")
        let result = FeatureReconstructor.build(from: [.revolve(a), .revolve(b), .boolean(u)])
        #expect(result.fulfilled.contains("a"))
        #expect(result.fulfilled.contains("b"))
        #expect(result.fulfilled.contains("u"))
        #expect(result.shape != nil)
    }

    @Test("Boolean with missing named left reports unresolvedRef")
    // #3332: the old body nested `if let skip` / `if case` and recorded an Issue only in the else
    // arms, so a build that fulfilled something, returned a shape, or skipped under the wrong stage
    // passed. Pinned here: nothing fulfilled, no shape, exactly one skip for the boolean's own id,
    // in the additive stage, as an unresolvedRef that names the left id (the one reported first).
    // A subtract with the same unknown ids refuses in the subtractive stage.
    func missingLeftRef() throws {
        let b = FeatureSpec.Boolean(op: .union, leftID: "nope", rightID: "alsoNope", id: "bad")
        let result = FeatureReconstructor.build(from: [.boolean(b)])
        #expect(result.shape == nil)
        #expect(result.fulfilled.isEmpty)
        #expect(result.histories.isEmpty)
        #expect(result.skipped.count == 1)
        let skip = try #require(result.skipped.first)
        #expect(skip.featureID == "bad")
        #expect(skip.stage == .additive)
        guard case .unresolvedRef(let message) = skip.reason else {
            Issue.record("expected unresolvedRef, got \(skip.reason)")
            return
        }
        #expect(message.contains("nope"))
        #expect(!message.contains("alsoNope"), "the left id is reported first")

        let cut = FeatureSpec.Boolean(op: .subtract, leftID: "nope", rightID: "alsoNope", id: "cut")
        let cutResult = FeatureReconstructor.build(from: [.boolean(cut)])
        let cutSkip = try #require(cutResult.skipped.first)
        #expect(cutSkip.featureID == "cut")
        #expect(cutSkip.stage == .subtractive)
        guard case .unresolvedRef = cutSkip.reason else {
            Issue.record("expected unresolvedRef for subtract, got \(cutSkip.reason)")
            return
        }
    }
}
