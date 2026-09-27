---
nav_exclude: true
search_exclude: true
---

# #2175: Swift over OCCTSwift over the bridge over OCCT, on wasm, and the Phase 0 go/no-go

`run.sh` reproduces every number below. Like [`Scripts/repro/2172`](../2172/README.md),
[`2173`](../2173/README.md) and [`2174`](../2174/README.md), it reads the compiler, the sysroot and
every flag out of the build tree CMake generated rather than restating them, so it cannot drift
from the build it describes.

    Scripts/build-occt-wasm.sh          # the kernel: 49 toolkits, 5,488 files, ~35 minutes
    Scripts/repro/2175/run.sh           # everything below
    Scripts/repro/2175/run.sh sjlj      # just the blocker, and the negative case for its fix

Measurements, 2026-09-25, macOS 27.0 arm64, 10 cores. Swift toolchain 6.4.0-RELEASE, Swift wasm SDK
6.4.0-RELEASE, wasi-sdk 34.0, `wasmkit` 0.3.1, all as pinned by
[`Scripts/wasm-toolchain-versions.txt`](../../wasm-toolchain-versions.txt). `Libraries/occt-src` at
`V8_0_1` plus all twenty-nine carried patches plus the eleven WASI patches, which is what
[`okf/policies/wasi-patch-base.md`](../../../okf/policies/wasi-patch-base.md) requires.

`llvm-ar`, `llvm-nm` and `llvm-objdump` are the **pinned** toolchain's. There is no `llvm-nm` on
the default macOS PATH at all, and host `nm -g` on a wasm object lists undefined symbols as though
they were defined, which has already produced two wrong conclusions in this initiative.

## The headline

**The whole stack runs.** Swift, over the OCCTSwift public API, over the C bridge, over OCCT, in
one `wasm32-unknown-wasip1` module, under the pinned `wasmkit`:

    OCCTSwift wasm spike, wasm32-unknown-wasip1: Swift -> OCCTSwift -> bridge -> OCCT
    case box                  PASS  10x20x30 volume=6000.0 faces=6 edges=12 vertices=8
    case fuse                 PASS  two 10-cubes overlapping in one octant, volume=1875.0 expected=1875.0 faces=12 valid=true
    case step-export          PASS  wrote .../spike-fused.step bytes=36189 header=ISO-10303-21;
    case step-import          PASS  read back volume=1875.0 faces=12 against the written shape's 1875.0/12
    case must-fail-raise      PASS  Shape.box(0,0,0) -> nil, records=1 [OCCTShapeCreateBox: Standard_DomainError: ]
    case must-fail-internal   PASS  malformed STEP refused as readFailed(..., status: IFSelect_RetFail: the step ran and failed), bridge records=0
    note stepData             bytes=36189 via FileManager.default.temporaryDirectory = /tmp
    failures: 0

Everything in that list goes through the published Swift surface. Nothing calls the bridge
directly, because the question this gate answers is whether a SwiftWasm application consuming
OCCTSwift as a SwiftPM dependency can do real CAD work, not whether the C functions are reachable.

**One blocker stood between the link and that output, and it was not in any of the places this
effort had been looking.** A C++ function carrying both a lowered `setjmp` and wasm exceptions
comes out as an **invalid** wasm module. It is written up below and filed as #2757; the fix is one
flag in `Scripts/build-occt-wasm.sh`.

Four smaller gaps, all in merged code, all invisible to every check that existed:

| Gap | What it did | How it read |
|---|---|---|
| `OCCTBridge.h` has no `<stdbool.h>` | 1,198 `unknown type name 'bool'` errors in 14 of the 18 bridge headers | invisible to every bridge `.mm`, which compile as C++ where `bool` is a keyword |
| no bridge source included the threading shim | the `#include` `Package.swift` says the bridge relies on did not exist | the manifest's comment describes a mechanism nothing used |
| 196 of 230 Swift files `import simd` | `no such module 'simd'`, the entire Swift layer | nothing on an Apple platform can see it |
| `Shape.isSelfIntersecting(hardTimeout:)` needs a second thread | `cannot find 'DispatchSemaphore' in scope` | the only Dispatch user in 230 files |

