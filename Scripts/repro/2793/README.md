# #2793: the per-domain test suites, built and run for `wasm32-unknown-wasip1`

Phase 0's GO carried four conditions. The third was "six calls are not a test suite": nothing but
#2052's six spike calls had ever run for wasm, and there was no parity check against the Apple
kernel. This directory holds the measurements behind closing it.

**Result: 13 of the 18 per-domain targets build and run under the pinned wasmkit.**
`Scripts/run-wasm-tests.sh` drives them and `Scripts/wasm-test-known-failures.txt` holds the
cross-platform differences it found.

Every number below was measured on this machine, macOS 27 / arm64, against the pinned toolchain in
`Scripts/wasm-toolchain-versions.txt` and the `v4.0.0-kernel.2` wasm kernel.

## 1. `Int` is 32 bits on wasm32, and it stops five test files dead

`intwidth/` is a three-line SwiftPM package built for the triple and run under wasmkit:

```
Int.bitWidth = 32
Int.max = 2147483647
Int32.max = 2147483647
Int(Int32.max) + 1 overflows: true -> -2147483648
```

Five test files exist to prove that a count past the bridge's `int32_t` is refused, and each spells
that input `Int(Int32.max) + 1`. On wasm32 the expression is not a large number, it is a trap. The
first run of `OCCTMathTests` died there, in
`Issue640MathDimensionBoundsTests.findAllRootsSamplesBounds`, after 500 lines of passing suites.

Two repairs were tried and rejected, and `Package.swift` records both:

- `Int(clamping: Int64(Int32.max) + 1)` does not trap but clamps to `Int32.max` on wasm32, which is a
  **different** assertion. The guards under test refuse counts *greater than* `Int32.max`, so at
  exactly `Int32.max` the call proceeds and attempts the two-billion-element allocation for real.
  That is how `OCCTCurveTests` came to hang for minutes instead of failing.
- `.enabled(if: Int.bitWidth > 32)` is the idiomatic Swift Testing skip and is the likely end state,
  but two of the sites sit inside a `@Test(arguments:)` list and one in a `static let`, and whether a
  trait suppresses evaluation of an argument list has to be measured before it is relied on.

**Nothing in `Sources/` is wrong because of this.** A `count > Int32.max` guard cannot be true when
`Int.max == Int32.max`; it is unreachable on wasm32, not broken.

## 2. Apple's `simd` re-exports libm, so the stand-in must too

`simd-libm/probe.swift` imports `simd` and nothing else, and calls `cos(1.0)` and `atan2(1.0, 2.0)`:

```
0.5403023058681398 0.4636476090008061
```

So on Apple, `import simd` is what puts the C math functions in scope. 90 of the 1,428 files under
`Tests/` rely on exactly that, most importing only `Testing`, `simd` and `OCCTSwift`. Before the
`@_exported import WASILibc` in `Sources/WASICompat/simd/SIMDCompat.swift` they failed with
`cannot find 'cos' in scope`.

It re-exports the math functions and **not** all of Darwin: the same file needs `import Foundation`
for `exit` and `String.padding`. The claim in the source comment is about libm and is no wider.

## 3. Three more places the stand-in was not faithful

All three found by building the tests, none reachable from `Sources/OCCTSwift`.

| | Apple | the stand-in, before #2793 |
|---|---|---|
| `simd_float4x4()` | the **zero** matrix, `simd_determinant` 0.0 | documented and built as the identity |
| `simd_double3x3()` | the zero matrix | the identity |
| `m[i]` | column `i` | no subscript at all |
| `simd_determinant` | exists | missing |
| `length`/`distance`/`dot`/`cross`/`normalize` | exported unqualified as well as `simd_`-prefixed | `simd_`-prefixed only |

`initcheck/` and `subscripts/` are the probes. The subscript order matters and a symmetric matrix
cannot reveal it, so it was measured on an asymmetric one:
`simd_double3x3(SIMD3(1,2,3), SIMD3(4,5,6), SIMD3(7,8,9))` gives `m[0] == SIMD3(1,2,3) == columns.0`
and `m[0][1] == 2`, and `simd_float4x4`'s `f[2][3] == 12`. Column-indexed, both.

