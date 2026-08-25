# Investigation: #1072 — Was #345's SIGABRT Caused by the #1057 Toolchain Defect?

## Executive Summary

**Conclusion**: The #345 SIGABRT crash was **not** caused by the #1057 toolchain defect. The #345 fix (guarding 49 `gp_Dir`/`Geom_Direction` constructions with try/catch) correctly addressed the root cause, and the toolchain defect could not have triggered at the time #345 occurred because no `@Test(arguments:)` sites used the problematic tuple pattern.

---

## Background

### Issue #345 (Closed July 22, 2026)
- **Symptom**: Parallel `swift test` runs hit `exited with unexpected signal code 6` (SIGABRT) ~1-in-10 runs
- **Evidence**: Only the Swift Testing harness message; no test name, no backtrace
- **Fix Applied** (commit `b66f4df6`): Wrapped 49 bridge functions constructing `gp_Dir`/`gp_Ax1`/`gp_Ax2`/`gp_Ax3`/`Geom_Direction` in try/catch blocks
- **Validation**: 70 additional full-suite runs (309,540 test executions) — zero crashes
- **Root Cause Identified**: OCCT's `gp_Dir` constructor throws `Standard_ConstructionError` for zero-length vectors; uncaught C++ exceptions crossing the bridge boundary cause `std::terminate()` → `abort()` (SIGABRT)

### Issue #1057 (Closed August 21, 2026)
- **Defect**: `@Test(arguments:)` over tuples mixing a reference-counted type (`String`, `Array`, class) with a builtin vector ≥32 bytes (`SIMD3<Double>`, `SIMD4<Double>`, etc.) crashes the test process
- **Signals**: SIGSEGV with `freed pointer was not the last allocation` (Swift task allocator check) or SIGABRT
- **Mechanism**: Swift Concurrency task allocator stack-discipline corruption in the `@Test` macro's expanded `async throws` function with `isolated (any Actor)?` parameter
- **Reported Upstream**: swiftlang/swift#91639
- **Workaround**: Use a single test walking a list instead of `@Test(arguments:)` cases

---

## Investigation Findings

### 1. State of `@Test(arguments:)` at Time of #345 (Commit `b66f4df6`, July 22, 2026)

| Test File | Argument Type | Risk for #1057 Defect |
|-----------|---------------|----------------------|
| `Issue181RobustnessTests.swift` | `[Double]` | ❌ No — simple scalars |
| `Issue185HelicalSweepTests.swift` | `[Bool]` | ❌ No — simple scalars |
| `Issue187ScrewThreadTests.swift` | `[(Double, Double)]` | ❌ No — tuple of scalars |
| `Issue189ThreadGuardTests.swift` | `[(Double, Double)]` | ❌ No — tuple of scalars |
| `Issue193LongThreadTests.swift` | `[Double]` | ❌ No — simple scalars |
| `ThreadFormsTests.swift` | `[ThreadForm]` (enum) | ❌ No — enum values |

**None** of the `@Test(arguments:)` sites at that time used the problematic pattern of mixing a reference-counted member with a ≥32-byte SIMD vector.

### 2. When Was the Problematic Pattern Introduced?

The `Issue990ThreadAxisBasisTests.swift` file (commit `dc71b028`, fix for #990) introduced:
```swift
static let axes: [(String, SIMD3<Double>, SIMD3<Double>)] = [...]
```
This `(String, SIMD3<Double>, SIMD3<Double>)` tuple **exactly matches** the #1057 defect trigger (Case P/K in #1057's table).

However, this file was created **after** #345 was closed. The original comment in that file even misattributed the crash to OCCT and linked it to #344/#345 — which #1057 later corrected.

### 3. Signal 6 (SIGABRT) Can Have Multiple Causes

| Cause | Mechanism | Signal |
|-------|-----------|--------|
| Unguarded `gp_Dir` construction | Uncaught `Standard_ConstructionError` → `std::terminate()` | SIGABRT (6) |
| Toolchain defect (#1057) | Swift task allocator corruption → `abort()` | SIGABRT (6) |
| Other `std::terminate()` paths | Any uncaught C++ exception across noexcept boundary | SIGABRT (6) |

Both causes produce signal 6, but they are **distinct mechanisms**.

### 4. The #345 Fix Addressed a Real, Reproducible Defect

The audit that led to the #345 fix found **49 bridge functions** across 7 files that constructed `gp_Dir`/`Geom_Direction` from caller-supplied doubles with **no try/catch anywhere in the call chain**. Examples:
- `OCCTSurfaceD1` / `OCCTSurfaceD2` — no try/catch
- `OCCTSurfaceGetNormal` (two lines below) — already had try/catch

This inconsistency confirmed the defect was real and not imagined. The fix was validated with 70 clean runs.

### 5. Could the Toolchain Defect Have Triggered Anyway?

For the #1057 toolchain defect to trigger, a test must use `@Test(arguments:)` with the problematic tuple type. At the time of #345:
- No such test existed in the codebase
- The crash occurred in "full parallel `swift test` runs" across all test targets
- The toolchain defect only manifests when the specific `@Test(arguments:)` is **executed**, not merely present

Since no test with the problematic signature existed, the toolchain defect **could not have been the cause** of the #345 crashes.

---

## Why the Confusion Arose

1. **Same signal number** (6 = SIGABRT) for two different mechanisms
2. **No diagnostic trail** in either case — both leave minimal evidence
3. **OCCT's process-wide signal handler** reports any SIGSEGV/SIGABRT, making OCCT appear culpable even when it isn't
4. **#345 had "essentially no localizing evidence"** — just the harness message
5. **#1057's Case P** prints `freed pointer was not the last allocation` before dying, which looks like a memory corruption but is actually the Swift task allocator's own check

---

## Recommendation

**Do not reopen #345.** The fix was correct, the root cause was real and independently verified, and the validation (70 clean runs) is strong evidence. The toolchain defect (#1057) is a separate issue that affects a specific test pattern not present at the time.

**Action Items:**
1. ✅ Document this investigation (this file)
2. ✅ Keep #345 closed with its current resolution
3. ✅ Ensure new `@Test(arguments:)` sites are checked by `census-arguments-tuple-shapes.py` (already in CI via `--self-test`)
4. ⚠️ If a future SIGABRT occurs with "no test name, no backtrace" in a run that **does** exercise at-risk `@Test(arguments:)` sites, investigate both causes

---

## Related Issues/PRs

- #345 — Original SIGABRT issue (closed by PR #351)
- #344 — Companion SIGSEGV issue (fixed by kernel patches)
- #1057 — Toolchain defect in `@Test(arguments:)` (closed by PR #1080)
- PR #1080 — Corrected `Issue990ThreadAxisBasisTests` comment, added census script
- `Scripts/census-arguments-tuple-shapes.py` — Census script to detect at-risk `@Test(arguments:)` sites
- `Scripts/repro/1057-tuple-arguments-crash/` — Standalone reproducer for the toolchain defect

---

*Investigation completed: 2026-08-26*
