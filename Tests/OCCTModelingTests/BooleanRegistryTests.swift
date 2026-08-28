import Testing
import simd

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
    func missingLeftRef() {
        let b = FeatureSpec.Boolean(op: .union, leftID: "nope", rightID: "alsoNope", id: "bad")
        let result = FeatureReconstructor.build(from: [.boolean(b)])
        if let skip = result.skipped.first(where: { $0.featureID == "bad" }) {
            if case .unresolvedRef = skip.reason {
            } else {
                Issue.record("expected unresolvedRef")
            }
        } else {
            Issue.record("expected skipped")
        }
    }
}
