import Testing

@testable import OCCTSwift

/// #2875: `Geom2d_BezierCurve` and `Geom_BezierCurve` state their pole ceiling three times and
/// state it differently each time.
///
/// The constructors take `nbpoles > MaxDegree() + 1` as the refusal, so they build 26 poles and
/// refuse 27. `Increase()` agrees with them. `InsertPoleAfter` takes `nbpoles >= MaxDegree()`, so
/// it stops at 25, one pole short, and stops one pole short of what its own header comment
/// promises: "Raised if the resulting number of poles is greater than MaxDegree + 1"
/// (`Geom2d_BezierCurve.hxx:137`, `Geom_BezierCurve.hxx:134`).
///
/// **The 3D twin carries the identical predicate**, at `Geom_BezierCurve.cxx:214` against
/// `Geom2d_BezierCurve.cxx:199`, so neither side is the odd one out; they differ only in that the
/// 3D class writes it as a literal `throw`, which is live, and the 2D class writes it as
/// `Standard_ConstructionError_Raise_if`, which `No_Exception` removes from the shipped kernel
/// (`okf/policies/occt-validation-is-compiled-out.md`). The 2D refusal is therefore ours, added by
/// #2870, and it is deliberately kept at the strict kernel value so `Curve2D` and `Curve3D` answer
/// the same thing: relaxing it to the documented ceiling would make 2D accept an operation the 3D
/// kernel throws on, and that throw cannot be relaxed from the bridge.
///
/// Measured against `v4.0.0-kernel.3` in `Scripts/repro/2875/`, which also records why nothing was
/// patched. This suite pins every boundary so a kernel bump that moves either one fails here
/// rather than passing quietly.
@Suite("#2875: Bezier pole ceiling, construction against insertion")
struct Issue2875BezierPoleCeilingTests {

    private func poles2d(_ n: Int) -> [SIMD2<Double>] {
        (1...n).map { SIMD2(Double($0), Double($0 % 3)) }
    }

    private func poles3d(_ n: Int) -> [SIMD3<Double>] {
        (1...n).map { SIMD3(Double($0), Double($0 % 3), 0) }
    }

    @Test("the two classes report the same maximum degree")
    func maxDegreeAgrees() {
        #expect(Curve2D.bezierMaxDegree == 25)
        #expect(Curve3D.bezierMaxDegree == Curve2D.bezierMaxDegree)
    }

    @Test("the constructors accept maxDegree + 1 poles and refuse maxDegree + 2")
    func constructorCeiling() {
        let md = Curve2D.bezierMaxDegree
        if let c = Curve2D.bezier(poles: poles2d(md + 1)) {
            #expect(c.bezierProperties.poleCount == md + 1)
            #expect(c.bezierProperties.degree == md)
        } else {
            Issue.record("Curve2D.bezier refused \(md + 1) poles, which the kernel accepts")
        }
        #expect(
            Curve2D.bezier(poles: poles2d(md + 2)) == nil,
            "Curve2D.bezier accepted \(md + 2) poles")