## The five calls, and why each one is there

The issue asked for five. Two of them are the same call: the must-fail one has two halves, because
a refusal that OCCT raises and a refusal OCCT handles internally are different measurements.

### 1, `Shape.box(width:height:depth:)`

Pure compute, and the question is whether OCCT runs at all on this target: static initialisation
under `_start`, the `Standard_Type` registry, `TopoDS`/`BRep` construction. Volume 6000, 6 faces,
12 edges, 8 vertices.

The counts are the **deduplicated** ones, `uniqueFaceCount` and `uniqueEdgeCount`. A
`TopExp_Explorer` visits a shared sub-shape once per owner and answers 24 for a box's edges, which
is the fixture trap #2174's probe fell into and reported as a FAIL against a perfectly correct
solid.

### 2, `Shape.fused(with:tolerance:)`

Exercises the allocator hard, which is the risk #2171 recorded and could not probe, and which
#2174 answered for `operator new` alone. Two 10-cubes overlapping in one octant:
1000 + 1000 − 125 = **1875**, asserted against the literal rather than against "it returned
something".

### 3, STEP export, and the filesystem question

`Exporter.writeSTEP(shape:to:name:)`, unchanged, taking a `URL` whose path is inside a directory
the host preopened. It wrote a 36,189-byte AP214 file of 806 entities, and the assertion is on the
`ISO-10303-21;` header rather than on the file existing, because a present and empty file is
exactly the failure that would otherwise read as a pass.

**The path-taking API needs no change.** This was expected to be the awkward part and it is not.
The mechanism is the one CascadeStudio (MIT, `zalo/CascadeStudio`) uses in production for the same
problem under Emscripten: write the bytes into the virtual filesystem, call the unchanged
path-taking OCCT entry point, read the bytes back out, unlink. Emscripten hands you MEMFS at `/`
for free; WASI has no filesystem at all until the host preopens one, and the equivalent is
`@bjorn3/browser_wasi_shim`'s `PreopenDirectory(name, entries)` of in-memory `File`s, passed in the
`fds` array a SwiftWasm app already constructs for the Swift runtime. Same three steps, different
provenance for the directory.

