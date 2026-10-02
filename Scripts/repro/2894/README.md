# #2894: the uncatchable OCCT exception is about the unwind path, not the exception

An OCCT exception that the bridge catches on Apple reaches `std::terminate` on
`wasm32-unknown-wasip1`, ending the module. This directory holds the probe that localised it.

**Result: it is the runtime.** The same exception is caught one frame below the bridge's
`catch (...)` and uncaught several frames down **under `wasmkit` 0.3.1**, and caught at both depths
under Node with the browser's WASI shim, from the same module file byte for byte. So the exception's
type, its RTTI and `Geom_TrimmedCurve.cxx`'s code generation are all fine, LLVM's output is fine, and
`wasmkit` does not unwind a C++ exception through several frames.

**The depth experiment below is what made that findable**, so it is kept rather than replaced: it
narrowed the question from "why is an OCCT exception uncatchable" to "why is it uncatchable only at
depth", which is the shape that made changing the runtime an obvious thing to try. The order in which
I tried things was not: flags, EH model, setjmp and the exception's class all came first, and the
runtime came fifth. It should have been first, and this directory's own earlier note that `wasmkit`
interprets where a browser compiles was already the reason why.

## Running it

`depth-probe.swift` needs `@testable import OCCTSwift`, so it runs as a test file rather than as an
executable. Drop it into a test target that builds for wasm, for example `Tests/OCCTMathTests/`, then:

```
Scripts/fetch-occt-wasm.sh
./Scripts/run-wasm-tests.sh build
wasmkit run --dir /tmp/occt-wasm-tests --dir /tmp --env TMPDIR=/tmp/occt-wasm-tests \
  .build/out/Products/Release-webassembly-wasm32/OCCTMathTests-test-runner.wasm \
  --testing-library swift-testing --no-parallel --filter ZZProbe2894Depth
```

It is not committed as a test because it asserts nothing: it prints, and a `std::terminate` ends the
module, so the ORDER of the cases is what carries the information.

## The three cases and what each is for

| | call | exception | depth below the bridge's `try` |
|---|---|---|---|
| A | `Shape.box(0, 0, 0)` | `Standard_DomainError` | shallow |
| B | `Curve3D.trimmed(from: 1, to: 1)` | `Standard_ConstructionError`, `Geom_TrimmedCurve::U1 == U2` | **one frame**: the bridge does `new Geom_TrimmedCurve(...)` inside its own `try` |
| C | `Shape.evolved(spine:profile:)` | **the same exception, same message** | several frames, through `BRepFill_Evolved::Perform` → `PrivatePerform` → `PrepareProfile` |

B is the experiment. A only shows that *some* OCCT throw is catchable; it cannot separate the
exception's class from the unwind, because it is a different exception from a different translation
unit. B and C differ in exactly one variable.

## Apple, all three caught

```
DEPTH-A box(0,0,0) -> nil records=1 ["Standard_DomainError"]
DEPTH-B trimmed -> nil records=1 ["Standard_ConstructionError"]
DEPTH-B record: OCCTCurve3DTrim: Standard_ConstructionError: Geom_TrimmedCurve::U1 == U2
DEPTH-C evolved -> nil records=1 ["Standard_ConstructionError"]
```

Note what C does on Apple: `Shape.evolved` with these inputs **does not succeed** there either. It
throws and the bridge catches it, so the test that exposed #2894 passes on Apple because the catch
works, not because the operation works.

## wasmkit: B caught, C terminates

```
DEPTH-A box(0,0,0) -> nil records=1 ["Standard_DomainError"]
DEPTH-B trimmed -> nil records=1 ["Standard_ConstructionError"]
DEPTH-B record: OCCTCurve3DTrim: Standard_ConstructionError: Geom_TrimmedCurve::U1 == U2
DEPTH-C ATTEMPTING evolved; no following line means it escaped
Error: Trap: unreachable
    1: std::__terminate(void (*)())
    2: std::terminate()
    3: BRepFill_Evolved::PrepareProfile(...)
    4: BRepFill_Evolved::PrivatePerform(...)
    5: BRepFill_Evolved::Perform(...)
```

## Four explanations eliminated by measurement

- **Missing exception flags on a toolkit.** `BRepFill_Evolved.cxx.obj` carries 2,693 `try_table`,
  1,625 `catch_all` and 568 `throw_ref`; `Standard_Failure.cxx.obj` and `Geom_TrimmedCurve.cxx.obj`
  the same shape plus `__cxa_throw`. Every object inspected uses the modern EH encoding, none the
  legacy one.
