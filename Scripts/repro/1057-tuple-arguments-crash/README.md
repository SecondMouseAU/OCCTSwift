# #1057: `@Test(arguments:)` over a mixed tuple corrupts the Swift task allocator

`Tests/OCCTThreadTests/Issue990ThreadAxisBasisTests.swift` used to carry a comment attributing a
SIGSEGV to OCCT and linking it to #344/#345. It is not OCCT. It is a toolchain defect, it needs no
OCCT, no bridge and no `OCCT.xcframework`, and it reproduces in a package with nothing in it.

Everything here is measured on **Swift 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)**, Xcode 26.6
(17F113), macOS 26.6.1 (25G76), arm64, Testing library version **1902**. No other toolchain was
available on this machine, so nothing below is a claim about any other one.

## What to run

```bash
./run-grid.sh 3        # the swift-testing grid, 23 cells, 3 processes each
./run-stages.sh        # the same crash reached with no swift-testing, 22 stages
./run-variants.sh      # the narrowing, 64 one-change-at-a-time variants
./backtrace.sh A1StringSIMD3   # the crash frame
./dump-expansion.sh    # the @Test macro expansions the compiler is handed

swiftc upstream-repro.swift -o /tmp/r && /tmp/r   # the smallest form, on its own

# from the repo root: every `arguments:` site under Tests/, and which of them are at risk
python3 Scripts/repro/1057-tuple-arguments-crash/census-arguments-sites.py
python3 Scripts/repro/1057-tuple-arguments-crash/census-arguments-sites.py --self-test
```

`standalone/` is a self-contained SwiftPM package. It does **not** depend on OCCTSwift and is not
part of the outer package's build graph.

Each cell, stage and variant runs in its own process, because the crash is fatal and a single run
would report only the first one to die.

## Stage 1: the swift-testing grid

`standalone/Tests/TupleGridTests/TupleGridTests.swift`, one `@Suite` per cell, every body trivial.
3/3 processes each.

| cell | `arguments:` element type | verdict |
|---|---|---|
| A | `(String, SIMD3<Double>)` | **CRASH** |
| B | `(String, SIMD3<Double>, SIMD3<Double>)` | **CRASH** |
| C | `(SIMD3<Double>, SIMD3<Double>)` | clean |
| D | `(String, Int)` | clean |
| E | `SIMD3<Double>` bare | clean |
| F | `String` bare | clean |
| G | `(SIMD3<Double>, String)` | **CRASH** |
| H | `(Ref, SIMD3<Double>)`, a final class | **CRASH** |
| I | `([Int], SIMD3<Double>)` | **CRASH** |
| J | `(String, SIMD2<Double>)`, 16 bytes | clean |
| K | `(String, SIMD4<Double>)`, 32 bytes | **CRASH** |
| L | `(String, SIMD4<Float>)`, 16 bytes | clean |
| M | `(String, SIMD8<Float>)`, 32 bytes | **CRASH** |
| N | `(String, Size32Align16)`, 32 bytes of 16-byte vectors | clean |
| O | `(String, Vector32Wrapper)`, a struct wrapping `SIMD3<Double>` | **CRASH** |
| P | `(String, Double)` | clean |
| Q | `NamedPair`, a struct with the same two members as A | **CRASH** |
| R | A's type with exactly one case | **CRASH** |
| S | two-sequence `arguments: [String], [SIMD3<Double>]` | clean |
| T | A's type with `.serialized` | **CRASH** |
| U | one test walking the list, no `arguments:` | clean |
| V | A's type with a body that is `{}`, argument never read | **CRASH** |

Four things this settles that the issue's own table did not.

**It is not about SIMD alignment.** The issue said `SIMD3<Double>` is 32-byte aligned. Measured, it
is not: `size=32 stride=32 align=16`, and 16 is the runtime's `MaxAlignment`. `@_alignment(32)` is
rejected outright with "cannot increase alignment above maximum alignment of 16", so no Swift value
is over-aligned in that sense. Cell N is the control that matters: a struct of two `SIMD2<Double>`
has the identical `size=32 stride=32 align=16` layout and is clean. Cells K, M and O are 32-byte
**builtin vectors** and crash, so what discriminates is whether a 32-byte vector is in the layout,
not the size and not the alignment.