The only site in the package that reads a matrix by subscript is
`CenterOfMassTests`' `props.momentOfInertia[1][1]`, which is on the diagonal: the one case that
would have hidden a transpose.

## 4. `simd_determinant` against Apple's own: 20,006 cases

`determinant-parity.swift` compiles on macOS, where both implementations exist, and compares them.
The stand-in's body is pasted in rather than imported, because the `simd` target is reachable only
when `isWASI` and its name collides with Apple's.

```
20,000 random matrices plus 6 named cases, tolerance 1e-05
worst relative difference: 2.861023e-06 (random #9703)
PARITY
```

**The tolerance is derived, not tuned to pass.** The expansion is about 60 float operations, so
worst-case error growth is around `60 * Float.ulpOfOne` = 7.1e-6, and 1e-5 sits just above that.
Accumulating the same expansion in `Double` and narrowing at the end was measured too and moves the
worst case only from 2.9e-6 to 2.2e-6. That 25% is the tell: most of the residual is **Apple's**
rounding, not this function's, since the Double form is nearer the true value. There is no bit-parity
to chase, so `Float` accumulation is kept because it matches the type it is declared on.

### Proving the comparison catches something

Per [`prove-the-test-fails.md`](../../../okf/policies/prove-the-test-fails.md), one cofactor sign was
flipped, the classic 4x4 determinant mistake:

```
20,000 random matrices plus 6 named cases, tolerance 1e-05
worst relative difference: 49.95464 (random #2623)
20000 MISMATCHES
```

exit 1, and **all seven named cases still passed.** Every one of them is zero, diagonal, singular or
sign-symmetric, so the named cases alone would have blessed the defect. The random sweep is the part
that works, which is the reason it is 20,000 and not six.

## 5. The finding: OCCT's inline validation does not raise on wasm (#2891)

The one real cross-platform difference in shipped behaviour that the coverage found, and the reason
`Scripts/wasm-test-known-failures.txt` exists. Measured with `OCCTDiagnostics.capturing` around a
single call, identical inputs on both platforms:

```swift
let cs = CoordinateSystem3D(
    origin: SIMD3(5, 3, 2), direction: SIMD3(0, 0, 1), xDirection: SIMD3(0, 0, 1))
let (translated, diagnostics) = OCCTDiagnostics.capturing { cs.translated(by: SIMD3(1, 2, 3)) }
```

| | Apple | wasm |
|---|---|---|
| `diagnostics.count` | **2** | **0** |
| records | `OCCTAx3Translate: Standard_ConstructionError: gp_Dir() - input vector has zero norm`, and the same for `OCCTAx3Create` | none |
| `translated.origin` | `(5, 3, 2)`, the documented unmoved fallback | `(6, 5, 5)` |

`records=0` is the important half. The bridge's `catch (...)` never ran, so nothing was thrown; the
degenerate axis was used as though it were valid and the translation applied to it. This is not a
caught-and-mishandled exception, it is a check that did not fire.

Four candidate explanations were ruled out by measurement:

- **`No_Exception` defined for the wasm bridge.** It is not. A TU including
  `Standard_ConstructionError.hxx` with the wasm bridge's own flags reports both `No_Exception` and
  `No_Standard_ConstructionError` undefined.
- **A different header tree.** Both are 7,160 files, and `gp_Dir.hxx` carries the inline
  `Standard_ConstructionError_Raise_if(aSqMod <= gp::Resolution() * gp::Resolution(), ...)` in both.
- **A different build type.** `build-occt.sh` and `build-occt-wasm.sh` both configure
  `-DCMAKE_BUILD_TYPE=Release`.
- **The condition being false.** `(0,0,1)` crossed with `(0,0,1)` is exactly `(0,0,0)` in IEEE
  double on any target.

