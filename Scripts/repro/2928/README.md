# #2928: what the wasm test exclusions were actually avoiding

#2793 built the wasm test path and excluded five whole test targets and sixteen files; #2997
removed seven of those file exclusions and one target when it changed the runtime, because they
were `wasmkit` and not the port. This directory holds the measurements behind the rest.

Four questions, four answers, and three of the four reasons recorded in `Package.swift` turned out
not to be true of the platform.

## 1. Is `Int(Int32.max) + 1` a compile error on wasm32, or a run-time trap?

**A run-time trap.** `Int` is 32 bits on `wasm32-unknown-wasip1`, so the value is not
representable, but nothing diagnoses it: `swiftc -target wasm32-unknown-wasip1 -emit-sil` accepts
every one of five spellings, including the one inside an array literal and the one in a
`static let`. `overflow-probe.swift` and `run-overflow.sh` are the measurement.

```
===== CASE1 (wasm32, Int is 32 bits)      func f() -> Int { Int(Int32.max) + 1 }      compiles
===== CASE2 (wasm32, Int is 32 bits)      static let in a struct                      compiles
===== CASE3 (wasm32, Int is 32 bits)      inside an [Int] literal                     compiles
===== CASE4 (wasm32, Int is 32 bits)      not constant-foldable                       compiles
===== CASE5 (wasm32, Int is 32 bits)      addingReportingOverflow                     compiles
```

That matters because it decides the shape of the fix. A compile error would have to be removed from
the source; a run-time trap can be left in place and not reached. It also says why the files were
EXCLUDED rather than listed as failures: a trap ends the module, so every test after it in that
suite is unreported, which `Scripts/run-wasm-tests.sh` treats as a hard failure no known-failure
list can excuse.

## 2. Does `.enabled(if:)` suppress evaluation of a `@Test(arguments:)` list?

See `trait-evaluation-probe.swift` (the three sites behind a FALSE condition) and
`trait-evaluation-control.swift` (the same three behind a TRUE one, which must trap on wasm32 or
the probe proves nothing). The result is in `trait-measurement.md`.

## 3. Which primitives named in the whole-target exclusions actually fail to compile?

`prims.swift` and `run-prims.sh`, one `-D` per primitive so one failure cannot mask another:

```
COMPILES  NSLock                FAILS  DispatchQueue
COMPILES  ProcessInfo           FAILS  DispatchGroup
COMPILES  withTaskGroup         FAILS  DispatchSemaphore
COMPILES  Thread                FAILS  autoreleasepool
```

`Package.swift` gave `NSLock` as the reason `OCCTIOTests` could not exist on wasm, 46 files for one
type, and `ProcessInfo` as half the reason for `OCCTStressTests` and `OCCTFoundationTests`. Both
compile. The wasm SDK ships the full `swift-corelibs-foundation`, not only
`FoundationEssentials`: `Sources/OCCTPlatform/PlatformLock.swift` avoids `NSLock` because the
LIBRARY cannot afford full Foundation's 10 MB of internationalisation data (#2761), which is a
module-size constraint on the shipped product and not an availability one. A test target has no
size budget.

## 4. Is `OCCTThreadTests` a suite about concurrency?

**No. It is a suite about screw threads.** `Package.swift` read "28 files whose subject is
concurrency", and six of the 28 are: `Issue298FilletThreadSafetyTests`,
`Issue341MeshCafThreadSafetyTests`, `Issue359STEPThreadSafetyTests`,
`Issue361SharedSingletonThreadSafetyTests`, `Issue367FuseMultiThreadSafetyTests` and
`Issue1404TObjApplicationThreadSafetyTests`. The other 22 are M8 fasteners, thread forms, thread
designation parsing, helical sweeps and V-profiles, and not one of them mentions a lock, a queue, a
semaphore or a task group:

```
grep -ln 'Dispatch\|autoreleasepool\|NSLock\|withTaskGroup\|Thread\.' Tests/OCCTThreadTests/*.swift
```

returns the six. This is the cheapest finding in the issue and the one that was hardest to see,
because the target's name is correct for its contents and wrong for the reason it was excluded.
