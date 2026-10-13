import Testing

@testable import OCCTSwift

/// The curve index and empty-profiler bounds that `GeomFill_Profiler` states and does not check.
///
/// #2884: adjudicating this class's `#ifndef No_Exception` region found two defects the region is
/// not about, both uncatchable and both two lines of public Swift away.
///
/// The named region, at `GeomFill_Profiler.cxx:334`, swallows `int n = NbKnots()` and the check it
/// fed asks whether the caller's `Knots` and `Mults` are that long.
/// `OCCTGeomFillProfilerKnotsAndMults` sizes both arrays from `NbKnots()` on the same object two
/// statements earlier, so it cannot violate that condition; no guard is owed and none was added.
///
/// What the class does not guard, measured in `Scripts/repro/2884` against the pinned kernel:
///
/// - `Poles(Index, ...)` documents "Raises if <Index> not in the range [1,NbCurves]" and tests it
///   with two `Standard_DomainError_Raise_if` lines the Release kernel compiles out. With two
///   curves loaded, index 0 SIGSEGVd and index 5 or 1000000 returned, filling the caller's array
///   with another curve's poles read from past the end of the sequence.
/// - `Perform()` reaches `UnifyByInsertingAllKnots`, whose first statement indexes the first curve
///   of the sequence. On an empty profiler the process faulted before `Perform` returned. One
///   curve is enough.
///
/// Both are now bounded in the bridge against a count the bridge keeps itself, because
/// `GeomFill_Profiler` exposes none.
@Suite("#2884: GeomFill_Profiler index and empty-profiler bounds")
struct Issue2884GeomFillProfilerBoundsTests {

    private static func loaded(_ count: Int) -> CurveProfiler? {
        let profiler = CurveProfiler.create()
        for i in 0..<count {
            guard
                let c = Curve3D.circle(
                    center: SIMD3(0, 0, Double(i) * 5), normal: SIMD3(0, 0, 1),
                    radius: 5 - Double(i))
            else { return nil }
            profiler.addCurve(c)
        }
        return profiler
    }

    @Test("perform() refuses an empty profiler instead of faulting")
    func emptyProfilerRefused() {
        let profiler = CurveProfiler.create()
        #expect(profiler.perform() == false)
        // The accessors stay answerable afterwards rather than reporting a homogenization that
        // never happened.
        #expect(profiler.poleCount == 0)
        #expect(profiler.knotCount == 0)
        #expect(profiler.poles(curveIndex: 1).isEmpty)
    }

    @Test("perform() still succeeds with one curve, which is the measured boundary")
    func oneCurveIsEnough() {
        guard let profiler = Self.loaded(1) else {
            Issue.record("failed to build the probe curve")
            return
        }
        #expect(profiler.perform())
        #expect(profiler.poleCount > 0)
        #expect(profiler.poles(curveIndex: 1).count == profiler.poleCount)
    }

    @Test("poles() answers for every real index and refuses every other one")
    func polesIndexBounds() {
        guard let profiler = Self.loaded(2) else {
            Issue.record("failed to build the probe curves")
            return
        }
        #expect(profiler.perform())
        let n = profiler.poleCount
        #expect(n > 0)
        #expect(profiler.poles(curveIndex: 1).count == n)
        #expect(profiler.poles(curveIndex: 2).count == n)
        // Written as one test walking a list rather than @Test(arguments:), per CLAUDE.md.
        for index in [0, -1, 3, 5, 1_000_000, Int.min, Int.max] {
            #expect(
                profiler.poles(curveIndex: index).isEmpty,
                "poles(curveIndex: \(index)) returned poles for a curve that is not there")
        }
    }

    @Test("the two real curves are distinct, so an out-of-range index cannot pass by luck")
    func realIndicesAddressDifferentCurves() {
        guard let profiler = Self.loaded(2) else {
            Issue.record("failed to build the probe curves")
            return
        }
        #expect(profiler.perform())
        let first = profiler.poles(curveIndex: 1)
        let second = profiler.poles(curveIndex: 2)
        guard let a = first.first, let b = second.first else {
            Issue.record("a real curve index returned no poles")
            return
        }
        #expect(a != b)
    }

    @Test("knotsAndMults() keeps working: the region itself owed no guard")
    func knotsAndMultsUnchanged() {
        guard let profiler = Self.loaded(2) else {
            Issue.record("failed to build the probe curves")
            return
        }
        #expect(profiler.perform())
        let (knots, mults) = profiler.knotsAndMults()
        #expect(knots.count == profiler.knotCount)
        #expect(mults.count == profiler.knotCount)
    }
}