- **A mismatched EH model between OCCT and the bridge.** The bridge object holding
  `OCCTBRepFillEvolved` has 628 `try_table`, 80 TYPED `catch` clauses, and
  `__cxa_begin_catch`/`__cxa_end_catch`, so it has real handlers in the same encoding.
- **#2757's setjmp interaction.** No `setjmp`/`longjmp` in either object, and the OCCT source has no
  `OCC_CATCH_SIGNALS` or `Standard_ErrorHandler` in that file.
- **The module being unable to catch OCCT exceptions.** Case A and case B both catch, in the same
  module as C.

## Where it fails, and what is still open

`std::terminate` is called in **`PrepareProfile`'s own frame**, not deeper, so unwinding travelled up
from `Geom_TrimmedCurve` and stopped there. The compiler emits a `std::terminate` call on a frame's
cleanup path, and `_ZSt9terminatev` is an undefined symbol in that object. That leaves the two
textbook causes: a destructor throwing while unwinding, or a `noexcept` callee inlined into the frame.
`PrepareProfile` holds two `occ::handle`s, an `NCollection_DataMap`, two `NCollection_List`s and a
`BRepTools_WireExplorer`, all of which must be destroyed on the unwind.

**That question is now moot**, because the answer is that neither reading was right: nothing about
OCCT's frames or their destructors is at fault, and the unwind works under a conforming runtime. It is
recorded because the reasoning was the right shape even though the conclusion was aimed at the wrong
component. Four other candidate operations were tried as controls and none of them throws at all on Apple
(`Shape.loft` solid from two sections, `Shape.offset(by:)` at -1e9, `Shape.pipeSweep` on a degenerate
spine, and #430's `GeomAbs_G2` filling on a planar support, which succeeded rather than raising), so
no second deep throw was found by hand.

The argument from the existing corpus points at "specific" without settling it: 11 of the 12 wasm
suites pass entirely, 5,501 tests, and the known-failure list is 16 entries. If unwinding through
OCCT frames were broken in general, far more than three files would trap. That is an argument from
absence and is not a measurement.

## The runtime measurement

`Scripts/repro/2175/spike` carries cases `unwind-depth-1` and `unwind-depth-n`, which are cases B and
C above, because the spike is the only module in this repository that runs under both `wasmkit` and
Node. Build it, then:

```
# wasmkit
wasmkit run --dir "$work" --dir /tmp <spike>.wasm "$work"

# Node, same bytes
SPIKE_MODULE=<spike>.wasm Scripts/repro/2052/run.sh all
```

Node:

```
case unwind-depth-1  PASS  Curve3D.trimmed(1,1) -> nil, records=1 [Standard_ConstructionError: Geom_TrimmedCurve::U1 == U2]
case unwind-depth-n  PASS  Shape.evolved -> nil, records=1 [Standard_ConstructionError: Geom_TrimmedCurve::U1 == U2]
failures: 0
exit=0 trap=none
VERDICT: PASS
```

`wasmkit`, same bytes: `unwind-depth-n` reaches `std::terminate` through
`BRepFill_Evolved::PrepareProfile` and the module ends.

### What that invalidated

Three issues and a pile of exclusions, all measured only under `wasmkit`:

| | was filed as | under Node |
|---|---|---|
| #2894 | an OCCT exception reaching `std::terminate` | passes |
| #2895 | an out-of-bounds free in a destructor, two sites | passes |
| #2897 | an indirect call typed `(i32)` where the site expects `(i32, i32, i32)` | passes |

`OCCTIntegrationTests` came back as a whole target, and six more files with it, plus
`GCPntsSamplerBoundsTests` whose 422-second test is 27.8 s here. The suites went from 12 targets and
5,501 tests to 13 and 5,553, and the run from about seven minutes to 224 s.

**#2897 is the one worth dwelling on.** I had written that wasm's typed `call_indirect` was a checker
we do not otherwise have, and that the trap might therefore be evidence of a latent ABI problem on
Apple. It was the interpreter's own handling. The speculation was wrong and the reasoning that
produced it was the appealing kind.

## What would still need a kernel build

Pinning the frame means instrumenting or bisecting `PrepareProfile`'s locals, or compiling that one
translation unit at `-O0` to see whether inlining is what puts the terminate there. Both need OCCT
rebuilt, which is 69 minutes, so they belong with the next rebuild rather than on their own.
