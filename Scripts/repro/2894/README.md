# #2894: the uncatchable OCCT exception is about the unwind path, not the exception

An OCCT exception that the bridge catches on Apple reaches `std::terminate` on
`wasm32-unknown-wasip1`, ending the module. This directory holds the probe that localised it.

**Result: the same exception, from the same OCCT class, with the same message, is CAUGHT one frame
below the bridge's `catch (...)` and UNCAUGHT several frames down.** So the exception's type, its
RTTI and `Geom_TrimmedCurve.cxx`'s code generation are all fine, and what fails is unwinding through
the intervening frames.

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

## wasm: B caught, C terminates

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

**Whether this is general to deep throws or specific to these frames is NOT established.** Four other
candidate operations were tried as controls and none of them throws at all on Apple
(`Shape.loft` solid from two sections, `Shape.offset(by:)` at -1e9, `Shape.pipeSweep` on a degenerate
spine, and #430's `GeomAbs_G2` filling on a planar support, which succeeded rather than raising), so
no second deep throw was found by hand.

The argument from the existing corpus points at "specific" without settling it: 11 of the 12 wasm
suites pass entirely, 5,501 tests, and the known-failure list is 16 entries. If unwinding through
OCCT frames were broken in general, far more than three files would trap. That is an argument from
absence and is not a measurement.

## What needs the kernel build

Pinning the frame means instrumenting or bisecting `PrepareProfile`'s locals, or compiling that one
translation unit at `-O0` to see whether inlining is what puts the terminate there. Both need OCCT
rebuilt, which is 69 minutes, so they belong with the next rebuild rather than on their own.
