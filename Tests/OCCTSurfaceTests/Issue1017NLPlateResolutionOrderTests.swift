import Testing

@testable import OCCTSwift

// #1017: `nlPlateDeformed` / `nlPlateDeformedG1` called their first integer `maxIterations` and
// handed it to `NLPlate_NLPlate::Solve2` as `ord`, the plate's resolution order. `Plate_Plate`
// accepts only 2 through 9 there and otherwise declines, but `Solve2` reports success anyway, so
// an out-of-range value came back as a surface that had not been deformed at all. The parameter
// is now named for what it is and an out-of-range order is refused.
@Suite("NLPlate resolution order is bounded and load-bearing (#1017)")
struct Issue1017NLPlateResolutionOrderTests {

    private static let g0Constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>)] = [
        (uv: SIMD2(-5, -5), target: SIMD3(-5, -5, 1)),
        (uv: SIMD2(5, 5), target: SIMD3(5, 5, 2)),
        (uv: SIMD2(0, 0), target: SIMD3(0, 0, 5)),
    ]

    private static let g1Constraints:
        [(
            uv: SIMD2<Double>, target: SIMD3<Double>, tangentU: SIMD3<Double>,
            tangentV: SIMD3<Double>
        )] = [
            (
                uv: SIMD2(0, 0), target: SIMD3(0, 0, 5),
                tangentU: SIMD3(1, 0, 0.5), tangentV: SIMD3(0, 1, 0.5)
            )
        ]

    private func plane() -> Surface? {
        Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
    }

    // The order the kernel declines. Before the fix each of these returned a surface, built from
    // an empty plate and therefore identical to the undeformed input, while reporting success.
    @Test(
        "An order outside 2...9 is refused rather than silently ignored",
        arguments: [
            0, 1, 10, 12, 100, -1,
        ])
    func outOfRangeOrderIsRefused(order: Int) {
        guard let surface = plane() else {
            #expect(Bool(false), "Failed to create plane")
            return
        }
        #expect(
            surface.nlPlateDeformed(
                constraints: Self.g0Constraints, resolutionOrder: order, tolerance: 0.1) == nil)
        #expect(
            surface.nlPlateDeformedG1(
                constraints: Self.g1Constraints, resolutionOrder: order, tolerance: 0.1) == nil)
    }

    // The two ends of the accepted range, and the shipped default in between, all still build.
    // This is the other half of the guard: a range check that refused a legitimate order would
    // look exactly like one that refuses only the illegitimate ones.
    @Test("Every order the kernel accepts still builds and deforms", arguments: [2, 3, 4, 5, 8, 9])
    func inRangeOrderStillBuilds(order: Int) {
        guard let surface = plane() else {
            #expect(Bool(false), "Failed to create plane")
            return
        }
        guard
            let deformed = surface.nlPlateDeformed(
                constraints: Self.g0Constraints, resolutionOrder: order, tolerance: 0.1)
        else {
            Issue.record("order \(order) should build")
            return
        }
        // Before the fix an out-of-range order returned the undeformed surface, and nothing
        // distinguished that from a solve that had run. The property worth pinning is that the
        // result moves off the source plane at all.
        let domain = deformed.domain
        var maxAbsZ = 0.0
        for i in 0...8 {
            for j in 0...8 {
                let u = domain.uMin + (domain.uMax - domain.uMin) * Double(i) / 8.0
                let v = domain.vMin + (domain.vMax - domain.vMin) * Double(j) / 8.0
                maxAbsZ = max(maxAbsZ, abs(deformed.point(atU: u, v: v).z))
            }
        }
        #expect(maxAbsZ > 1.0, "order \(order) did not deform the surface (maxAbsZ = \(maxAbsZ))")
    }

    // Characterisation, not a proof of the fix: this passed before the rename too. It is here
    // because it is the reason the parameter was renamed rather than dropped the way
    // `nlPlateDeformedG2`'s dead `maxIterations` was (#999). Two accepted orders produce
    // measurably different surfaces, so the value governs something real.
    @Test("Two accepted orders produce different surfaces")
    func orderChangesTheAnswer() {
        guard let surface = plane() else {
            #expect(Bool(false), "Failed to create plane")
            return
        }
        let low = surface.nlPlateDeformed(
            constraints: Self.g0Constraints, resolutionOrder: 2, tolerance: 0.1)
        let high = surface.nlPlateDeformed(
            constraints: Self.g0Constraints, resolutionOrder: 8, tolerance: 0.1)
        guard let low, let high else {
            #expect(Bool(false), "Both orders should build")
            return
        }
        let lowZ = low.point(atU: 0, v: 0).z
        let highZ = high.point(atU: 0, v: 0).z
        #expect(lowZ.isFinite)
        #expect(highZ.isFinite)
        #expect(abs(lowZ - highZ) > 1.0)
    }

    // An accepted order must actually deform. Before the fix an out-of-range order returned the
    // undeformed surface, and nothing distinguished that from a solve that had run, so the
    // property worth pinning is that the result moves off the source plane at all.
    @Test("The default order moves the surface off the input plane")
    func defaultOrderDeforms() {
        guard let surface = plane() else {
            #expect(Bool(false), "Failed to create plane")
            return
        }
        guard
            let deformed = surface.nlPlateDeformed(
                constraints: Self.g0Constraints, tolerance: 0.1)
        else {
            #expect(Bool(false), "Default order should build")
            return
        }
        let domain = deformed.domain
        var maxAbsZ = 0.0
        for i in 0...8 {
            for j in 0...8 {
                let u = domain.uMin + (domain.uMax - domain.uMin) * Double(i) / 8.0
                let v = domain.vMin + (domain.vMax - domain.vMin) * Double(j) / 8.0
                maxAbsZ = max(maxAbsZ, abs(deformed.point(atU: u, v: v).z))
            }
        }
        #expect(maxAbsZ > 1.0)
    }
}
