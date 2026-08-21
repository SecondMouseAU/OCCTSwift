import Testing
import Foundation
import simd
@testable import OCCTSwift

// #832: Shape+Modeling's fused/subtracted/intersected(tolerance:/glue:), a pre-#202/#206, v0.114.0
// era API, used to call their own narrow bridge functions (OCCTBooleanFuseWithTolerance etc.),
// bypassing the defaultBooleanTimeout watchdog and forwarding a negative tolerance straight into
// SetFuzzyValue instead of ignoring it like Shape.union/subtracting/intersection already do. They
// now delegate to that canonical family internally, same signature, same return type, these tests
// pin the two behaviors that changed underneath, plus parity between GlueMode and BooleanGlue.
@Suite("Issue #832, Shape+Modeling boolean delegation")
struct Issue832BooleanDelegation {

    private func stackedBoxes() -> (Shape, Shape)? {
        guard let lower = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let upper = Shape.box(origin: SIMD3(0, 0, 10), width: 10, height: 10, depth: 10) else {
            return nil
        }
        return (lower, upper)
    }

    private func overlappingBoxes() -> (Shape, Shape)? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10) else { return nil }
        return (a, b)
    }

    @Test("fused/subtracted/intersected(tolerance:) match union/subtracting/intersection(fuzzyValue:)")
    func toleranceDelegatesToFuzzyValue() {
        guard let (a, b) = overlappingBoxes() else { #expect(Bool(false)); return }
        let fused = a.fused(with: b, tolerance: 1e-4)
        let unioned = a.union(b, fuzzyValue: 1e-4)
        #expect(fused != nil && unioned != nil)
        if let f = fused, let u = unioned {
            #expect(abs((f.volume ?? -1) - (u.volume ?? -2)) < 1e-6)
        }

        let subtracted = a.subtracted(b, tolerance: 1e-4)
        let subtracting = a.subtracting(b, fuzzyValue: 1e-4)
        #expect(subtracted != nil && subtracting != nil)
        if let s1 = subtracted, let s2 = subtracting {
            #expect(abs((s1.volume ?? -1) - (s2.volume ?? -2)) < 1e-6)
        }

        let intersected = a.intersected(with: b, tolerance: 1e-4)
        let intersection = a.intersection(b, fuzzyValue: 1e-4)
        #expect(intersected != nil && intersection != nil)
        if let x1 = intersected, let x2 = intersection {
            #expect(abs((x1.volume ?? -1) - (x2.volume ?? -2)) < 1e-6)
        }
    }

    // Before #832, fused(with:tolerance:) forwarded a negative tolerance straight into
    // BRepAlgoAPI_Fuse::SetFuzzyValue, an untested, undocumented code path the auditor flagged as
    // a risk relative to union(_:fuzzyValue:)'s documented "negative is ignored" contract.
    // Measured directly (not assumed) with a small-gap fixture designed to tell "ignored" apart
    // from "applied": a gap too wide to close without fuzzy tolerance closes under tolerance: 0.01
    // (shellCount 2 -> 1) but stays open under tolerance: -0.01, identically to tolerance: 0, on
    // BOTH the pre-#832 direct-bridge-call implementation and the post-#832 delegated one. So
    // BRepAlgoAPI_Fuse::SetFuzzyValue itself already discards a negative value; #832's delegation
    // makes the *contract* consistent with union's (and removes the untested, duplicated bridge
    // path) but does not change this specific observable behavior, which was already safe. Kept
    // as a parity/regression test, not evidence of a behavior fix, see the PR body for the
    // measurement this comment summarizes.
    @Test("negative tolerance behaves the same as tolerance: 0, matching union's contract")
    func negativeToleranceIgnored() {
        guard let (a, b) = stackedBoxes() else { #expect(Bool(false)); return }
        if let f = a.fused(with: b, tolerance: -5) {
            #expect(abs((f.volume ?? 0) - 2000.0) < 1.0)
        } else {
            #expect(Bool(false), "fused(with:tolerance: -5) returned nil")
        }
    }

    // GlueMode { shift=0, full=1, off=2 } and BooleanGlue { off=0, shift=1, full=2 } encode the
    // same BOPAlgo_GlueEnum choice with opposite raw-value orderings (#832). A raw-value cast
    // (`BooleanGlue(rawValue: glueMode.rawValue)`) would silently repoint every case to the wrong
    // BOPAlgo_GlueEnum. Asserted two ways: directly against the mapping (the discriminating
    // check, a coincident-face fixture like stackedBoxes() below produces the identical fused
    // volume under every glue mode, since glue mode is a BOP performance/robustness hint rather
    // than something that changes the correct answer for simple geometry, so a volume-only
    // comparison alone would NOT have caught a raw-value regression here, measured, not assumed),
    // and via the delegated call, as a parity sanity check.
    @Test("GlueMode maps to BooleanGlue by case name, not raw value")
    func glueModeMapsByCaseName() {
        #expect(Shape.GlueMode.shift.asBooleanGlue == .shift)
        #expect(Shape.GlueMode.full.asBooleanGlue == .full)
        #expect(Shape.GlueMode.off.asBooleanGlue == .off)

        guard let (a, b) = stackedBoxes() else { #expect(Bool(false)); return }
        let cases: [(Shape.GlueMode, Shape.BooleanGlue)] = [(.shift, .shift), (.full, .full), (.off, .off)]
        for (glueMode, booleanGlue) in cases {
            let viaGlueMode = a.fused(with: b, glue: glueMode)
            let viaBooleanGlue = a.union(b, glue: booleanGlue)
            #expect(viaGlueMode != nil, "fused(with:glue: \(glueMode)) returned nil")
            #expect(viaBooleanGlue != nil, "union(_:glue: \(booleanGlue)) returned nil")
            if let g = viaGlueMode, let u = viaBooleanGlue {
                #expect(abs((g.volume ?? -1) - (u.volume ?? -2)) < 1e-6,
                        "GlueMode.\(glueMode) should match BooleanGlue.\(booleanGlue) by case name")
            }
        }
    }

    // #832's other stated fix: the six delegating entry points now carry the same
    // defaultBooleanTimeout watchdog as union/subtracting/intersection, which they had no
    // equivalent of at all before. A sane call still succeeds with the correct volume under the
    // (now-inherited) default 120s timeout.
    @Test("delegated calls still succeed under the inherited default timeout")
    func delegatedCallsSucceedUnderDefaultTimeout() {
        guard let (a, b) = overlappingBoxes() else { #expect(Bool(false)); return }
        // union 1000 + 1000 - 500(overlap) = 1500; intersection 500; subtract 1000-500 = 500
        if let f = a.fused(with: b, tolerance: 0) { #expect(abs((f.volume ?? 0) - 1500) < 1) }
        else { #expect(Bool(false), "fused nil under inherited default timeout") }
        if let x = a.intersected(with: b, tolerance: 0) { #expect(abs((x.volume ?? 0) - 500) < 1) }
        else { #expect(Bool(false), "intersected nil under inherited default timeout") }
        if let s = a.subtracted(b, tolerance: 0) { #expect(abs((s.volume ?? 0) - 500) < 1) }
        else { #expect(Bool(false), "subtracted nil under inherited default timeout") }
    }

    // Review finding on PR #867: the six delegating entry points inherited defaultBooleanTimeout
    // (120s) with no way to override it, since none of them exposed a timeout: parameter, a
    // caller whose fuzzy-tolerance boolean on a large assembly previously took, say, 150s and
    // eventually succeeded would now silently get nil at 120s instead, with no opt-out. Fixed by
    // adding timeout: (default Shape.defaultBooleanTimeout) to all six entry points, mirroring
    // Issue206BooleanTimeoutTests.tinyTimeoutInterrupts()'s deterministic mechanism: a deadline
    // already in the past interrupts the build at its first progress checkpoint, even for an
    // otherwise-fast valid boolean, proving timeout: is actually threaded through to the
    // underlying union/subtracting/intersection call rather than merely accepted and ignored.
    @Test("explicit timeout: is threaded through to the underlying call, not ignored (all six entry points)")
    func explicitTimeoutIsThreadedThrough() {
        guard let (a, b) = overlappingBoxes() else { #expect(Bool(false)); return }
        let tiny = 1e-7
        // tolerance: overload
        #expect(a.fused(with: b, tolerance: 0, timeout: tiny) == nil)
        #expect(a.subtracted(b, tolerance: 0, timeout: tiny) == nil)
        #expect(a.intersected(with: b, tolerance: 0, timeout: tiny) == nil)
        // glue: overload
        #expect(a.fused(with: b, glue: .off, timeout: tiny) == nil)
        #expect(a.subtracted(b, glue: .off, timeout: tiny) == nil)
        #expect(a.intersected(with: b, glue: .off, timeout: tiny) == nil)

        // Same operations succeed with a sane explicit timeout, proving the tiny-timeout nils
        // above are the watchdog firing and not some other failure mode.
        if let f = a.fused(with: b, tolerance: 0, timeout: 60) { #expect(abs((f.volume ?? 0) - 1500) < 1) }
        else { #expect(Bool(false), "fused nil under a 60s explicit timeout") }
        if let g = a.fused(with: b, glue: .off, timeout: 60) { #expect(abs((g.volume ?? 0) - 1500) < 1) }
        else { #expect(Bool(false), "fused(glue:) nil under a 60s explicit timeout") }
    }
}
