# Does `.enabled(if:)` suppress evaluation of a `@Test(arguments:)` list?

The measurement #2928 names as its first step, because five excluded files spell an input past
`Int32.max` and two of the sites sat inside an `arguments:` list with one in a `static let`. If a
disabling trait suppresses evaluation, the files can come back with the trait; if it does not, the
input itself has to be absent where `Int` is 32 bits.

Run with the pinned toolchain and SDK, under Node with the browser's WASI shim, against
`Scripts/run-wasm-tests.sh`'s own products. **The two files go in different test targets and run as
different modules**, which is the point: a trap ends a module, so a control that traps in the probe's
own module would destroy the probe's result rather than corroborate it.

```
cp Scripts/repro/2928/trait-evaluation-probe.swift   Tests/OCCTMathTests/ZZProbe2928Guarded.swift
cp Scripts/repro/2928/trait-evaluation-control.swift Tests/OCCTAnalysisTests/ZZProbe2928Control.swift
./Scripts/run-wasm-tests.sh build
P=.build/out/Products/Release-webassembly-wasm32
node Scripts/wasm-test-node-runner.mjs .build/wasm-test-shim/browser_wasi_shim \
    "$P/OCCTMathTests-test-runner.wasm" \
    --testing-library swift-testing --no-parallel --filter ZZProbe2928Guarded
node Scripts/wasm-test-node-runner.mjs .build/wasm-test-shim/browser_wasi_shim \
    "$P/OCCTAnalysisTests-test-runner.wasm" \
    --testing-library swift-testing --no-parallel --filter ZZProbe2928Control
```

## Result: YES, for all three sites

Measured 2026-10-02, Swift 6.4.0-RELEASE, swift-testing 6.4 (efd8d65801f569d), Node v26.10.0 with
`@bjorn3/browser_wasi_shim@0.4.2`, target `wasm32-unknown-wasip1`.

```
◇ Suite "ZZProbe2928Guarded: three evaluation sites behind a disabling trait" started.
➜ Test "case 1: a disabled test's argument list" skipped.
➜ Test "case 2: a disabled test reading a trapping static let" skipped.
➜ Test "case 3: a disabled test's own body" skipped.
◇ Test "sentinel: the module is still alive and reporting" started.
PROBE-GUARDED-SURVIVED bitWidth=32
✔ Test run with 4 tests in 1 suite passed after 0.014 seconds.
```

`Int.bitWidth` is 32, so each `.enabled(if: Int.bitWidth > 32)` was false, all three were skipped,
and the module reached its summary line. Nothing evaluated `Int(Int32.max) + 1`.

**The control, same three sites with the condition TRUE, ends the module:**

```
TRAP: RuntimeError: unreachable
exit=70
```

That is the whole of its output. It trapped **before `Test run started` was printed**, which places
the evaluation in test DISCOVERY rather than in a test body: of the control's three cases only the
`arguments:` list is evaluated that early, since case 2 reads its `static let` and case 3 calls
`pastInt32()` inside a body that never got to run. So a trapping `arguments:` list is not a failing
test, it is a module that dies before any test in the suite reports, which is why these files had to
be excluded rather than listed as known failures.

Both halves are needed. A probe that survives on its own proves only that the value might never trap.

## What it means for the five files, and why they do not use the trait

The trait works, and it is **not** what #2928 used. The reason is coverage, not correctness.

`.enabled(if: Int.bitWidth > 32)` disables a whole TEST, and in all five files the unrepresentable
input is one or two assertions inside a test whose other assertions are perfectly representable.
`Issue558SamplingCountBounds.requestedContract` is nine assertions of which one needs
`Int32.max + 1`; `Issue2857`'s `everyOutOfRangeIndexIsRefused` walks twelve indices of which one does;
`Issue640` has 28 tests of which one has a single such assertion. Gating the test loses the rest.

So each file instead makes the CASE conditional rather than the test:

```swift
/// `Int32.max + 1`, a count past the `int32_t` the bridge takes its count in. `nil` where `Int` is
/// 32 bits, because no `Int` is past `Int32.max` there.
private static let pastInt32: Int? = Int.bitWidth > 32 ? Int(Int32.max) + 1 : nil
```

and either `if let pastInt32 = Self.pastInt32 { ... }` at a scalar site, or `+ Self.pastInt32List`
on a list the test walks. The ternary's untaken branch is never evaluated, which this probe's case 3
is the same fact about. Apple keeps every assertion it had, byte for byte in value terms, and wasm
loses only the one case the platform cannot express.

**Where the trait is still the right tool** is a test that is wholly about a 64-bit-only input, and
none of the five had one. It is also the better tool whenever the value is needed in a
`@Test(arguments:)` list, because this measurement says the list is not evaluated: the house rule
against `@Test(arguments:)` for a reference-counted-plus-vector tuple (#1057) is what keeps those
rare here.
