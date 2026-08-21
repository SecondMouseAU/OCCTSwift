import Testing
import simd
@testable import OCCTSwift

/// #623. `ContinuityClass` offers two ways to ask "is this at least X", and they disagreed.
///
/// `satisfies(_:)` short-circuited on the `nil` `derivativeOrder` that `.g1`/`.g2` carry with an
/// unconditional `false`, before ever reading the requested floor. So `.g1.satisfies(.c0)` was
/// `false` while `.g1 >= .c0` was `true`, a caller gating on "is this at least positionally
/// continuous?" rejected every result *smoother* than the C0 ones it accepted.
///
/// The reasoning the fix rests on: G1 entails G0 entails positional continuity, which is exactly
/// what C0 is. There is no parametrisation subtlety at order zero, a curve is either connected
/// or it is not, so the old justification ("a g1/g2 result is not a parametric guarantee at any
/// order") is right for C1 and above and wrong for C0.
///
/// The single-cell assertions below are the reported bug; the matrix is what would have caught
/// it, and guards the whole family rather than the one cell.
@Suite("ContinuityClass floor checks agree with the ordering (#623)")
struct Issue623ContinuityFloorTests {

    /// The `ParametricContinuity` floor each `ContinuityClass` names, written out by hand rather
    /// than derived from `derivativeOrder`, so the matrix below states its expectation
    /// independently of the code under test.
    ///
    /// Three classes have no counterpart: `g1`/`g2` are geometric, not parametric, and
    /// `ParametricContinuity` stops at C3 so `cN` has nothing to name.
    static let parametricCounterpart: [ContinuityClass: ParametricContinuity] = [
        .c0: .c0, .c1: .c1, .c2: .c2, .c3: .c3,
    ]

    // MARK: - The reported cell

    @Test("A geometric class meets the C0 floor, and nothing above it")
    func geometricClassesMeetTheC0Floor() {
        // The defect: both of these were false.
        #expect(ContinuityClass.g1.satisfies(.c0))
        #expect(ContinuityClass.g2.satisfies(.c0))

        // Above C0 a geometric class still guarantees nothing about derivative vectors, which
        // is the part of the original reasoning that was right.
        #expect(!ContinuityClass.g1.satisfies(.c1))
        #expect(!ContinuityClass.g1.satisfies(.c2))
        #expect(!ContinuityClass.g1.satisfies(.c3))
        #expect(!ContinuityClass.g2.satisfies(.c1))
        #expect(!ContinuityClass.g2.satisfies(.c2))
        #expect(!ContinuityClass.g2.satisfies(.c3))

        // The fix is a floor on the missing order, not a new order: `derivativeOrder` still
        // reports nil, because a geometric class genuinely has no parametric order.
        #expect(ContinuityClass.g1.derivativeOrder == nil)
        #expect(ContinuityClass.g2.derivativeOrder == nil)
    }

    @Test("Every measured class clears the positional floor")
    func everyClassClearsTheC0Floor() {
        // C0 is the bottom of `GeomAbs_Shape`'s ladder, no class sits below it, so a caller
        // gating on "is this at least positionally continuous?" must never be told no.
        for measured in ContinuityClass.allCases {
            #expect(measured.satisfies(.c0), "\(measured) failed the C0 floor")
        }
    }

    // MARK: - The property that would have caught it

    @Test("satisfies() and >= agree across the whole 7x7 matrix, bar one documented pair")
    func satisfiesAgreesWithTheOrderingAcrossTheMatrix() {
        var compared = 0
        var disagreements: [(measured: ContinuityClass, required: ContinuityClass)] = []

        for measured in ContinuityClass.allCases {
            for required in ContinuityClass.allCases {
                // 21 of the 49 pairs name a required class that has no parametric floor to ask
                // `satisfies` about; the remaining 28 are comparable both ways.
                guard let floor = Self.parametricCounterpart[required] else { continue }
                compared += 1
                if measured.satisfies(floor) != (measured >= required) {
                    disagreements.append((measured, required))
                }
            }
        }

        #expect(compared == 28)

        // Exactly one cell may differ, and it is the one the two APIs are *documented* to answer
        // differently. `GeomAbs_Shape` ranks G2 (3) above C1 (2), but curvature continuity does
        // not entail first-derivative continuity, so the parametric floor correctly refuses what
        // the ladder allows. Every other cell must match, including (.g1, .c0) and (.g2, .c0),
        // which is where #623 lived.
        #expect(disagreements.count == 1)
        if let only = disagreements.first {
            #expect(only.measured == .g2)
            #expect(only.required == .c1)
        }
        #expect(!ContinuityClass.g2.satisfies(.c1))
        #expect(ContinuityClass.g2 >= .c1)
    }

