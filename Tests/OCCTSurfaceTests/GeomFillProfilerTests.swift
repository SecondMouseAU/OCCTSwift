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
            #expect(profiler.degree > 0)
            #expect(profiler.poleCount > 0)
            #expect(profiler.knotCount > 0)
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
            if let firstMult = mults.first {
                #expect(firstMult > 0)
            }
        }
    }
}
