import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1067: the #206 watchdog is right to bound a boolean, but until now the bound and a genuine
// boolean failure produced the same `nil`, so a caller could not tell "this geometry is bad" from
// "this machine was busy". The three `*Outcome` methods separate them; `union`/`subtracting`/
// `intersection` keep the old collapsed `nil` and are now thin wrappers over them.
//
// Both halves of the distinction are driven deterministically, with no wall-clock wait:
//
//   - timedOut: a `timeout` of 1e-9 puts the deadline in the past before `Build()` is entered, so
//     the first `UserBreak()` poll trips. This is the technique `Issue206BooleanTimeout` already
//     uses at 1e-7 and is not a race against machine speed: a faster machine reaches the first poll
//     sooner, but the deadline is already behind it either way. Measured in
//     `Scripts/repro/1067-boolean-timeout-outcome/probe_1067.mm`: 200/200 trips, 0/200 completions,
//     first poll reached in 0.0002s.
//   - failed: a nullified operand is refused before the progress scope advances even once
//     (`polls == 0` in the same probe, at a 120s timeout), so the watchdog structurally cannot have
//     fired and the outcome must be `.failed`.
@Suite("Issue #1067, a boolean timeout is not a boolean failure")
struct Issue1067BooleanOutcome {

    /// A deadline already in the past when `Build()` starts.
    ///
    /// See the suite comment for why this is deterministic rather than a race.
    private static let pastDeadline = 1e-9