**It is not `String`.** Cells H and I swap it for a class and an `Array` and both crash, so any
reference-counted member does it.

**It is not the tuple.** Cell Q is a nominal struct with the same two stored properties and crashes.
Cell S, which keeps the same two types but as two separate parameters, is clean. So the trigger is
one aggregate containing both, whether it is spelled as a tuple or as a struct.

**It is not concurrency between cases.** Cell R is a single case and cell T is `.serialized`, and
both crash.

**It is not the body.** Cell V's body is `{}` and never reads the argument. This directory asserted
"whatever the body does" for a round while every cell still carried a `precondition` or an
`#expect`, which a pre-PR review flagged as an unevidenced claim made in the place it mattered
most. Cell V is that evidence.

## Stage 2: the crash frame

`./backtrace.sh A1StringSIMD3`:

```
2 swift::swift_Concurrency_fatalErrorv(...) in libswift_Concurrency.dylib
5 swift_task_dealloc + 124 in libswift_Concurrency.dylib
6 implicit closure #1 in static A1StringSIMD3.$s...generator...fMu_@Sendable ()
    in TupleGridPackageTests at .../@__swiftmacro_...A1StringSIMD3V3run4TestfMp_.swift
7 partial apply for implicit closure #1 in ... in TupleGridPackageTests
8 closure #1 in closure #2 in Test.Case.Generator.init<A, B>(sequence:parameters:testFunction:) in Testing
```

`freed pointer was not the last allocation` is the Swift task allocator's own stack-discipline
check, printed by `libswift_Concurrency`. The failing frame is in **the test module**, in
compiler-generated code inside the `@Test` macro expansion, not in any `Testing` frame. Testing is
frame 8, the caller.

The runs that reach OCCT's installed signal handler print `*** Abort *** ... SIGSEGV 'segmentation
violation' detected. Address 5928` instead, which is what led the original investigation to read it
as an OCCT fault: OCCT installs its handler process-wide and reports any SIGSEGV, whoever raised
it.

Both messages are the same corruption. Which one a run produces depends on the program, not on the
element type: cells H and I print `freed pointer was not the last allocation` like every other
crashing cell, while the same two element types in `Smallest` (V43, V44) take a bare SIGSEGV and
exit 139 with nothing printed. A draft of this paragraph attributed the 139 to cells H and I, which
is the wrong half of the measurement and was caught in review.

## What the macro hands the compiler