    @Test("A floor check never claims more than the ordering allows")
    func satisfiesNeverOutrunsTheOrdering() {
        // NOTE: this does *not* guard #623, and is not meant to. #623 made `satisfies` too
        // strict, and a too-strict implementation passes this vacuously, every `false` skips
        // the body. Verified: it survives the injected bug.
        //
        // It guards the opposite failure mode, which the #623 fix is the natural way to
        // introduce: an over-correction that makes a geometric class satisfy a floor the ladder
        // itself does not reach (say, floor `?? Int.max`, or dropping the `nil` case entirely).
        // `satisfies` may be stricter than the ladder, that is the documented G2/C1 cell,
        // never looser, because that direction would have a floor check vouch for smoothness
        // the measurement never reported.
        for measured in ContinuityClass.allCases {
            for required in ContinuityClass.allCases {
                guard let floor = Self.parametricCounterpart[required] else { continue }
                if measured.satisfies(floor) {
                    #expect(measured >= required,
                            "\(measured).satisfies(\(floor)) is true but \(measured) sorts below \(required)")
                }
            }
        }
    }

    @Test("The floor is monotonic in the requested order, and in the measured class bar one pair")
    func satisfyingAFloorImpliesSatisfyingEveryLowerOne() {
        // Two directions, and only the second one guards #623.
        //
        // Direction 1, the requested order: whatever a class satisfies, it satisfies everything
        // weaker. This is what makes `satisfies` usable as a gate at all, but it holds for any
        // implementation shaped `f(measured) >= required.rawValue`, including the #623 one, so
        // it catches nothing here. It guards a future rewrite that special-cases individual
        // floors (a lookup table, say) and loses downward closure.
        for measured in ContinuityClass.allCases {
            for floor in ParametricContinuity.allCases where measured.satisfies(floor) {
                for weaker in ParametricContinuity.allCases where weaker.rawValue <= floor.rawValue {
                    #expect(measured.satisfies(weaker),
                            "\(measured) satisfies \(floor) but not the weaker \(weaker)")
                }
            }
        }

        // Direction 2, the measured class: if a weaker measurement clears a floor, a stronger
        // one should too, THIS is the invariant #623 broke, `.c0` cleared `.c0` while the
        // strictly-higher-ranked `.g1` did not, and unlike direction 1 it fails under the
        // injected bug (4 violations rather than 1).
        //
        // It cannot be asserted outright, because the documented G2/C1 cell violates it too:
        // `.c1` satisfies `.c1` and the higher-ranked `.g2` does not. So collect the violations
        // and pin the set, exactly as the 7x7 matrix does.
        var violations: [(weaker: ContinuityClass, stronger: ContinuityClass, floor: ParametricContinuity)] = []
        for weaker in ContinuityClass.allCases {
            for stronger in ContinuityClass.allCases where stronger >= weaker {
                for floor in ParametricContinuity.allCases
                where weaker.satisfies(floor) && !stronger.satisfies(floor) {
                    violations.append((weaker, stronger, floor))
                }
            }
        }
        #expect(violations.count == 1)
        if let only = violations.first {
            #expect(only.weaker == .c1)
            #expect(only.stronger == .g2)
            #expect(only.floor == .c1)
        }
    }

    // MARK: - The third contract, left alone

    @Test("The junction-analysis bitmask contract is independent of the floor check")
    func analysisBitmaskContractIsUnaffected() {
        // `ContinuityAnalysis.holds(_:)` asks a third question again: "did `LocalAnalysis_*`
        // report this *exact* class?", set membership on a `GeomAbs_Shape`-ordinal bitmask,
        // neither a floor nor a ranking. #623 changes only the `nil`-`derivativeOrder` fallback
        // inside `satisfies`, so every bit must still sit at its own raw value.
        for measured in ContinuityClass.allCases {
            #expect(measured.analysisFlagBit == 1 << Int(measured.rawValue))
        }
        #expect(ContinuityClass.g1.analysisFlagBit == 0b0010)
        #expect(ContinuityClass.g2.analysisFlagBit == 0b1000)

        // A mask naming exactly C0 and G1 decodes to exactly those two: a geometric class is a
        // member in its own right and is never folded into the parametric class below it, which
        // is why `holds(.c1)` must not start answering yes just because `.g1.satisfies(.c0)` now
        // does.
        let decoded = ContinuityClass.set(fromAnalysisMask: 0b0011)
        #expect(decoded == [.c0, .g1])
        #expect(!decoded.contains(.c1))
    }

    // MARK: - Real measured geometry

    @Test("The floor gate holds on geometry OCCT actually measured")
    func floorGateOnMeasuredGeometry() {
        // The matrix above is pure vocabulary; this walks the real `Geom_Surface::Continuity()`
        // path the gate is used on.
        if let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            #expect(plane.continuityClass == .cN)
            #expect(plane.continuityClass.satisfies(.c0))
            #expect(plane.continuityClass.satisfies(.c3))
        }
        // A cubic BSpline surface whose interior U knot repeats to full degree measures C0, the
        // weakest class OCCT reports, and must still clear the positional floor.
        let poles: [[SIMD3<Double>]] = (1...7).map { i in
            (1...4).map { j in SIMD3<Double>(Double(i), Double(j), Double((i + j) % 2)) }
        }
        if let c0 = Surface.bspline(poles: poles,
                                    knotsU: [0.0, 0.5, 1.0], multiplicitiesU: [4, 3, 4],
                                    knotsV: [0.0, 1.0], multiplicitiesV: [4, 4],
                                    degreeU: 3, degreeV: 3) {
            #expect(c0.continuityClass == .c0)
            #expect(c0.continuityClass.satisfies(.c0))
            #expect(!c0.continuityClass.satisfies(.c1))
        }
    }
}