    private func overlappingBoxes() -> (Shape, Shape)? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        else { return nil }
        return (a, b)
    }

    /// Readable failure text: `#expect` on the enum itself would print nothing useful, since
    /// `BooleanOutcome` carries a `Shape` and is deliberately not `Equatable`.
    private func label(_ outcome: Shape.BooleanOutcome) -> String {
        switch outcome {
        case .success: return "success"
        case .failed: return "failed"
        case .timedOut: return "timedOut"
        }
    }

    /// The three ops, each as (name, outcome-returning call).
    ///
    /// Named rather than enum-selected because `Shape.BooleanOperation` already exists for
    /// `analyzeBoolean` with a different case set, and a second boolean-operation enum is the
    /// `GlueMode`/`BooleanGlue` trap.
    private func outcomes(_ a: Shape, _ b: Shape, timeout: Double)
        -> [(String, Shape.BooleanOutcome)]
    {
        [
            ("union", a.unionOutcome(b, timeout: timeout)),
            ("subtraction", a.subtractionOutcome(b, timeout: timeout)),
            ("intersection", a.intersectionOutcome(b, timeout: timeout)),
        ]
    }

    // MARK: - The distinction itself

    @Test("an expired deadline reports timedOut, not failed (all three ops)")
    func expiredDeadlineIsTimedOut() {
        guard let (a, b) = overlappingBoxes() else {
            #expect(Bool(false), "fixture")
            return
        }
        for (name, outcome) in outcomes(a, b, timeout: Self.pastDeadline) {
            #expect(label(outcome) == "timedOut", "\(name) at an expired deadline")
            #expect(outcome.shape == nil, "\(name) must carry no shape when it timed out")
        }
    }

    @Test("a refused operand reports failed even with the watchdog armed (all three ops)")
    func refusedOperandIsFailed() {
        guard let (a, _) = overlappingBoxes(), let empty = a.nullified else {
            #expect(Bool(false), "fixture")
            return
        }
        // The fixture must keep meaning its name: a `nullified` copy that was not actually null
        // would make every assertion below read a successful boolean's `.failed` that never was.
        #expect(empty.isNull, "the refusing operand must really be a null shape")

        // The default 120s watchdog IS armed here. This is the case that separates "the watchdog
        // reported" from "a watchdog existed": the probe measures zero polls on this path, so
        // `tripped()` is false and the outcome must be `.failed`.
        for (name, outcome) in outcomes(a, empty, timeout: Shape.defaultBooleanTimeout) {
            #expect(label(outcome) == "failed", "\(name) with a nullified operand, watchdog armed")
        }
        // And unbounded, where `.timedOut` is unreachable by construction (no breaker exists).
        for (name, outcome) in outcomes(a, empty, timeout: 0) {
            #expect(label(outcome) == "failed", "\(name) with a nullified operand, unbounded")
        }
    }

    @Test("a completed boolean reports success and the operation actually did something")
    func completedBooleanIsSuccess() {
        guard let (a, b) = overlappingBoxes() else {
            #expect(Bool(false), "fixture")
            return
        }
        // Two 1000-unit boxes overlapping by 500: union 1500, intersection 500, cut 500. Each
        // differs from both operands, so a no-op passthrough could not satisfy these.
        let expected = ["union": 1500.0, "subtraction": 500.0, "intersection": 500.0]
        for (name, outcome) in outcomes(a, b, timeout: Shape.defaultBooleanTimeout) {
            #expect(label(outcome) == "success", "\(name) at the default timeout")
            if let shape = outcome.shape {
                #expect(abs((shape.volume ?? 0) - (expected[name] ?? -1)) < 1, "\(name) volume")
            } else {
                #expect(Bool(false), "\(name) carried no shape")
            }
        }
    }

    // MARK: - The named methods are unchanged

    @Test("union/subtracting/intersection still collapse both outcomes to nil")
    func namedMethodsStillReturnNilForBoth() {
        guard let (a, b) = overlappingBoxes(), let empty = a.nullified else {
            #expect(Bool(false), "fixture")
            return
        }
        // The whole point of the additive design: these three keep the contract they shipped with.
        #expect(a.union(b, timeout: Self.pastDeadline) == nil)
        #expect(a.subtracting(b, timeout: Self.pastDeadline) == nil)
        #expect(a.intersection(b, timeout: Self.pastDeadline) == nil)
        #expect(a.union(empty) == nil)
        #expect(a.subtracting(empty) == nil)
        #expect(a.intersection(empty) == nil)
    }

    @Test("the named methods return exactly their outcome sibling's shape")
    func namedMethodsAgreeWithTheOutcome() {
        guard let (a, b) = overlappingBoxes() else {
            #expect(Bool(false), "fixture")
            return
        }
        // Second construction: the same geometry reached by two different entry points must agree,
        // which is what makes the delegation safe to claim as source-compatible.
        let pairs: [(Shape?, Shape.BooleanOutcome)] = [
            (a.union(b), a.unionOutcome(b)),
            (a.subtracting(b), a.subtractionOutcome(b)),
            (a.intersection(b), a.intersectionOutcome(b)),
        ]
        for (named, outcome) in pairs {
            if let named, let viaOutcome = outcome.shape {
                #expect(abs((named.volume ?? -1) - (viaOutcome.volume ?? -2)) < 1e-9)
            } else {
                #expect(Bool(false), "one entry point produced no shape")
            }
        }
    }

    // MARK: - circularPatternCut can now set the bound

    @Test("circularPatternCut forwards its timeout to the subtraction")
    func circularPatternCutForwardsTimeout() {
        guard let blank = Shape.cylinder(radius: 20, height: 10),
            let tool = Shape.cylinder(radius: 2, height: 30)?.translated(by: SIMD3(15, 0, -10)),
            let blankVolume = blank.volume
        else {
            #expect(Bool(false), "fixture")
            return
        }
        // An expired deadline reaches the boolean, which is the only way this can be nil: the
        // count is positive and the pattern itself has no watchdog.
        #expect(
            blank.circularPatternCut(
                tool: tool, axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 8,
                timeout: Self.pastDeadline) == nil)

        // The default bound still drills, and drills something: the result must lose material.
        if let drilled = blank.circularPatternCut(
            tool: tool, axisPoint: .zero, axisDirection: SIMD3(0, 0, 1), count: 8),
            let drilledVolume = drilled.volume
        {
            #expect(drilledVolume < blankVolume - 1, "8 bores must remove material")
        } else {
            #expect(Bool(false), "default-timeout pattern cut returned nil")
        }
    }
}
