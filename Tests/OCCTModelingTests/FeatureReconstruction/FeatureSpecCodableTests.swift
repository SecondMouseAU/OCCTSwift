import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.147 #82: FeatureSpec Codable

@Suite("v0.147 FeatureSpec Codable")
struct FeatureSpecCodableTests {
    @Test("Encode/decode roundtrip of a revolve")
    func revolveRoundtrip() throws {
        let r = FeatureSpec.revolve(
            .init(
                profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 5)],
                axisOrigin: .zero,
                axisDirection: SIMD3(0, 0, 1),
                angleDeg: 360,
                id: "rev"))
        let enc = try JSONEncoder().encode(r)
        let dec = try JSONDecoder().decode(FeatureSpec.self, from: enc)
        #expect(dec == r)
    }

    @Test("Encode/decode roundtrip of a boolean")
    func booleanRoundtrip() throws {
        let b = FeatureSpec.boolean(.init(op: .subtract, leftID: "a", rightID: "b", id: "sub1"))
        let enc = try JSONEncoder().encode(b)
        let dec = try JSONDecoder().decode(FeatureSpec.self, from: enc)
        #expect(dec == b)
    }

    @Test("Encode/decode an array of mixed specs")
    func mixedArray() throws {
        let specs: [FeatureSpec] = [
            .revolve(
                .init(
                    profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 5)],
                    axisOrigin: .zero,
                    axisDirection: SIMD3(0, 0, 1),
                    id: "base")),
            .hole(
                .init(
                    axisPoint: SIMD3(5, 0, 0),
                    axisDirection: SIMD3(0, 0, 1),
                    diameter: 2.0, depth: 5.0, id: "h1")),
            .fillet(.init(edgeSelector: .all, radius: 0.5, id: "f")),
            .boolean(.init(op: .union, leftID: "base", rightID: "h1", id: "u")),
        ]
        let enc = try JSONEncoder().encode(specs)
        let dec = try JSONDecoder().decode([FeatureSpec].self, from: enc)
        #expect(dec.count == specs.count)
        #expect(dec == specs)
    }

    @Test("EdgeSelector variants round-trip")
    func edgeSelectorRoundtrip() throws {
        let selectors: [FeatureSpec.EdgeSelector] = [
            .all,
            .nearPoint(SIMD3(1, 2, 3), tolerance: 0.5),
            .onFeature("base"),
        ]
        for s in selectors {
            let enc = try JSONEncoder().encode(s)
            let dec = try JSONDecoder().decode(FeatureSpec.EdgeSelector.self, from: enc)
            #expect(dec == s)
        }
    }
}