        if let c = Curve3D.bezier(poles: poles3d(md + 1)) {
            #expect(c.bezier.poleCount == md + 1)
            #expect(c.bezier.degree == md)
        } else {
            Issue.record("Curve3D.bezier refused \(md + 1) poles, which the kernel accepts")
        }
        #expect(
            Curve3D.bezier(poles: poles3d(md + 2)) == nil,
            "Curve3D.bezier accepted \(md + 2) poles")
    }

    @Test("2D insertion reaches the constructor's own ceiling, since 0045 and #3013")
    func insertionCeiling2D() {
        let md = Curve2D.bezierMaxDegree
        // One below the insertion ceiling: accepted, and the result is a legal curve.
        guard let ok = Curve2D.bezier(poles: poles2d(md - 1)) else {
            Issue.record("Curve2D.bezier returned nil for \(md - 1) poles")
            return
        }
        #expect(ok.bezierInsertPoleAfter(md - 1, point: SIMD2(99, 0)))
        #expect(ok.bezierProperties.poleCount == md)

        // At md poles: now ACCEPTED, and it is the same ceiling the constructors and Increase()
        // already used. Carried patch 0045 moved the kernel's own bound and #3013 moved
        // OCCTCurve2DBezierInsertPoleAfter's to match, in the change that pinned it
        // (v4.0.0-kernel.4). Before that this assertion was `!...` and the comment here explained
        // why 2D refused what 3D also refused; both now reach md + 1.
        guard let atCeiling = Curve2D.bezier(poles: poles2d(md)) else {
            Issue.record("Curve2D.bezier returned nil for \(md) poles")
            return
        }
        #expect(
            atCeiling.bezierInsertPoleAfter(md, point: SIMD2(99, 0)),
            "bezierInsertPoleAfter refused a \(md)-pole curve, which 0045 accepts")
        #expect(atCeiling.bezierProperties.poleCount == md + 1)

        // At the constructor's ceiling: refused too. This is the one that matters for safety.
        // Unguarded, the kernel reaches md + 2 poles and Multiplicities() then reads a
        // std::array of md + 1 entries out of bounds, which aborted the probe (exit 134).
        guard let atMax = Curve2D.bezier(poles: poles2d(md + 1)) else {
            Issue.record("Curve2D.bezier returned nil for \(md + 1) poles")
            return
        }
        #expect(
            !atMax.bezierInsertPoleAfter(md + 1, point: SIMD2(99, 0)),
            "bezierInsertPoleAfter accepted a \(md + 1)-pole curve")
        #expect(atMax.bezierProperties.poleCount == md + 1)
        // Reading the two cached accessors is what faults on an over-long curve, so exercise the
        // in-bounds path and check it answers.
        #expect(atMax.bezierProperties.degree == md)
        let p = atMax.point(at: 0.5)
        #expect(p.x.isFinite && p.y.isFinite)
    }

    @Test("3D insertion reaches the same ceiling as 2D, from the kernel's own live throw")
    func insertionCeiling3D() {
        let md = Curve3D.bezierMaxDegree
        guard let ok = Curve3D.bezier(poles: poles3d(md - 1)) else {
            Issue.record("Curve3D.bezier returned nil for \(md - 1) poles")
            return
        }
        #expect(ok.bezier.insertPoleAfter(index: md - 1, point: SIMD3(99, 0, 0)))
        #expect(ok.bezier.poleCount == md)

        guard let atCeiling = Curve3D.bezier(poles: poles3d(md)) else {
            Issue.record("Curve3D.bezier returned nil for \(md) poles")
            return
        }
        // Accepted since 0045. The 3D site is a literal throw rather than a _Raise_if, so unlike
        // the 2D half this one genuinely moves in a Release kernel: measured 25 poles to 26.
        #expect(
            atCeiling.bezier.insertPoleAfter(index: md, point: SIMD3(99, 0, 0)),
            "3D insertPoleAfter refused a \(md)-pole curve, which 0045 accepts")
        #expect(atCeiling.bezier.poleCount == md + 1)

        guard let atMax = Curve3D.bezier(poles: poles3d(md + 1)) else {
            Issue.record("Curve3D.bezier returned nil for \(md + 1) poles")
            return
        }
        #expect(
            !atMax.bezier.insertPoleAfter(index: md + 1, point: SIMD3(99, 0, 0)),
            "3D insertPoleAfter accepted a \(md + 1)-pole curve")
        #expect(atMax.bezier.poleCount == md + 1)
    }

    @Test("degree elevation agrees with the constructors, not with insertion")
    func increaseCeiling() {
        let md = Curve2D.bezierMaxDegree
        guard let c2 = Curve2D.bezier(poles: poles2d(2)),
            let c3 = Curve3D.bezier(poles: poles3d(2))
        else {
            Issue.record("Curve2D.bezier or Curve3D.bezier returned nil for 2 poles")
            return
        }
        // md is reachable by elevation, so the class is willing to hold md + 1 poles by this route
        // as well as by construction. Only InsertPoleAfter disagrees.
        #expect(c2.bezierIncreaseDegree(md))
        #expect(c2.bezierProperties.poleCount == md + 1)
        #expect(c3.bezier.increaseDegree(to: md))
        #expect(c3.bezier.poleCount == md + 1)

        // md + 1 is refused on both, the 2D side by our guard and the 3D side by the kernel.
        #expect(!c2.bezierIncreaseDegree(md + 1))
        #expect(c2.bezierProperties.degree == md)
        #expect(!c3.bezier.increaseDegree(to: md + 1))
        #expect(c3.bezier.degree == md)
    }
}
