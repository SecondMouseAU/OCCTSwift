import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.143 D5: FeatureReconstructor edge selectors

// #3332: both tests recorded an Issue only when the fillet was skipped as `.unsupported`, and
// otherwise asserted nothing: "Either fulfilled or skipped with .occtFailure". Measured on the
// pinned kernel they were in fact SKIPPED, as `occtFailure("uniform fillet failed")`: the revolve
// base is a cylinder, and `.nearPoint` compares an edge's PARAMETER MIDPOINT with the point, which
// for the two circular edges is the point opposite the seam and for the seam is mid-height, so the
// point (10, 0, 5) with tolerance 20 selected all three edges at once (seam included) and the
// uniform fillet refused them. The fixtures below select what they name, and every volume is a
// closed form:
//   * all 12 edges of a 20 x 20 x 10 block filleted at r = 1:
//       (a-2r)(b-2r)(c-2r) + 2r(sum of face products) + pi r^2 (a+b+c-6r) + 4/3 pi r^3 = 3958.419
//   * one 20 mm edge at r = 1: V - (1 - pi/4) r^2 * 20 = 3995.708
//   * the top circle of a radius-10, height-10 cylinder at r = 0.5, by Pappus:
//       V - (1 - pi/4) r^2 * 2 pi (R - r (10 - 3 pi) / (3 (4 - pi))) = 3138.259
@Suite("v0.143 EdgeSelector.nearPoint / onFeature")
struct EdgeSelectorWiredTests {
    private func block(id: String = "block") -> FeatureSpec.Extrude {
        FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 20), SIMD2(0, 20)],
            planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1), length: 10, id: id)
    }

    @Test("Fillet .nearPoint finds an edge within tolerance")
    func filletNearPoint() throws {
        // The block's top front edge: along x at y = 0, z = 10, midpoint (10, 0, 10).
        let near = FeatureSpec.Fillet(
            edgeSelector: .nearPoint(SIMD3(10, 0, 10), tolerance: 0.5),
            radius: 1.0, id: "fillet_near")
        let result = FeatureReconstructor.build(from: [.extrude(block()), .fillet(near)])
        #expect(result.fulfilled == ["block", "fillet_near"])
        #expect(result.skipped.isEmpty)
        let shape = try #require(result.shape)
        #expect(shape.isValid)
        let volume = try #require(shape.volume)
        #expect(abs(volume - (4000 - (1 - Double.pi / 4) * 20)) < 1e-4)
        // Only that one edge was rounded: 6 original faces + 1 fillet face.
        #expect(shape.faceCount == 7)

        // A point nowhere near any edge midpoint selects nothing and skips the fillet.
        let far = FeatureSpec.Fillet(
            edgeSelector: .nearPoint(SIMD3(100, 100, 100), tolerance: 0.5),
            radius: 1.0, id: "fillet_far")
        let missed = FeatureReconstructor.build(from: [.extrude(block()), .fillet(far)])
        #expect(missed.fulfilled == ["block"])
        let skip = try #require(missed.skipped.first)
        #expect(skip.featureID == "fillet_far")
        guard case .occtFailure(let message) = skip.reason else {
            Issue.record("expected occtFailure, got \(skip.reason)")
            return
        }
        #expect(message.contains("no edge found near point"))
        let unchanged = try #require(missed.shape?.volume)
        #expect(abs(unchanged - 4000) < 1e-6)

        // On the cylinder the match is against the parameter midpoint: the top circle's is the
        // point opposite the seam, (-10, 0, 10).
        let revolve = FeatureSpec.Revolve(
            profilePoints2D: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), id: "base")
        let ring = FeatureSpec.Fillet(
            edgeSelector: .nearPoint(SIMD3(-10, 0, 10), tolerance: 0.5),
            radius: 0.5, id: "ring")
        let rounded = FeatureReconstructor.build(from: [.revolve(revolve), .fillet(ring)])
        #expect(rounded.fulfilled == ["base", "ring"])
        let roundedVolume = try #require(rounded.shape?.volume)
        let r = 0.5
        let centroid = r * (10 - 3 * Double.pi) / (3 * (4 - Double.pi))
        let removed = (1 - Double.pi / 4) * r * r * 2 * Double.pi * (10 - centroid)
        #expect(abs(roundedVolume - (Double.pi * 100 * 10 - removed)) < 1e-3)
    }

    @Test("Fillet .onFeature targets feature's edges")
    func filletOnFeature() throws {
        // `.onFeature("block")` selects every edge the block feature contributed: all 12.
        let all = FeatureSpec.Fillet(
            edgeSelector: .onFeature("block"), radius: 1.0, id: "fillet_on")
        let result = FeatureReconstructor.build(from: [.extrude(block()), .fillet(all)])
        #expect(result.fulfilled == ["block", "fillet_on"])
        #expect(result.skipped.isEmpty)
        let shape = try #require(result.shape)
        #expect(shape.isValid)
        let a = 18.0
        let c = 8.0
        let rounded =
            a * a * c + 2 * (a * a + 2 * a * c) + Double.pi * (2 * a + c)
            + 4.0 / 3.0 * Double.pi
        let volume = try #require(shape.volume)
        #expect(abs(volume - rounded) < 1e-3)
        // 6 flat faces, 12 edge fillets, 8 corner patches.
        #expect(shape.faceCount == 26)

        // A boss on top of the block: `.onFeature("boss")` rounds the boss's edges and leaves the
        // block's alone, so the volume sits between the unrounded union (4500) and the all-edges
        // fillet of the same union.
        let boss = FeatureSpec.Extrude(
            profilePoints2D: [SIMD2(5, 5), SIMD2(15, 5), SIMD2(15, 15), SIMD2(5, 15)],
            planeOrigin: SIMD3(0, 0, 10), planeNormal: SIMD3(0, 0, 1), length: 5, id: "boss")
        let onBoss = FeatureSpec.Fillet(edgeSelector: .onFeature("boss"), radius: 0.5, id: "r_boss")
        let withBoss = FeatureReconstructor.build(
            from: [.extrude(block()), .extrude(boss), .fillet(onBoss)])
        #expect(withBoss.fulfilled == ["block", "boss", "r_boss"])
        let bossVolume = try #require(withBoss.shape?.volume)
        #expect(abs(bossVolume - 4499.0023) < 1e-3)
        let everything = FeatureSpec.Fillet(edgeSelector: .all, radius: 0.5, id: "r_all")
        let allResult = FeatureReconstructor.build(
            from: [.extrude(block()), .extrude(boss), .fillet(everything)])
        let allVolume = try #require(allResult.shape?.volume)
        #expect(allVolume < bossVolume - 1, "the all-edges fillet removes more than the boss's")

        // An id no feature registered is refused as an unresolved reference.
        let unknown = FeatureSpec.Fillet(
            edgeSelector: .onFeature("nope"), radius: 1.0, id: "fillet_unknown")
        let refused = FeatureReconstructor.build(from: [.extrude(block()), .fillet(unknown)])
        #expect(refused.fulfilled == ["block"])
        let skip = try #require(refused.skipped.first)
        #expect(skip.featureID == "fillet_unknown")
        guard case .unresolvedRef(let message) = skip.reason else {
            Issue.record("expected unresolvedRef, got \(skip.reason)")
            return
        }
        #expect(message.contains("nope"))
    }
}
