# 2894: which throws the wasm exception seam carries, and which one it does not

`BRepFill_Evolved::PrepareProfile` reaches `std::terminate` on `wasm32-unknown-wasip1` where the
bridge's `catch (...)` should have run. Two suites trap on it, the rest of the wasm suite does not,
and #2171 had already shown that exceptions work across the OCCT/bridge seam. **What distinguishes
the two was the question**, and the answer is one flag.

## The one-line answer

**Nothing distinguishes the throws. The difference is the optimisation level of the frame being
unwound through.** The same OCCT translation unit, the same source, the same exception flags:

| `BRepFill_Evolved.cxx` compiled | case B |
|---|---|
| `-O0` | `CAUGHT Standard_ConstructionError: Geom_TrimmedCurve::U1 == U2` |
| `-O1` | `std::terminate` |
| `-O2` | `std::terminate` |
| `-O2 -fno-inline` | `CAUGHT Standard_ConstructionError: Geom_TrimmedCurve::U1 == U2` |
| `-O2 -mllvm -inline-threshold=0` | `Trap: out of bounds memory access` in `~NCollection_Sequence<double>` |
| `-O2`, minus `-mllvm -wasm-enable-sjlj` | `std::terminate`, unchanged |

Reproduce the first four with `Scripts/repro/2894/run.sh bisect`. This is a **code-generation
defect in the WebAssembly exception lowering**, not an OCCT bug, not a missing flag on a toolkit,
and not a property of the exception type or of the distance it travels.

## What ran

`probe.cpp` is one translation unit holding six cases, so the module's exception configuration
cannot be the variable between them. `run.sh wasm` and `run.sh native` run the same source on the
two targets. Measured 2026-10-02 against `v4.0.0-kernel.2` (the pinned wasm asset) and the
`v4.0.0-kernel.3` xcframework, with the pinned toolchain.

| | what it raises | wasm | arm64 macOS |
|---|---|---|---|
| A `BRepPrimAPI_MakeBox(0, 0, 0)` | `Standard_DomainError`, inside the archive | caught | caught |
| E `gp_Ax3(P, (0,0,1), (0,0,1))` | `Standard_ConstructionError` from `gp_Dir::CrossCross`, **inline, expanded in this unit** | caught | caught |
| D `Geom_TrimmedCurve(C, 1.0, 1.0)` | `Standard_ConstructionError`, #2894's own raise | caught | caught |
| C the same raise, unwound through `Geom_Plane`, `NCollection_DataMap`, `NCollection_List`, `TopoDS_Face` and `BRepTools_WireExplorer` locals | the same | caught | caught |
| F `BRepFill_Evolved::Perform`, straight profile | nothing | `IsDone=1` | `IsDone=1` |
| B `BRepFill_Evolved::Perform`, #2894's profile | `Standard_ConstructionError` | **`std::terminate`** | caught |

Every candidate the issue listed is answered by that table.

- **Frame count and unwinding depth.** Case C unwinds the same raise through a frame holding every
  local type `PrepareProfile` holds, and it is caught. Depth is not the discriminator, and the
  destructor reading the issue's last comment proposed is dead.
- **Which translation unit the throw originates in.** Cases A, D and E raise from three different
  places (the OCCT archive, the OCCT archive, and an inline header expanded in the probe's own
  unit) and all three are caught.
- **#2757, setjmp plus wasm exceptions in one function.** The linked module carries **one** wasm
  tag, the C++ exception tag. `__c_longjmp` is not in it, `BRepFill_Evolved.cxx.obj` references
  neither `setjmp` nor `longjmp`, and removing `-mllvm -wasm-enable-sjlj` from the unit's compile
  changes nothing.
- **A shadow stack too small for a deep unwind.** The link sets a 4 MB stack, and `-O0`, whose
  frames are larger, is the setting that works.

## The mechanism, measured rather than reasoned

**Exactly one exception is thrown.** Interposing `__cxa_throw` with `wasm-ld`'s `--wrap` prints one
line, `Standard_ConstructionError`, and then the process terminates. So no destructor threw during
the unwind, and the terminate is not the C++ "exception thrown while unwinding" rule firing.

**`std::terminate` is called outright, not through the exception machinery.** The probe's terminate
handler finds `std::current_exception() == nullptr`. In the disassembly of the pinned
`BRepFill_Evolved.cxx.obj`, `PrepareProfile` holds 169 `try_table`s, of which 65 are a plain
`catch_all` (which cannot rethrow) whose target block is `global.set 0` then a call to
`_ZSt9terminatev` then `unreachable`. That is the ordinary shape of a terminate scope wrapped
around a cleanup, and one of them is being entered by the original exception.

**The cleanup that runs belongs to an object that was never constructed.** `run.sh marks` shows
both halves in one run. It instruments `CutEdgeProf` with three prints and compiles at
`-O2 -mllvm -inline-threshold=0`, which is not "no inlining" (`CutEdgeProf` is file-static with one
call site, so it is inlined whatever the threshold) but does remove the terminate scope that
otherwise swallows the failure, so the same defect surfaces as a trap that names the destructor:

