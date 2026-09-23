import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill_Profiler")
struct GeomFillProfilerTests {
    @Test("add curves and perform")
    func addCurvesAndPerform() {
        if let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let c2 = Curve3D.circle(center: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3)
        {
            let profiler = CurveProfiler.create()
            profiler.addCurve(c1)
            profiler.addCurve(c2)
            profiler.perform()
            // #766: `> 0` passed any shape (NbPoles reporting NbKnots included). GeomFill_Profiler
            // homogenizes the two circles to degree 14, 15 poles, 2 knots, see Scripts/repro/766-geomfill-d/.
            #expect(profiler.degree == 14)
            #expect(profiler.poleCount == 15)
            #expect(profiler.knotCount == 2)
        } else {
            Issue.record("failed to build probe curves")
        }
    }

    // #710: OCCTGeomFillProfilerAddCurve reaches its curve argument's Handle through an alias
    // form (`*(const Handle(Geom_Curve)*)curveRef`) that check-null-handle-guards.py cannot see,
    // and GeomFill_Profiler::AddCurve dereferences it unconditionally -- an uncatchable SIGSEGV on
    // a null Handle(Geom_Curve). No public (or @testable-reachable) factory can currently produce
    // a Curve3D wrapping a null Handle (measured across every OCCTCurve3D-constructing bridge
    // site; see Scripts/repro/644-710-geomfill-appsurf-null-arity/README.md), so this guard cannot
    // be exercised on its crashing input in-process without fabricating a hazard the public API
    // does not produce. This test instead proves the guard does not regress the ordinary path: a
    // real curve must still be added and homogenized. `Issue.record` (not a decorative
    // `if let`) so a regression that makes addCurve silently drop the curve fails loudly.
    @Test("null-handle guard does not block a valid curve (#710 regression)")
    func nullHandleGuardAllowsValidCurve() {
        guard let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let c2 = Curve3D.circle(center: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3)
        else {
            Issue.record("failed to build probe curves")
            return
        }
        let profiler = CurveProfiler.create()
        profiler.addCurve(c1)
        profiler.addCurve(c2)
        profiler.perform()
        guard profiler.degree > 0 else {
            Issue.record(
                "profiler.degree was 0 after adding two valid curves -- the null-handle guard rejected a valid curve"
            )
            return
        }
        #expect(profiler.poleCount > 0)
    }

    @Test("extract poles")
    func extractPoles() {
        if let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let c2 = Curve3D.circle(center: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3)
        {
            let profiler = CurveProfiler.create()
            profiler.addCurve(c1)
            profiler.addCurve(c2)
            profiler.perform()
            let poles = profiler.poles(curveIndex: 1)
            #expect(poles.count == profiler.poleCount)
            // #766: the count alone passed the other curve's poles. Curve 1 is the radius-5 circle
            // at z = 0; its first two homogenized poles, per GeomFill_Profiler::Poles(1), are
            // (5, 0, 0) and (5, 2.24399475257, 0), see Scripts/repro/766-geomfill-d/.
            if poles.count == 15 {
                #expect(simd_length(poles[0] - SIMD3(5, 0, 0)) < 1e-9)
                #expect(simd_length(poles[1] - SIMD3(5, 2.24399475257, 0)) < 1e-9)
            }
        } else {
            Issue.record("failed to build probe curves")
        }
    }

    @Test("knots and multiplicities")
    func knotsAndMults() {
        if let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let c2 = Curve3D.circle(center: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1), radius: 4)
        {
            let profiler = CurveProfiler.create()
            profiler.addCurve(c1)
            profiler.addCurve(c2)
            profiler.perform()
            let (knots, mults) = profiler.knotsAndMults()
            #expect(knots.count == profiler.knotCount)
            #expect(mults.count == profiler.knotCount)
            // #766: `firstMult > 0` passed a multiplicity of 1. GeomFill_Profiler reports knots
            // [0, 2 pi] with multiplicities [15, 15], see Scripts/repro/766-geomfill-d/.
            #expect(mults == [15, 15])
            #expect(knots.count == 2 && abs((knots.last ?? 0) - 2 * .pi) < 1e-9 && knots.first == 0)
        } else {
            Issue.record("failed to build probe curves")
        }
    }
}