`./dump-expansion.sh` writes every `@Test` expansion to `macro-expansions.txt` (not committed: it
is 7,500 lines of this worktree's absolute paths). The one the argument turns on, for cell A:

```swift
@Sendable private static func $s...Z4c8319d65343190cfMu_(_ arg0: (String, SIMD3<Double>)) async throws -> Void {
  @Sendable func $s..._7__localfMu0_(
    _ arg0: (String, SIMD3<Double>),
    _: isolated (any _Concurrency.Actor)? = Testing.__defaultSynchronousIsolationContext
  ) async throws {
    let $s..._7__localfMu_ = unsafe try await Testing.__requiringUnsafe(...(A1StringSIMD3()))
    _ = unsafe try await Testing.__requiringUnsafe(...($s..._7__localfMu_.run(arg0)))
  }
  try await $s..._7__localfMu0_(arg0)
}
```

A nested `async throws` function with an `isolated (any Actor)?` parameter, taking the tuple. That
is the whole shape, and stage 4 shows nothing else about it is needed.

## Stage 3: the same crash with no swift-testing

`standalone/Sources/MinimalRepro`, run by `./run-stages.sh`. It imports no Testing.

| stage | shape | verdict |
|---|---|---|
| 1 | direct `await` on the crashing tuple | clean |
| 2 | through a concrete function value | clean |
| 3 | through a generic higher-order function, serially | clean |
| 4 | the same in a task group | clean |
| 5 | the same, control tuple | clean |
| 6-8 | tuple expanded into a parameter pack | clean |
| 9-11 | parameter pack across a resilient module boundary | clean |
| 12-14 | `@Sendable ((E1, E2)) async throws -> Void` over generic elements, the shape `Test.__function` actually declares | clean |
| **15** | **the full macro-expansion shape, crashing tuple** | **CRASH** |
| 16 | the same, control tuple | clean |
| 17 | stage 15 minus the `isolated` parameter | clean |
| 18 | stage 15 minus the `@autoclosure` helpers | **CRASH** |
| 19 | nested func with an `isolated` parameter, through the driver | **CRASH** |
| 20 | the same, control tuple | clean |
| 21 | nested func with an `isolated` parameter, called directly | **CRASH** |
| 22 | the same, control tuple | clean |

Stages 12 to 14 are worth keeping even though they are clean: the `Test.__function<C, E1, E2>`
signature was read out of `Testing.framework`'s own `arm64-apple-macos.swiftinterface`, not
remembered, and reproducing it faithfully still did not crash. What did was the *body* the macro
writes, not the *signature* it calls.

## Stage 4: the narrowing

`standalone/Sources/Smallest`, run by `./run-variants.sh`. It imports nothing at all: no Testing,
no Foundation, no `simd` module. `SIMD3<Double>` is a standard-library type.

The smallest crashing program:

```swift
@globalActor actor Iso { static let shared = Iso() }

func outer(_ a: (String, SIMD3<Double>)) async throws {
    func local(_ a: (String, SIMD3<Double>), _: isolated (any Actor)? = Iso.shared) async throws {
        precondition(!a.0.isEmpty)
    }
    try await local(a)
}

try await outer(("+X", SIMD3(1, 0, 0)))
```

Three conditions, each proved necessary by a variant that removes exactly one of them.

**A local `async throws` function nested inside an `async throws` function.** V15 with no `throws`
anywhere is clean; V28 with `throws` on the local function only is clean; V29 with `throws` on the
outer function only is clean; V36 with the same local function hoisted to the top level is clean.

**An `isolated (any Actor)?` parameter on the local function, whose argument the compiler cannot
fold.** V30 without the parameter is clean. V50, passing a literal `nil`, is clean. V49, passing an
opaque `nil` through an `@inline(never)` function, **crashes**. So the actor's runtime value is
irrelevant and its visibility to the compiler is what matters. That distinction is not academic
here: `Testing.__defaultSynchronousIsolationContext`, which is what the `@Test` macro writes as the
default, is a non-inlinable computed property, and printing it from inside the grid gives **`nil`**.
An earlier draft of this file said a non-nil actor was required, on the strength of V39's literal
`nil` being clean. That was the wrong reading of the same measurement.

**One parameter is an aggregate holding both a reference-counted member and a builtin vector of 32
bytes or more.** Both halves are necessary. V27 with an all-POD tuple is clean; V35 with the vector
alone is clean; V34 with the two members as separate parameters is clean; V31 (`SIMD2<Double>`, 16
bytes) and V42 (`SIMD4<Float>`, 16 bytes) are clean; V32 (a 32-byte struct built from two 16-byte
vectors) is clean; V51 (`(String, Int)`) and V52 (`(String, Double)`) are clean. V33 (a nominal
struct), V40 (`SIMD4<Double>`), V41 (`SIMD8<Float>`), V45 (members swapped), V46 (`SIMD16<Float>`,
64 bytes), V47 (a three-element tuple), V56 (a nested tuple of two vectors) and V57
(`SIMD4<Int64>`, an integer vector) all crash. V43 (a class) and V44 (an `Array`) crash as a bare
SIGSEGV rather than reaching the allocator's check.

V51 and V52 exist because the grid's own `(String, Int)` and `(String, Double)` cells were measured
under the swift-testing shape rather than this one, and a table that silently mixes two shapes is
a table nobody can check. V57 exists because the census script's first regex only knew `Double` and
`Float` element types, and a pre-PR review measured an integer vector crashing.

`@Sendable` on the local function is not part of it: V37 without it crashes.

### The pair is necessary and not sufficient, and the rest is not characterised

The same review measured `(String, simd_double3x3)` clean, which the rule as first written says
should crash. Reproduced here without importing `simd`, and pushed further:

| parameter type | `MemoryLayout.size` | 32-byte vectors in it | verdict |
|---|---|---|---|
| `(String, SIMD3<Double>)` | 48 | 1 | **crash** |
| `(String, SIMD4<Int64>)` | 48 | 1 | **crash** |
| `(String, Vec1)`, a struct of one vector | 48 | 1 | **crash** |
| `(String, Size32Align16)` | 48 | 0 | clean |
| `(String, SIMD2<Double>)` | 32 | 0 | clean |
| `(String, SIMD16<Float>)` | 80 | 1 (64-byte) | **crash** |
| `(String, SIMD3<Double>, SIMD3<Double>)` | 80 | 2 | **crash** |
| `(String, Vec2)`, a struct of two vectors | 80 | 2 | **crash** |
| `(String, One80)`, one vector plus four `Double`s | 80 | 1 | clean |
| `(String, Pad1)`, two vectors plus one `Double` | 88 | 2 | clean |
| `(String, One96)`, one vector plus five `Double`s | 88 | 1 | clean |
| `(String, Vec3)`, a struct of three vectors, the `simd_double3x3` shape | 112 | 3 | clean |
| `(SIMD3<Double>, SIMD3<Double>)` | 64 | 2 | clean |

Size alone does not explain it: 80 bytes crashes with two vectors (`Vec2`) and is clean with one
plus padding (`One80`). Vector count alone does not explain it: one vector crashes at 48 and is
clean at 80. A compound rule can be fitted to these thirteen rows, and fitting one is exactly what
[`measure-dont-assume`](../../../okf/policies/measure-dont-assume.md)'s "an argument that explains
everything may be describing a defect" section says not to do. So this file states the table and
stops: **the pair is necessary, the exact cut is unknown, and somebody with the IR should be the
one to explain it.** `census-arguments-sites.py` flags on the pair alone and therefore
over-predicts, which is the direction a census should err in.

`ShapeProperties.momentOfInertia` returns a `simd_double3x3`, so this edge is reachable from real
public API here rather than being a curiosity: a parameterised test over
`(String, simd_double3x3)` is clean today.

## Debug only

`swift test -c release --filter A1StringSIMD3` passes, and `Smallest` built with `-c release` runs
every variant clean. The defect is `-Onone` only, which is what `swift build` and `swift test`
produce by default and therefore what everybody actually runs.

## Prior art checked

Searched `swiftlang/swift` and `swiftlang/swift-testing` for the fatal message and for the
combination of an `isolated` parameter with the task allocator. The near neighbours are
swiftlang/swift [#75501](https://github.com/swiftlang/swift/issues/75501),
[#84793](https://github.com/swiftlang/swift/issues/84793),
[#86204](https://github.com/swiftlang/swift/issues/86204),
[#88794](https://github.com/swiftlang/swift/issues/88794) and
[#88750](https://github.com/swiftlang/swift/issues/88750), all reached through `async let`,
continuations, `Task.sleep` specialisations or cross-module linking rather than through this shape,
and swiftlang/swift-testing [#1027](https://github.com/swiftlang/swift-testing/issues/1027), which
is a duplicate-argument crash and a different trigger.
swiftlang/swift [#88993](https://github.com/swiftlang/swift/issues/88993) is about an `isolated`
parameter but reports the wrong isolation on resume rather than memory corruption, and is closed.
None of them is this.

## Reported

[swiftlang/swift#91639](https://github.com/swiftlang/swift/issues/91639), filed 2026-08-21 against
Swift 6.3.3, carrying `upstream-repro.swift` inline and the table above. Filed there rather than
against swift-testing because the reproducer has no swift-testing in it and the failing frame is in
the test module's own compiler-generated code, with `Testing` as the caller.

## What it means for this repo

A `@Test(arguments:)` here cannot take an element type that pairs a reference-counted member with a
`SIMD3<Double>`, `SIMD4<Double>` or any wider vector, in a tuple or in a struct. Walking the list
inside one test, which is what `Issue990ThreadAxisBasisTests` does, is the workaround, and cell U
confirms it is clean.

Census by `census-arguments-sites.py`, over all of `Tests/`: **33** `@Test(..., arguments:)` sites,
**0 at risk**, 1 needing a human to open the named type. It is a census and not a gate, for two
reasons: an `arguments:` value that is a named collection carries no type at all, and the flagging
rule over-predicts (see the table above).

Its `--self-test` is 22 cases, 16 over `classify()` and 6 building real fixture files and running
`sites()` over them. Removal matrix, on throwaway copies, each clause neutered on its own:

| clause removed | self-test result |
|---|---|
| the wide-vector test | 9 of 22 fail |
| the reference-counted test | 9 of 22 fail |
| the SIMD element-width table | 8 of 22 fail |
| the doc-comment skip | 2 of 22 fail |
| the string-literal mask | 2 of 22 fail |
| the bare-identifier verdict | 2 of 22 fail |
| the paren scan starting inside the `@Test(` call | 1 of 22 fails |

The mask's first fixture proved nothing: it put `arguments:` in a display name on a line that also
had a real `arguments:`, so the row count was 1 either way. Replaced with a line whose only
`arguments:` is inside the string, plus one where the display name's `arguments:` comes first and
would otherwise become the start of the captured type. Neutering the doc-comment skip takes the
total from 33 to 38 at HEAD, because the corrected comment in `Issue990ThreadAxisBasisTests` names
`arguments:` five times, and one of those five phantom rows reads **AT RISK**, since the same
paragraph names `SIMD3<Double>`, `String` and `Array` while explaining the rule.

Three of the 33 rows needed a human:

- `Tests/OCCTBRepGraphTests/Issue881PerpendicularBasisTests.swift:76` is the only SIMD-tuple site,
  element `(SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)`, no reference-counted member, matching
  clean cell C.
- `Tests/OCCTThreadTests/Issue991ThreadProfileFlatWidthTests.swift:20` has element
  `(String, ThreadProfile, Double, Double)`, so it does pair a `String` with a struct.
  `ThreadProfile`'s only stored property is `[Vertex]`, so the aggregate holds no vector and
  nothing wider than a word.
- `Tests/OCCTThreadTests/ThreadFormsTests.swift:17` is the `unknown` row: `arguments:
  ThreadFormsTests.smoothForms` names a collection rather than writing a type, so the script
  reports that it cannot decide instead of printing `clean` in the same column as the rows it
  actually inspected. `ThreadForm` is an enum with a `String` raw value and no payload, which is a
  tag byte, so the row is clean.

**At-risk sites: 0.** Nothing was changed for its own sake.

### Nothing runs this census

`ci.yml`'s `gate-scripts` job invokes `Scripts/*.py`, and `Scripts/git-hooks/pre-commit` mirrors it,
so a script under `Scripts/repro/` is run by nobody. The repo's precedent for a non-gating census is
that CI still runs its `--self-test`, because a bare run of a census can never fail and so can never
signal. Promoting this one means four coordinated edits: move it to
`Scripts/census-arguments-tuple-shapes.py`, add its `--self-test` to `ci.yml`, add the same
invocation to the pre-commit hook, and extend `CLAUDE.md`'s "Static Gate Scripts" list and its
"two censuses" count to three.

It is deliberately not done in the PR that created this directory, because the fourth edit is to
`CLAUDE.md` and the agent that wrote this is not permitted to change that file. Left as one
follow-on decision rather than three-quarters of a change, so the list and the reality do not
disagree silently, which is the failure `CLAUDE.md`'s own release section spends a paragraph on.

## Deliberately not answered here

#1057 closes with an unverified note: #345 was closed on a bare `exited with unexpected signal code
6` with no test name and no backtrace, and signal 6 is what this defect produces. Nothing in this
directory tests that connection, and the tree at #345's time is not the tree measured here. Tracked
as #1072 rather than left in a closed issue's last paragraph; `census-arguments-sites.py --root` is
what that check would use.