So the check is present, live and reached, and does not raise. That points at the exception path
itself rather than at configuration, which is why it is filed separately (#2891) rather than fixed
here. It sits next to #2757, the invalid `br_table` from setjmp plus wasm exceptions in one function.

`okf/policies/occt-validation-is-compiled-out.md` and `Scripts/census-compiled-out-validation.py`
explain why the check is inline in the bridge's TU at all, and name `gp_Ax2(P, N, Vx)` as the worked
example of the same shape.

## 6. Eight things about running Swift Testing on wasm

1. **SwiftPM builds one `<Target>-test-runner.wasm` per test target** and has no runner for the
   triple, so `swift test --swift-sdk` cannot be used. There is no single bundle.
2. **`--testing-library swift-testing` is required at run time.** Without it the generated entry
   point runs XCTest first, and `XCTMain` reads `Bundle.main`, which traps on WASI before any test
   executes. The trap is in `Foundation.Bundle.main`'s addressor under `XCTMainMisc`. Every test in
   this package is Swift Testing, so the selection skips nothing.
3. **`--disable-xctest` at build time does not work.** The flag is accepted and the new Swift Build
   system relinks the runner with XCTest anyway; the runner's mtime updates and its size does not.
4. **`-Xswiftc -enable-testing` is required in release configuration.** Without it all 13 targets
   fail with `module 'OCCTSwift' was not compiled for testing`.
5. **`--no-parallel` is required, and not for speed.** Swift Testing parallelises by default, which on
   a single-threaded target means hundreds of concurrent tasks on one cooperative executor. Running
   `OCCTCurveTests` in the default mode printed **563 "started" lines and zero completions**: the slow
   tests interleave with everything else and nothing finishes, so the run looks hung and gives no way
   to tell which test is responsible. The same runner with `--no-parallel` completed 281 tests in
   under three minutes. This also cost a wrong diagnosis worth recording: with 563 tests started and
   none finished, the last `◇ Test ... started` line looks like the culprit, and it was not. Those two
   `GCPntsTangentialDeflectionTests` cases pass in **0.017 s** when run alone.
6. **`wasmkit run` takes its own options BEFORE the module path.** Anything after the path is handed
   to the guest, so `wasmkit run module.wasm --dir /tmp` is accepted, passed to Swift Testing,
   ignored, and grants no preopen at all. This is the one that cost the most: running wasmkit by hand
   with the flags in the right order passed while the script with the same flags failed, which sent
   the diagnosis first to the work directory's path form and then to `TMPDIR` alone. `TMPDIR` was
   necessary; the ordering is what made it take effect.
7. **`TMPDIR` must be set in the guest, and preopens alone are not enough.**
   `docs/guides/wasm-consumer-setup.md` already says so for consumers ("set `TMPDIR` and preopen
   it"); this runner was not doing it. Measured on the full `OCCTBRepGraphTests` suite: **1 failing**
   with both preopens and no `TMPDIR`, **0 failing** with `TMPDIR` pointed at the work directory.
   Under `--filter Issue336` it passed either way, which is exactly what made the preopens look
   sufficient and cost a round of wrong conclusions.

   The symptom is the misleading part: `FileManager.default.temporaryDirectory` resolves somewhere
   uncovered, the write is denied, and the bridge reports
   `.exportFailed("BREP export to issue336-….brep failed")`, which reads as a geometry or history
   defect rather than a missing environment variable.
8. **One test can cost seven minutes, and that is the interpreter, not wasm.**
   `GCPntsSamplerBoundsTests` walks arc length on an ellipse with a 1e9 aspect ratio for each of 16
   measured overshoot counts. Under wasmkit one of its two tests **passed after 422.275 seconds**,
   about 26 s per count, while the other 281 tests in that suite took under three minutes between
   them. wasmkit interprets and a browser compiles wasm, so this is close to meaningless as a
   statement about the port: the test passes, slowly, and is excluded for CI cost. It is worth
   running again when #2052's rung 3 puts a real engine behind the suites.

And one local-development trap, which CI does not have because CI always builds clean:
**Swift Build does not re-plan when a target's `exclude:` list changes.** After adding exclusions the
archive was rebuilt, with a fresh mtime and an identical size, still containing 884 symbols from the
excluded files in `OCCTCurveTests` and 145 in `OCCTAnalysisTests`. The artefacts have to be deleted.
That is what made the first full run of the suites worthless, and what made `OCCTCurveTests` hang:
the two-billion-iteration loop from section 1 was still linked in.