**What is measured here and what is inferred.** Measured: under `wasmkit`, `--dir <path>` preopens
a real directory on disk and the unchanged `Exporter`/`Shape` path API reads and writes in it.
Inferred: that the browser shim's in-memory `PreopenDirectory` behaves the same, which follows from
its documented behaviour and from the fact that the WASI calls the module makes are the same ones
either way (see [Host imports](#host-imports) below, where the preopen and path calls are listed),
but which nothing in this repository has run in a browser. #2052 is where that gets measured.

**The bytes-out convenience already exists and already works.** `Exporter.stepData(shape:name:)`
writes to `FileManager.default.temporaryDirectory` and reads the file back, which on this target
resolves to `/tmp`. With `/tmp` preopened it returns the same 36,189 bytes; without it, it throws
`ExportError.writeFailed`. So the rule for a host is one line: preopen the directory
`FileManager.default.temporaryDirectory` names, and the byte-oriented API works with no change at
all. The spike **reports** that case rather than asserting it, because whether the directory is
reachable is a property of the host's preopens rather than of the API.

There is no bytes-**in** equivalent (`Shape.load` takes a path or a `URL`, and no initialiser takes
`Data`), and per the above there does not need to be: the host writes the bytes into the preopen
first. That is a finding for #2052 and Phase 3 rather than an API change.

### 4, STEP import

The **read** side of the preopen question, which nothing in this effort had touched: export writes,
import must open and read a file the host provides. It also puts `Interface_Static` (carried patch
`0033`) under the #2170 shim's no-op locks on the read path, and allocates at a scale export does
not reach.

`Shape.load(fromPath:)` read back volume 1875.0 and 12 faces, asserted against **case 2's own
numbers** rather than against a literal, so a STEP file that parses into the wrong solid cannot
pass.

### 5a, the must-fail call: a raise crossing OCCT into the bridge

**The most important case, and the memo is worthless without it.** #2171 measured that a
translation unit built without `WASM_CXX_EH_FLAGS` returns correct boxes, correct fuses and correct
STEP files, and answers every error by trapping the module or leaking every `Handle` between the
raise and the bridge, with no diagnostic anywhere. Nothing in cases 1 to 4 can distinguish that
build from a correct one.

`Shape.box(width: 0, height: 0, depth: 0)` reaches `BRepPrimAPI_MakeBox`, which throws
`Standard_DomainError` from `BRepPrim_GWedge.cxx`, a `TKPrim` object of the archive.
`OCCTShapeCreateBox`'s outermost `catch (...)` is in the bridge. So the unwinder crosses from OCCT
into the bridge and the refusal arrives in Swift as `nil`.

    Shape.box(0,0,0) -> nil, records=1 [OCCTShapeCreateBox: Standard_DomainError: ]

`nil` alone would not prove it: a bridge that never entered OCCT returns `nil` too. The diagnostic
channel (#1161, swept to complete function-level coverage by #2077) is what makes this an
assertion. The record names the bridge function that caught it and the OCCT exception's own class,
read from `Standard_Failure::ExceptionType()`, through `OCCTDiagnostics.capturing`. The message is
empty because `BRepPrim_GWedge` raises with no text, which is OCCT's own behaviour and not a wasm
artefact.

#2174 proved the same raise reaches a C++ `main`. This is the first time it reaches **Swift**.

### 5b, the must-fail call: OCCT's own handler, with nothing reaching the bridge

The other half the issue asked for: a call whose documented failure mode is a false return rather
than a raise. `IFSelect_WorkSession::ReadFile` wraps the parse in its own `try`/`catch` and turns a
`Standard_Failure` into `IFSelect_RetFail`, which the bridge reports as a status and Swift throws
as `ImportError.readFailed`.

That handler is inside OCCT's own translation units, so it is exactly the thing #2171 says
disappears with no diagnostic if the exception flags miss a file. The discriminating assertion is
the **pair**: a refusal reaches Swift **and** the bridge's capture stays **empty**, because nothing
propagated as far as the bridge.

    malformed STEP refused as readFailed(..., status: IFSelect_RetFail: the step ran and failed),
    bridge records=0

OCCT also printed its own parser diagnostic on the way, which is the handler being reached rather
than skipped:

    **** ERR StepFile : Undefined Parsing: Line 2: Incorrect syntax: unexpected TYPE, expecting STEP

### Proving the six cases can fail

[`prove-the-test-fails`](../../../okf/policies/prove-the-test-fails.md), for the spike itself
rather than for the blocker below. The box case's expected volume was changed from 6000 to 6001,
the module rebuilt and re-run:

    failures: 1
    *** FAILED: wasmkit exit 1
    >>> 1 case(s) failed.

and restoring it returns `6 of 6 cases PASS, exit 0`. Two things are being proved there and both
matter: the module's own `exit(Int32(failures))` reaches the runner, and `run.sh run` fails the
invocation rather than printing a red line into a green exit status. It also asserts six PASS lines
rather than only the exit status, so a module that printed nothing and exited 0 cannot pass.

## The blocker: setjmp and wasm exceptions in one function emit an invalid module

Filed as #2757. This is what stood between a module that links and a module that runs, and it is
worth reading in full because nothing in #2169 through #2174 could have found it: every one of them
linked C++ only, and none reached this function.

The spike linked on the first attempt and then died immediately after its first `print`:

    OCCTSwift wasm spike, wasm32-unknown-wasip1: Swift -> OCCTSwift -> bridge -> OCCT
    Error: expected the same copy types for all branches in `br_table` but got
    [i32, ref(exnRef)] and []    at offset 0x26e8a68

The function at that offset, from the pinned `llvm-objdump`, is
`BRepCheck_ParallelAnalyzer::operator()(int) const`, which declares **eleven `exnref` locals** and
carries **six `OCC_CATCH_SIGNALS`** in one body. The instructions around the offset:

```
 26e8a56: 02 de 81 80 80 00    block   unknown_type          # multi-value, results [i32, exnref]
 26e8a5c: 1f 40 01 01 80 ...   try_table  (catch_ref 0 0)
 26e8a66: 20 04                local.get 4
 26e8a68: 0e 03 04 01 02 02    br_table  {4, 1, 2, 2}
```

Depth 1 is that multi-value `block`; depths 2 and 4 are plain `block`s carrying nothing. The
WebAssembly specification requires every `br_table` target to have the **same** label types, so
**the module is invalid and wasmkit is right to refuse it.** This is a codegen defect, not a
runtime limitation, and any conforming runtime would reject the same bytes.

`OCC_CATCH_SIGNALS` is what puts a `setjmp` there. With `OCC_CONVERT_SIGNALS` defined,
`Standard_ErrorHandler.hxx` expands it to `Standard_ErrorHandler _aHandler; if
(setjmp(_aHandler.Label())) { _aHandler.Raise(); }`, and `-mllvm -wasm-enable-sjlj` lowers that
into a state machine. Combined with the exception flags in the same function, the result is the
`br_table` above.

### The fix, and why it is the correct setting rather than a workaround

`Scripts/build-occt-wasm.sh` now passes **`-UOCC_CONVERT_SIGNALS`** in `CMAKE_CXX_FLAGS`. CMake's
compile rule is `$(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS)`, so the `-U` is the last word and
beats the `-D` OCCT's own CMake puts in `CXX_DEFINES`. No patch, and nothing to re-find at the next
kernel bump.

`OCC_CONVERT_SIGNALS` exists to turn an OS signal into a C++ exception. **A wasm module receives no
OS signals**, so `OCC_CATCH_SIGNALS` could never have done anything on this target. It also matches
the Apple kernel this repo ships, where the macro is inert for a different reason
([`okf/references/known-occt-bugs.md`](../../../okf/references/known-occt-bugs.md)).

What it moved:

| | with `-DOCC_CONVERT_SIGNALS` | with `-UOCC_CONVERT_SIGNALS` |
|---|---|---|
| `BRepCheck_Analyzer.cxx.obj` | 153,618 bytes | 52,001 bytes |
| its `__wasm_setjmp` / `__wasm_longjmp` / `__c_longjmp` references | 3 | **0** |
| `libOCCT-wasm.a` | 163,356,516 bytes | 153,192,816 bytes |
| its defined symbols | 291,277 | 287,919 |
| setjmp references anywhere in its 5,488 members | non-zero | **0** |
| the Swift spike under wasmkit | refused at the first OCCT call | runs, 6 of 6 |

### The negative case

`run.sh sjlj` asserts in both directions, which is what
[`prove-the-test-fails`](../../../okf/policies/prove-the-test-fails.md) asks for. It compiles that
one OCCT source file twice with the build tree's own flags, once with the define forced back on;
reports the setjmp symbol counts and object sizes above, and **fails if the define stops producing
a lowered setjmp**, because then the case measures nothing. Then it copies the archive, swaps the
with-signals object in, relinks the real spike against it and runs it, requiring both that it fails
and that it fails on `br_table` rather than for some other reason.

    -DOCC_CONVERT_SIGNALS    setjmp symbols=3  object=153618 bytes
    -UOCC_CONVERT_SIGNALS    setjmp symbols=0  object=52001 bytes

    the same spike, against an archive whose BRepCheck_Analyzer.cxx.obj carries setjmp:
      OCCTSwift wasm spike, wasm32-unknown-wasip1: Swift -> OCCTSwift -> bridge -> OCCT
      Error: "Message(text: "expected the same copy types for all branches in `br_table` ...
    VERDICT: refused, and refused for the br_table reason. This is #2175's blocker.

### What is NOT reduced

[`probe-sjlj-eh.cxx`](probe-sjlj-eh.cxx) reproduces the **source shape**: a `setjmp` inside a `try`
whose handler object has a destructor, six of them in one loop body, which is
`BRepCheck_ParallelAnalyzer`'s shape. Compiled with the same flags, **that module is valid and
runs**. So the trigger needs more than the shape, and #2757 records that the upstream LLVM report
still needs a reduction. The probe is kept because a negative result about a reduction is worth as
much as the reduction would have been: it says where not to look.

## The four gaps in merged code

### `OCCTBridge.h` needs `<stdbool.h>`, not only `<stdint.h>`

#2049 guarded `#import <Foundation/Foundation.h>` out on WASI, and #2256 found that Foundation was
the only thing supplying `<stdint.h>`, which was 19 `unknown type name 'int32_t'` errors. It was
also the only thing supplying `<stdbool.h>`, and that half did not surface until Swift entered the
picture.

Every `.mm` in `Sources/OCCTBridge/src` compiles as C++, where `bool` is a keyword, so all 74 of
them compiled clean. `import OCCTBridge` from Swift builds the same headers as a clang module in
**C** (Objective-C on Apple), and there `bool` is a macro `<stdbool.h>` defines. Measured by
compiling the umbrella header for this triple with `-x c -ferror-limit=0`:

| | |
|---|---|
| errors in total | 1,523 |
| of those, `unknown type name 'bool'` | **1,198** |
| headers affected | 14 of the 18 in `Sources/OCCTBridge/include` |
| with `#include <stdbool.h>` restored | **0** |

### No bridge source included the threading shim

`Package.swift`'s WASI `OCCTBridge` target carries `.headerSearchPath("../../Scripts/wasm-shims")`
and a comment explaining that a guarded `#include` is preferred to the `-include` flag
`build-occt-wasm.sh` uses, because "a consumer who forgets nothing cannot forget this". Measured:
**no file in `Sources/OCCTBridge` included it**. The search path pointed at a header nothing named.

It matters because `OCCTBridge_Internal.h` declares five `std::mutex`es and a
`std::recursive_mutex`, and because #2174 measured that anything which merely *includes* OCCT needs
the shim as well: `Message_ProgressIndicator.hxx`, `NCollection_IncAllocator.hxx` and
`Poly_Triangulation.hxx` name `std::mutex` or `std::shared_mutex` in **public** headers. The
`#include` is now in `OCCTBridge_Internal.h`, under `#if defined(__wasi__)`, first, before
`<mutex>`.

Both mechanisms work: the spike builds with the toolset that force-includes the shim
(`make-wasi-toolset.py`'s default) and with `--no-shim`, which is #2048's cases 8 and 4
respectively, now measured through the real bridge rather than through a stub.

### `import simd`, in 196 of 230 files

Apple's `simd` is part of the Apple SDKs and there is no wasm build of it, so
`Sources/OCCTSwift/AnalyticGeometry.swift:3: error: no such module 'simd'` stops the Swift layer
before any of it is type-checked, and it stops it 196 times.

`Sources/WASICompat/simd/SIMDCompat.swift` is a target **named** `simd` that `Package.swift` adds
to `OCCTSwift`'s dependencies only when `isWASI`. No Apple build has it in the graph, `import simd`
still resolves to Apple's there, and none of the 196 files changed. What it defines is what the
package measurably uses and no more:

    grep -rho "simd_[a-zA-Z_0-9]*" Sources/OCCTSwift/ | sort | uniq -c

`simd_normalize` 62, `simd_length` 32, `simd_dot` 28, `simd_cross` 16, `simd_float4x4` 8,
`simd_length_squared` 5, `simd_distance` 4, `simd_double3x3` 3, `simd_min` 1, `simd_max` 1, plus
the unqualified `min`/`max` overloads for SIMD vectors that `Mesh.boundingBox` calls as plain
`min(a, b)`. `SIMD2`, `SIMD3` and `SIMD4` are Swift standard library types on every platform and
are not redefined.

Two differences from Apple's module, both deliberate and both recorded in the file: a
`simd_normalize` of a zero vector returns the input rather than a vector of NaNs, and the two
matrix types are column containers with no arithmetic, which is all `Sources/OCCTSwift` asks of
them (measured: no `.columns` access, no matrix arithmetic, no `matrix_*` or `vector_*` name
anywhere in the package). What to do about the 196 imports properly is #2759.

### `Shape.isSelfIntersecting(hardTimeout:)` cannot exist here

Three lines across one file are the only Dispatch use in `Sources/OCCTSwift`, and they are not
incidental: the method's whole contract is a hard wall-clock deadline enforced by a second thread
waiting on a `DispatchSemaphore`. `wasm32-unknown-wasip1` non-threads has one thread, so no
implementation of that signature can honour it. It is `#if !os(WASI)` rather than quietly weakened
into the cooperative `isSelfIntersecting(timeout:)` that already exists beside it. The API decision
is #2760.

## Sizes

The module carries the Swift runtime, Foundation, the Swift layer, the bridge and whatever of OCCT
those six calls reach. The two controls are what makes it readable: #1689's consumer is a SwiftWasm
app that already carries the Swift runtime and a WASI shim, so the number that matters is what
OCCT **adds**, not the total. `run.sh controls` builds them; they are `print("hi")` and a
three-line Foundation program using `URL`, `Data` and `FileManager.default.temporaryDirectory`.

| Module | Uncompressed | `gzip -9` | `brotli -q 11` |
|---|---|---|---|
| `HelloPlain`, Swift runtime only | 7,159,728 | 1,899,494 | 1,352,699 |
| `HelloFoundation`, + Foundation | 60,380,095 | 20,060,965 | **13,112,239** |
| **`OCCTWasmSpike`**, + bridge + OCCT | **141,861,273** | 41,110,844 | **26,976,003** |

There is **no size budget**: #1689's 5 MB was withdrawn on 2026-09-25, having never been like-for-like with the `occt-wasm` figure it was set against and having been exceeded by Foundation alone before any OCCT. The module is 26.98 MB
brotli, 5.4x over it. Two things have to be said about that number rather than one.

**Foundation is already 2.6x over the target on its own.** A SwiftWasm app that does nothing but
print a path is 13.11 MB brotli before any of this package is in it. By section:

| Section | `HelloFoundation` | `OCCTWasmSpike` |
|---|---|---|
| `CODE` | 15,828,699 | 56,983,898 |
| `DATA` | 37,615,734 | 41,019,123 |

37.6 MB of `HelloFoundation` is **data**, not code, and `import Foundation` is what pulls it:
Foundation's internationalisation data. Stripping debug information moves nothing, measured:
60,380,095 to 60,375,460, so this is not DWARF that a release pipeline would drop.

**So the size question is not primarily an OCCT question.** OCCT and the bridge add 13.86 MB brotli
over a Foundation SwiftWasm app; Foundation adds 11.76 MB brotli over a plain one. Neither figure
has had `wasm-opt`, `--gc-sections` tuning, `FoundationEssentials` instead of `Foundation`, or any
other size work applied to it, and none of that is in this issue's scope. Size work is #2761.

For continuity with #2174, whose C++-only `probe-step.wasm` was 3.27 MB brotli and carried no
Swift, no Foundation and no bridge: that figure was described there as "a floor and not an answer",
and the 26.98 MB here is what the rest of the stack costs on top of it.

## Host imports

A linked wasip1 module's host imports are its remaining undefined symbols, each named
`__imported_wasi_snapshot_preview1_<field>`.

| Module | `wasi_snapshot_preview1` | from any other module |
|---|---|---|
| a hello-world C program, #2174's control | 5 | 0 |
| `probe-step.wasm`, C++ over OCCT, #2266 | 16 | 0 |
| `HelloPlain`, Swift runtime only | 14 | 0 |
| `HelloFoundation`, + Foundation | **34** | 0 |
| **`OCCTWasmSpike`**, + bridge + OCCT | **34** | 0 |

**OCCT and the bridge add nothing.** The set difference between the OCCTSwift module's imports and
a Foundation SwiftWasm module's is empty, measured with `comm` over both sorted lists. That is the
answer to the question the issue asked, and it is the strongest single result for #2052: a host
that can run a SwiftWasm app using Foundation's file APIs can run this module with no additional
host function of any kind, and nothing is imported from any module other than
`wasi_snapshot_preview1`.

The 34, for a shim author:

    args_get args_sizes_get clock_res_get clock_time_get environ_get environ_sizes_get
    fd_close fd_fdstat_get fd_fdstat_set_flags fd_filestat_get fd_filestat_set_size
    fd_filestat_set_times fd_pread fd_prestat_dir_name fd_prestat_get fd_read fd_readdir
    fd_seek fd_sync fd_tell fd_write path_create_directory path_filestat_get
    path_filestat_set_times path_link path_open path_readlink path_remove_directory
    path_rename path_symlink path_unlink_file poll_oneoff proc_exit random_get

`fd_prestat_get` and `fd_prestat_dir_name` are how wasi-libc discovers preopened directories at
startup, and `path_open` is how the STEP writer and reader open a file inside one. Those three are
the whole filesystem story from the module's side, and they are in the set a Foundation SwiftWasm
app already imports.

## What the spike package is, and what it is not

[`spike/`](spike) is a **separate package** that declares OCCTSwift as a dependency and builds only
the `OCCTSwift` product, which is the shape #1689's consumer has. Building OCCTSwift as the root
package would also plan its eighteen test targets and three executables for wasm, none of which
this gate is about.

The dependency is by **path**, with an explicit `name: "OCCTSwift"` so the package identity does not
come from the directory name and the spike therefore builds in any checkout.

**This does not verify the versioned-dependency rule, and it does not need to.** #2048 measured
that SwiftPM's `.unsafeFlags` refusal is a property of a version requirement rather than of the
platform, so a path dependency exempts itself from the thing that mattered. What makes the
versioned form viable is that neither manifest carries an `.unsafeFlags` on the WASI path at all,
which `Package.swift` states and which the build line here shows: every flag with no safe spelling
comes from the consumer's toolset, written by `Scripts/make-wasi-toolset.py`.

**What a versioned consumer still needs, and does not get from git.** `Libraries/libOCCT-wasm.a` is
153 MB and `Libraries/occt-headers-wasm/` is 7,160 files, and both are gitignored. A consumer
resolving `.package(url:, from:)` clones a tree that contains neither, so `-lOCCT-wasm` and
`.headerSearchPath("occt-headers-wasm")` resolve to nothing. That is Phase 1's release-asset
distribution path, listed there already; it is stated here because the spike would have hidden it
behind the path dependency if nobody said so.

## What this does NOT establish

- **One configure, one host, one runtime.** macOS 27.0 arm64, `wasmkit` 0.3.1. Nothing has been run
  in a browser, which is #2052, and nothing has been run under `wasmtime`.
- **Six calls, not a test suite.** The per-domain test targets have not been built for wasm, let
  alone run. That is Phase 4.
- **No numerical parity check against the Apple build.** The values asserted here are the
  analytically correct ones (6000, 1875, 6 faces, 12 edges), which is a stronger check than parity
  for these shapes, but it is six values and not a comparison of the two kernels.
- **The browser filesystem is inferred, not measured.** See case 3.
- **Threading is untested because there is none.** The bridge's `occtGlobalMutex` is a no-op under
  the #2170 shim on this target, and every call here was made from one thread. Nothing was learned
  about what a threads-variant build would do.

## Related

- [`Scripts/repro/2174/README.md`](../2174/README.md), OCCT linked and run from C++, and #2266's
  close. Note that its `run.sh libs` will now report `-lsetjmp` as **not** load-bearing, which is
  this issue's change and is tracked in #2758.
- [`Scripts/repro/2171/README.md`](../2171/README.md), what exceptions do on wasip1.
- [`Scripts/repro/2048/README.md`](../2048/README.md), how a wasm application consumes this package.
- [`docs/wasm-feasibility.md`](../../../docs/wasm-feasibility.md), the plan of record, which carries
  the Phase 0 memo and the go/no-go.
- [`docs/WASI_GUARD_SITES.md`](../../../docs/WASI_GUARD_SITES.md), the guard-site record, which
  carries `-UOCC_CONVERT_SIGNALS`.