```
PROBE2894 MARK CutEdgeProf entry
PROBE2894 MARK before Geom_TrimmedCurve
PROBE2894 MARK after Geom_TrimmedCurve
PROBE2894 MARK before Seq ctor
PROBE2894 MARK after Seq ctor                 <- first call completes
PROBE2894 MARK CutEdgeProf entry
PROBE2894 MARK before Geom_TrimmedCurve
PROBE2894 MARK after Geom_TrimmedCurve        <- second call: the throw is after this line
Error: Trap: out of bounds memory access
    0: NCollection_Sequence<double>::delNode(...)
    3: NCollection_Sequence<double>::~NCollection_Sequence()
    4: BRepFill_Evolved::PrepareProfile(...)
```

`PrepareProfile` declares no `NCollection_Sequence<double>`. `CutEdgeProf` does, nine lines below
the `Geom_TrimmedCurve` it builds, and `before Seq ctor` is never printed for the second call. The
exception lands between the two marks, in the `GeomProjLib` work that follows, and the unwind
nevertheless destroys `Seq`, a local whose constructor has not run. `-fno-inline` keeps
`CutEdgeProf` a separate frame and the whole path is correct again.

## What it means for a consumer

A refusal that is a caught exception on Apple can be an aborted module on wasm, and which one it is
depends on whether the kernel's optimiser inlined a callee into the frame the exception passes
through. Nothing about the call site, the exception type or the API predicts it. The bound on how
wide this is comes from #2793's suite rather than from analysis: of roughly 3,600 wasm tests, two
suites trap, and both reach `BRepFill_Evolved`.

**There is no bridge-side guard for it.** The bridge's `catch (...)` is correct and is never
reached; the input that provokes the raise is a profile wire whose projection degenerates, which no
cheap predicate separates from a valid one.

## What would fix it

Upstream, in LLVM: the inliner and the WebAssembly exception lowering disagree about which cleanups
are live in an inlined region. The reduction for that report is the remaining work, and
`run.sh bisect` is the harness for it: one translation unit, one flag, two outcomes.

**The obvious small shape does not reproduce**, which is recorded so it is not re-derived. A
file-static callee with three tracked locals, inlined into a loop in its single caller, throwing
on the second iteration before the second and third constructors run, with the caller holding a
cleanup of its own, compiled with the same flags at `-O2`: every constructor pairs with its own
destructor and the `catch` fires. Whatever the real trigger is, it needs more structure than that,
which is why the reduction has to start from `BRepFill_Evolved.cxx` rather than from a sketch.

Locally, the only measured workaround is `-fno-inline` on the affected unit, which is a kernel
rebuild (69 minutes) plus a republish of the pinned wasm asset. That rebuild is already owed to the
OCCT 8.0.2 repin, and taking it for one unit before the mechanism is understood would be guessing
at the population: the defect is in the compiler, so any OCCT unit with the same shape has it.

## Running it

```bash
Scripts/install-wasm-toolchain.sh          # once
Scripts/fetch-occt-wasm.sh                 # once

Scripts/repro/2894/run.sh wasm             # the six cases on wasm
Scripts/repro/2894/run.sh native           # the same six on arm64 macOS
Scripts/repro/2894/run.sh bisect           # -O0 / -O2 / -O2 -fno-inline, case B each
Scripts/repro/2894/run.sh marks            # the throw site and the cleanup, in one run
Scripts/repro/2894/run.sh bridge           # #2891's inputs through the real bridge sources
```

`bisect` and `marks` need an OCCT source tree. A worktree has none, so point `OCCT_SRC` at the main
checkout's `Libraries/occt-src`. A worktree also has its own `Libraries`, so `WASI_SDK_PREFIX` may
need to point at the main checkout's wasi-sdk rather than a second copy.

## The sibling, #2891, does not share this

`run.sh bridge` compiles `OCCTBridge.mm` and `OCCTBridge_Spatial_GeometryUtils.mm`, the two real
bridge units behind `OCCTAx3Translate`, with the flags `Scripts/make-wasi-toolset.py` emits, and
calls #2891's exact inputs:

```
PROBE2891 location (5, 3, 2) records=1
PROBE2891   record 0: OCCTAx3Translate: Standard_ConstructionError: gp_Dir::CrossCross() - result vector has zero norm
PROBE2891 Apple answer: (5, 3, 2) records=1
```

That is the Apple answer, on wasm, from the bridge's own sources. Case E above says the same thing
from the other side: an inline `_Raise_if` expanded in a unit compiled like the bridge does fire on
this target, at `-O2`. So #2891 is not "wasm cannot raise from an inline check", and it is not this
defect either. Whatever produced its `records=0` and `(6, 5, 5)` belongs to the build that was
measured, which is the thing to re-measure first. Note that dropping `-fwasm-exceptions` from a
bridge unit is not the silent failure it would be elsewhere: `OCCTBridge.mm` reaches
`Standard_ErrorHandler.hxx` and therefore `setjmp.h`, which `#error`s without the flags.
