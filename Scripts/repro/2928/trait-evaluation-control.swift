import Testing

// #2928 step 1, the control for `trait-evaluation-probe.swift`. SAME THREE SITES, trait condition
// TRUE instead of false, so the only variable is the condition's value and not the presence of the
// trait machinery.
//
// A probe that survives proves nothing on its own: the value might simply never trap. This is the
// half that shows it does, and on wasm32 it is expected to END THE MODULE rather than report.
//
// IT IS BUILT ON ITS OWN, NOT ALONGSIDE THE PROBE. If `arguments:` lists turn out to be evaluated
// when the test bundle is enumerated rather than when a test runs, a trapping list anywhere in the
// module takes the module down whatever `--filter` selects, and the probe's result would be the
// control's. One file at a time is what keeps the two separable.

/// `Int32.max + 1`: representable where `Int` is 64 bits, a trap where it is 32.
private func pastInt32() -> Int { Int(Int32.max) + 1 }

@Suite("ZZProbe2928Control: the same three sites, enabled")
struct ZZProbe2928Control {

    static let lazyPastInt32 = pastInt32()

    @Test(
        "control 1: an enabled test's argument list",
        .enabled(if: Int.bitWidth > 0),
        arguments: [pastInt32()])
    func argumentList(_ n: Int) {
        print("PROBE-CONTROL-1 RAN WITH \(n)")
    }

    @Test("control 2: an enabled test reading the static let", .enabled(if: Int.bitWidth > 0))
    func staticLet() {
        print("PROBE-CONTROL-2 RAN WITH \(Self.lazyPastInt32)")
    }

    @Test("control 3: an enabled test's own body", .enabled(if: Int.bitWidth > 0))
    func body() {
        print("PROBE-CONTROL-3 RAN WITH \(pastInt32())")
    }

    @Test("sentinel: unreachable on wasm32 if any control above trapped")
    func sentinel() {
        print("PROBE-CONTROL-SURVIVED bitWidth=\(Int.bitWidth)")
    }
}
