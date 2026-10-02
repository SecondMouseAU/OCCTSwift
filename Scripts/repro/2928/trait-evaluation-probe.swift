import Testing

// #2928 step 1: does `.enabled(if:)` suppress evaluation of what a DISABLED test would evaluate?
//
// The question is not academic on wasm32, where `Int` is 32 bits: `Int(Int32.max) + 1` COMPILES
// there (measured, see this directory's README) and TRAPS at run time, and a trap ends the whole
// module, so every test after it is unreported. Five excluded files spell exactly that input. If a
// disabling trait suppresses evaluation they come back with the trait; if it does not, they need
// the input itself to be absent where `Int` is 32 bits.
//
// Three places the value could be evaluated, and this probe separates them:
//
//   1. a `@Test(arguments:)` list, which the macro captures and the framework enumerates;
//   2. a `static let`, which is lazy and initialised on first access;
//   3. the body of a disabled test.
//
// It asserts nothing beyond surviving, because what carries the information is whether the module
// reaches its summary line at all. See the README for how to run it and for what it measured.

/// `Int32.max + 1`: representable where `Int` is 64 bits, a trap where it is 32.
private func pastInt32() -> Int { Int(Int32.max) + 1 }

@Suite("ZZProbe2928Guarded: three evaluation sites behind a disabling trait")
struct ZZProbe2928Guarded {

    /// Case 2, a lazy `static let`.
    ///
    /// Lazy, so this traps only if something reads it.
    static let lazyPastInt32 = pastInt32()

    @Test(
        "case 1: a disabled test's argument list",
        .enabled(if: Int.bitWidth > 32),
        arguments: [pastInt32()])
    func argumentList(_ n: Int) {
        print("PROBE-1 RAN WITH \(n)")
    }

    @Test("case 2: a disabled test reading a trapping static let", .enabled(if: Int.bitWidth > 32))
    func staticLet() {
        print("PROBE-2 RAN WITH \(Self.lazyPastInt32)")
    }

    @Test("case 3: a disabled test's own body", .enabled(if: Int.bitWidth > 32))
    func body() {
        print("PROBE-3 RAN WITH \(pastInt32())")
    }

    @Test("sentinel: the module is still alive and reporting")
    func sentinel() {
        print("PROBE-GUARDED-SURVIVED bitWidth=\(Int.bitWidth)")
        #expect(Int.bitWidth == 32 || Int.bitWidth == 64)
    }
}
