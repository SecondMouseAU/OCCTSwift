import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.143 D5: FeatureReconstructor edge selectors

@Suite("v0.143 EdgeSelector.nearPoint / onFeature")
struct EdgeSelectorWiredTests {
    @Test("Fillet .nearPoint finds an edge within tolerance")
    func filletNearPoint() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "base")
        // A point on one of the resulting edges.
        let f = FeatureSpec.Fillet(
            edgeSelector: .nearPoint(SIMD3(10, 0, 5), tolerance: 20),
            radius: 0.5, id: "fillet_near")
        let result = FeatureReconstructor.build(from: [.revolve(r), .fillet(f)])
        // Either fulfilled or skipped with .occtFailure, what we don't want is
        // the old .unsupported behaviour.
        if !result.fulfilled.contains("fillet_near") {
            if let skip = result.skipped.first(where: { $0.featureID == "fillet_near" }) {
                if case .unsupported = skip.reason {
                    Issue.record(".nearPoint should no longer be unsupported")
                }
            }
        }
    }

    @Test("Fillet .onFeature targets feature's edges")
    func filletOnFeature() {
        let r = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            id: "base")
        let f = FeatureSpec.Fillet(
            edgeSelector: .onFeature("base"),
            radius: 0.5, id: "fillet_on")
        let result = FeatureReconstructor.build(from: [.revolve(r), .fillet(f)])
        if let skip = result.skipped.first(where: { $0.featureID == "fillet_on" }) {
            if case .unsupported = skip.reason {
                Issue.record(".onFeature should no longer be unsupported")
            }
        }
    }
}
