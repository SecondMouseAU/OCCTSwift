import Testing
import simd

@testable import OCCTSwift

@Suite("LocalAnalysis SurfaceContinuity Tests")
struct LocalAnalysisSurfaceContinuityTests {

    // #766: each test opened with `guard let ... else { return }`, so a nil surface passed
    // silently; the guards now record an issue. Values match LocalAnalysis_SurfaceContinuity
    // (Scripts/repro/766-join-local-loft/): identical planes C0Value 0, IsG1; plane vs cylinder
    // C0Value 5.
    @Test func identicalPlanes() {
        guard let s1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
            let s2 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        else {
            Issue.record("plane fixtures")
            return
        }
        // Planes have no second derivative, so the `.c2` default is NullSecondDerivative and
        // answers nil, these three suites used to assert nothing at all (#495). `.c1` is the
        // strictest order a plane can be analysed at.
        let analysis = s1.continuityWith(s2, u1: 0, v1: 0, u2: 0, v2: 0, order: .c1)
        #expect(analysis?.isC0 == true)
        #expect((analysis?.c0Value ?? .infinity) < 1e-6)

        // Tangency is a separate question: neither `.c1` nor the `.c2` default computes G1.
        let tangency = s1.continuityWith(s2, u1: 0, v1: 0, u2: 0, v2: 0, order: .g1)
        #expect(tangency?.isG1 == true)
    }

    @Test func planeVsCylinder() {
        guard let s1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
            let s2 = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5.0)
        else {
            Issue.record("plane/cylinder fixtures")
            return
        }
        let analysis = s1.continuityWith(s2, u1: 0, v1: 0, u2: 0, v2: 0, order: .c1)
        #expect(analysis?.order == .c1)
        // The two surfaces are 5 units apart at these parameters, so not even C0 holds.
        #expect(analysis?.isC0 == false)
        #expect(analysis?.c0Value == 5)
    }

    @Test func surfaceContinuityFlags() {
        guard let s1 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
            let s2 = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        else {
            Issue.record("plane fixtures")
            return
        }
        let analysis = s1.continuityWith(s2, u1: 0, v1: 0, u2: 0, v2: 0, order: .c1)
        #expect((analysis?.flags ?? 0) > 0)
    }
}
