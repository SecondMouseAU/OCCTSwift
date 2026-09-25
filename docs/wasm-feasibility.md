---
nav_exclude: true
search_exclude: true
---

# WebAssembly feasibility & plan

This doc captures the analysis of building OCCTSwift for WebAssembly so that the
**OCCTSwift Swift API can be reused inside a SwiftWasm app** (e.g. a browser app
driven by JavaScriptKit, or a server-side wasm runtime). Written June 2026 as a
forward plan. The toolchain is now pinned and has been run end to end, see
[Pinned toolchain](#pinned-toolchain). As of #2266, **all 5,488 source files in the
configured module set compile for `wasm32-unknown-wasip1`, and a C++ module linked
against them runs**: it builds a solid, measures it, meshes it, catches a
`Standard_Failure` OCCT raised from inside its own compiled code, and writes an
AP203 STEP file. #2174 got 5,487 of those and left one, `TKDESTEP`'s
`STEPConstruct_AP203Context.cxx`, which blocked STEP and with it the packaging step;
#2266 closed it.

**As of #2175 there is Swift in the module, and the Phase 0 gate is closed with a
GO.** Five calls through the OCCTSwift public API, over the bridge, over OCCT, in
one `wasm32-unknown-wasip1` module under the pinned `wasmkit`: a box, a fuse, a STEP
export, a STEP import, and one that must fail and does, arriving in Swift as a
refusal carrying the OCCT exception's own class name rather than as a trap. The memo
is [Phase 0](#phase-0-decision-spike-done-and-the-verdict-is-go-with-conditions)
below and the measurement log is
[`Scripts/repro/2175/README.md`](../Scripts/repro/2175/README.md).

The goal is fixed, and **the path is now settled as B**, by the only argument that
settles it: B linked and ran. A and C were never attempted and are moot. See
[Three paths](#three-paths-to-one-wasm-module) for what they were.

## Goal

Compile the existing Swift public API (`Shape`, `Wire`, `Surface`, …) → the C bridge
→ OCCT, all the way down to a single wasm module that a SwiftWasm application can
call. The consumer is **Swift**, not JavaScript, that is the only thing that
justifies this work, because OCCT-in-the-browser already exists for JS consumers
(see [Prior art](#prior-art)).

## What's already in our favour

Two structural facts make this more tractable than the `platform-expansion.md`
(Linux/Windows/Android) review assumed:

1. **The bridge is already wasm-shaped.** Despite the `.mm` extension, the 74
   files in `Sources/OCCTBridge/src` contain **zero Objective-C runtime**, no
   `NSString`, `NSObject`, `@try`, `@autoreleasepool`. It is pure C++ with a flat
   C-linkage surface (`double` / `int32_t` / `const char*` / `bool` / opaque
   `OCCT*Ref` pointers). The only ObjC touch is one
   `#import <Foundation/Foundation.h>` in the header, already guarded out on WASI
   by #2049. A flat C ABI is exactly the recommended seam for Swift-on-wasm.
   *(Note: this supersedes the stale "57k-line .mm, audit for ObjC-isms" claim in
   `platform-expansion.md`, the bridge has since been split into per-area files
   and verified clean.)* **The extension is not cosmetic on this target**: see
   "The bridge is compiled as C++, not Objective-C++" below.

2. **OCCT is configured headless, and that buys less than it reads.**
   `build-occt.sh` ships Visualization / OpenGL / GLES / FreeType / TBB / VTK /
   Draw all **OFF**; only FoundationClasses, ModelingData, ModelingAlgorithms,
   DataExchange + RapidJSON are ON. No GL context and no TBB is real and it is
   what makes the port plausible. **The module list is not, and this paragraph
   used to claim it was "precisely the subset that ports to wasm".** Measured
   2026-09-23 against the macOS install tree those flags produce, and again by
   #2174 against the wasm build tree itself: **49 archives across six modules and
   5,488 source files**, because OCCT's CMake pulls a dependency in whether or not
   its module is switched off. (5,488 is #2174's count from the object rules CMake
   generated for this configure. The 5,495 that stood here was taken with a pattern
   that could not match a source file name containing a dot and named only the `.cxx`
   and `.c` extensions; the wasm configure also drops two Apple-only `TKService`
   files the macOS one builds.)

   | Module | `BUILD_MODULE_*` | Toolkits built |
   |---|---|---|
   | FoundationClasses | ON | 2 |
   | ModelingData | ON | 4 |
   | ModelingAlgorithms | ON | 14 |
   | DataExchange | ON | 14 |
   | **ApplicationFramework** | **OFF** | **13** |
   | **Visualization** | **OFF** | **2** |

   `DataExchange`'s XCAF toolkits need `TKCAF`, `TKLCAF`, `TKCDF`, the
   `TKBin*`/`TKXml*`/`TKStd*` persistence set and `TKTObj`; those reach
   `TKService` and `TKV3d`. `TKV3d` alone is 203 source files. So the
   platform-gap surface, and the code the module size pays for, include 682 files
   from two modules the flags say are off. **Measured by #2174: those 682 need no
   platform guard at all.** The one file the whole set did not compile was in
   `TKDESTEP`, which is a module the flags do switch on, and #2266 closed it.

3. **Threading is a non-issue for us.** The bridge serialises all OCCT access
   through one `std::recursive_mutex`; single-threaded wasm satisfies that
   trivially, and TBB is already off.

## The central obstacle: two incompatible wasm ABIs

This is the fact that dominates the whole effort.

- **Official Swift-on-wasm** (upstream in Swift 6.1+, SDKs shipped from swift.org
  in 6.2/6.3) targets **`wasm32-unknown-wasip1`**, built against **wasi-sdk /
  wasi-libc**.
- **OCCT's only supported wasm path** is **Emscripten**
  (`wasm32-unknown-emscripten`, its own JS-based libc).
- These two are **not ABI-compatible and cannot be statically linked**, different
  libc constants (e.g. `O_CREAT`), struct layouts, and import shapes. Emscripten
  declined to align with WASI (wontfix, emscripten#9479). So you cannot drop an
  Emscripten-built `libOCCT.a` next to wasi-built Swift and link them.

Everything below is about how to bridge that gap.

## C++ exceptions on wasip1: what is proven (#2171)

The bridge answers a failed OCCT call by catching at the C boundary and returning a refusal, and
`check-throwing-calls.py` gates that. On `wasm32-unknown-wasip1` that contract **holds**, on
conditions that are now measured rather than assumed. The probe is
[`Scripts/repro/2171`](../Scripts/repro/2171), re-runnable as `Scripts/repro/2171/run.sh`, and its
measurement log is [that directory's README](../Scripts/repro/2171/README.md).

**Proven.** A failure type raised through a static `Raise` entry point is caught across separately
compiled targets by its own type, by reference to its base, and by `catch (...)`, which is the shape
every `OCCTBridge` function's outermost handler uses. A `std::out_of_range` raised inside libc++
itself is caught too, so the seam between the Swift SDK's no-exceptions C++ runtime and wasi-sdk's
exception-enabled one holds for a throw neither side of our code wrote. When the whole path carries
the flags, every destructor between the raise and the catch runs. setjmp and longjmp work in a
translation unit that also carries the exception flags.

**Three conditions, each of which fails silently if missed.**

| Condition | What happens without it |
|-----------|-------------------------|
| `WASM_CXX_EH_FLAGS` reaches **every** C++ translation unit, OCCT's included | The exception still propagates, but frames compiled without the flags skip their stack cleanup, and a `try`/`catch` written inside such a frame never fires. No error, no warning. |
| `-lc++abi -lunwind` from wasi-sdk's `eh` directory are on the link line | The link fails on `__cxa_throw` and seven more, which is at least loud |
| setjmp users are compiled `-mllvm -wasm-enable-sjlj` and linked `-lsetjmp` | The link fails on `setjmp` and `longjmp`; `-fwasm-exceptions` does nothing for them |

The first is the one that matters for OCCT, because OCCT does not only raise `Standard_Failure`, it
catches it internally to turn a failure into an `IsDone() == false`. Those handlers disappear with
no diagnostic if OCCT's CMake never receives the flags, and every OCCT frame between the raise and
the bridge leaks the `Handle`s and shapes it held. `Scripts/build-occt-wasm.sh` says nothing about
exceptions today; wiring the flags into `CMAKE_CXX_FLAGS` is the first thing #2172 has to do.

**Cost.** The same program with and without exceptions differs by about 200 KB, near enough
constant between `-O0` and `-Os`, so it is mostly the fixed cost of the exception runtime. The
per-function landing pads, which are the part that scales with OCCT, are not in that number.

**An uncaught exception is better off here than natively.** It leaves the module as a wasm exception
the host reports, rather than the uncatchable in-process failure of #345. The instance is still
unusable afterwards, so this changes the diagnostics and not the duty to catch at the bridge.

**Settled since, by #2174, which linked OCCT rather than a probe.** Two of the three things this
section listed as unknown have answers, and one of them is not the answer the question assumed.

- **The libc++ seam is not link-order dependent.** libc++ ABI-tags every header-inline symbol with
  `_LIBCPP_ODR_SIGNATURE`, which encodes whether exceptions are on, so the aborting
  `std::__throw_out_of_range` in WASI.sdk's prebuilt `libc++.a` is spelled `...B8nn210106...` and
  the throwing one our own compile emits is `...B8ne210106...`. They cannot resolve to each other
  at any link order. Measured, with the behavioural half to match: a `std::out_of_range` raised
  inside a 140 MB OCCT archive is caught.
- **`operator new` throws `std::bad_alloc`.** A 3.5 GB request under the wasm32 ceiling raises and
  the catch fires, so an OCCT allocation failure is a C++ exception the bridge can handle rather
  than a trap.
- `-lsetjmp` and `-lwasi-emulated-getpid` have now been on a link line; see
  [`Scripts/repro/2174/README.md`](../Scripts/repro/2174/README.md).

### The bridge is compiled as C++, not Objective-C++ (#2256)

The exception flags above cannot reach a bridge translation unit while it is compiled as
Objective-C++, because the pinned clang **crashes in WebAssembly instruction selection** on an
ordinary C++ `try`/`catch` in an Objective-C++ unit under `-fwasm-exceptions`. No Objective-C need
be present, and none is: clang gives any Objective-C++ unit the Objective-C++ personality function,
the wasm exception lowering only handles the C++ one, and what reaches the selector cannot be
selected. `-fno-objc-exceptions` does not help, no `-fobjc-runtime` choice helps, and
`-fobjc-runtime=macosx` is refused by the backend outright, so Objective-C cannot target this
triple at all.

The WASI build therefore compiles the bridge with `-x c++`. The 74 files are C++ already, so this
changes no semantics, and it changes nothing on Apple targets. It is the smaller of the two answers:
the other is renaming all 74 files to `.cpp`, which is arguably correct on its own merits and is
recorded in [`Scripts/repro/2256`](../Scripts/repro/2256/README.md) along with what would make it
worth doing.

That directory also carries the part that matters more than the crash. A **real** bridge
translation unit, compiled this way for `wasm32-unknown-wasip1`, linked and run, catches an OCCT
`Standard_ConstructionError` at its own outermost `catch (...)`; the same file with the exception
flags dropped compiles clean and never catches, which is #2171's silent failure reproduced through
the bridge rather than through a probe.

The upstream crash is [llvm/llvm-project#123659](https://github.com/llvm/llvm-project/issues/123659)
in its Objective-C form; the C++-in-`.mm` form measured here is not covered by it.

## What breaks in the Swift layer

**Most of this section was a forecast and #2175 replaced it with measurements.** The
whole Swift layer, all 230 files of `Sources/OCCTSwift`, compiles for
`wasm32-unknown-wasip1` and runs. What actually broke was not what this section
expected.

The Foundation numbers, re-derived 2026-09-25: **219 of the 230 files**
`import Foundation`, not ~70; `URLSession` appears **zero** times, so the audit this
section asked to re-verify is done and clean; `FileManager` appears **three** times,
not eight, and one of those is the `temporaryDirectory` that `Exporter.stepData` and
its siblings write to.

- `Data` / `URL` / `Date` / `JSONEncoder` work. Nothing was conditionalised for them.
- **`FileManager` file I/O works against a preopened directory, unchanged.** The
  path-taking STEP entry points need **no** virtual-filesystem shim inside this
  package: the host preopens a directory and the existing API reads and writes in it.
  This section called that "the single biggest API-surface task after linking" and it
  is not a task at all; see Phase 0's file-I/O finding and Phase 3 below.
- **What did break, and neither was on this list:**
  - **`import simd`, in 196 of the 230 files.** Apple's `simd` is part of the Apple
    SDKs and has no wasm build. Answered with a WASI-only target named `simd`
    (`Sources/WASICompat/simd`), which leaves all 196 files untouched; what to do
    properly is #2759.
  - **`Shape.isSelfIntersecting(hardTimeout:)`**, the only Dispatch user in the
    package. Its contract is a hard deadline enforced by a second thread, and
    wasip1 non-threads has one, so it is `#if !os(WASI)`. The API decision is #2760.
- **4 GB single-heap ceiling** (wasm32; Swift does not target wasm64) caps model size.
- **Size is the real API-surface problem, and it is Foundation's rather than OCCT's.**
  A SwiftWasm module that does nothing but print a path is 13.11 MB brotli, 37.6 MB of
  it internationalisation **data**, against a 5 MB target. Moving files to
  `FoundationEssentials` is the first lever; #2761 holds the numbers.

## Three paths to one wasm module

The goal requires Swift and OCCT in one module with a **shared ABI**. There were
three ways to get there, and **#2175 settled it: the answer is B**, by the only
argument that settles a question like this, which is that B linked and ran. A and C
were never attempted, and the table is kept because a reader who hits a wall in B
is entitled to know what was passed over and why.

| Path | Approach | Trade-off | Maturity (June 2026) |
|------|----------|-----------|----------------------|
| **A. Swift-on-Emscripten** | Compile Swift against emsdk libc so it matches an Emscripten-built OCCT. Reuse a prebuilt OCCT 8.0.0 wasm (e.g. `andymai/occt-wasm`). | Most direct *if* it works; reuses existing OCCT wasm builds. | **Experimental**. March 2026 Swift pitch + Embedded-Swift/emsdk PoC; no packaged toolchain. |
| **B. OCCT-on-wasi-sdk** | Port OCCT to build with wasi-sdk so it matches standard SwiftWasm. | Standard, well-supported Swift side; OCCT side is uncharted (OCCT assumes POSIX/threads). | OCCT headless core has no hard Emscripten dep, but no known wasi-sdk port exists. |
| **C. Two components** | Keep OCCT (Emscripten) and Swift (wasi) as separate wasm modules; bridge via the **Component Model / WIT** at a typed interface, not the C ABI. | Avoids ABI linking entirely; adds a serialization boundary across every call. | WASI 0.2 shipped; 0.3 landing 2026. Heaviest runtime model. |

The toolchain pinned below is **path B's**: it is the one the bounded work items
#2169 through #2175 attempted, and #2175 was the go/no-go that could have sent the
question back to A or C. It did not. The ABI seam this table exists to work around
holds: the Swift SDK's no-exceptions C++ runtime and wasi-sdk's exception-enabled one
coexist in one module, because libc++ ABI-tags every header-inline symbol with whether
exceptions are on and the two definitions therefore cannot collide (#2174), and an OCCT
raise crosses that seam into a bridge `catch` and out to Swift as a refusal (#2175).

## Pinned toolchain

Every version is held in [`Scripts/wasm-toolchain-versions.txt`](../Scripts/wasm-toolchain-versions.txt)
and read from there by the scripts. The table below names them; it does not
restate the URLs or checksums, which would be a copy with no update path.

| Piece | Pin | Why it is pinned there |
|-------|-----|------------------------|
| Swift toolchain | 6.4.0-RELEASE, **from swift.org, not Xcode** | Xcode's toolchain has no `wasm-ld` and no `swift-autolink-extract`, so it compiles for wasm and then cannot link. The swift.org build of the same version carries both, plus the wasm32 compiler-rt builtins and the runtime. |
| Swift SDK | `swift-6.4.0-RELEASE_wasm`, target `wasm32-unknown-wasip1` | Installed by URL and checksum, so the SDK cannot drift. Non-threads, by the decision in #2169: the threads variant left swift.org at 6.3 and a shared-memory module would force COOP/COEP cross-origin isolation on the browser consumer. |
| wasi-sdk | 34.0, checksummed per host | Supplies the one thing the Swift SDK's sysroot lacks, an exception-enabled C++ runtime. Not a second compiler. |
| Runtime | `wasmkit`, shipped inside the pinned Swift toolchain | Nothing extra to install, and it cannot drift away from the toolchain that produced the module. |

### The one command

```bash
Scripts/install-wasm-toolchain.sh
```

It reads the pins, installs the Swift SDK by checksum, downloads and verifies
wasi-sdk into `Libraries/`, then builds and runs
[`Scripts/repro/2169/standalone`](../Scripts/repro/2169), a Swift target calling a
C++ target over a flat C surface, which is the shape this package has. It prints
what the module printed. `--print-plan` resolves everything and downloads
nothing; `--verify` skips straight to the build and run.

The one step it will not take is installing the swift.org toolchain itself, since
that wants an administrator on macOS and an unpack location on Linux. It prints
the exact command and stops.

By hand, the build and run are:

```bash
export TOOLCHAINS=swift        # macOS: select the swift.org toolchain over Xcode's
swift build --swift-sdk swift-6.4.0-RELEASE_wasm --triple wasm32-unknown-wasip1
wasmkit run .build/out/Products/Debug-webassembly-wasm32/<product>.wasm
```

Both parts of the `swift build` invocation are load-bearing. The artifact bundle
carries an Embedded Swift SDK alongside the wasip1 one, so naming only the triple
is ambiguous and SwiftPM refuses it.

### What wasi-sdk is for

The Swift SDK's artifact bundle already contains a complete WASI sysroot,
including libc++ and its headers, and the swift.org clang compiles and links C++
against it unaided. Throwing C++ is the exception: the bundled `libc++abi.a` is
the no-exceptions build, defines no `__cxa_throw`, and the link fails. wasi-sdk
ships its C++ runtime twice, under `eh` and `noeh`, and linking the `eh` flavour's
`libc++abi` and `libunwind` is what makes a throwing target work. OCCT throws
`Standard_Failure` pervasively, so this is not optional for us.

### What the runtime choice costs

wasmkit implements the standardised exception encoding and rejects the legacy one
with `Illegal opcode: [6]`, so C++ compiled with `-fwasm-exceptions` also needs
`-mllvm -wasm-use-legacy-eh=false`. Both flags are pinned together as
`WASM_CXX_EH_FLAGS`, because dropping the second one produces a module that builds
cleanly and then cannot run.

### Which sysroot compiles OCCT, and why it is not wasi-sdk's

Settled by #2172. **OCCT is compiled against the Swift SDK's `WASI.sdk`, with the
swift.org toolchain's clang.** wasi-sdk supplies the `eh` runtime described above
and compiles nothing.

Both sysroots can compile for `wasm32-wasip1`, and they disagree about two things:

| | Swift SDK `WASI.sdk` | wasi-sdk 34.0 `wasm32-wasip1` |
|---|---|---|
| `_LIBCPP_HAS_THREADS` | 0 | 1, in both `eh` and `noeh` |
| libc++ `_LIBCPP_VERSION` | 210106, LLVM 21 | LLVM 23.1.0 |

The threads row is why the build force-includes the shim from #2170. The version
row is the stronger argument and is the one that decides it: two libc++ major
releases apart means two implementations under one set of mangled names in one
module, and the Swift half of that module links `WASI.sdk`'s copy whatever OCCT
was built against. The bridge's flat C ABI keeps C++ types out of Swift's way and
does nothing about which definition the linker picks.

The mechanism is [`Scripts/cmake/wasi-swift-sdk.cmake`](../Scripts/cmake/wasi-swift-sdk.cmake),
a toolchain file this repo owns. Before #2172 the build script reached for a
`swift-wasi-sdk.cmake` that exists in neither install and fell through to
wasi-sdk's own `wasi-sdk-p1.cmake`, so wasi-sdk's compiler and default sysroot
were what always ran.

### The exception flags reach OCCT's own compile

`Scripts/build-occt-wasm.sh` puts `WASM_CXX_EH_FLAGS` and `-mllvm -wasm-enable-sjlj`
into `CMAKE_CXX_FLAGS` for the whole OCCT build, and asserts before CMake starts
that they produce a catch handler. #2171 measured that a translation unit missing
them still lets an exception propagate, while its stack cleanup never runs and a
`try`/`catch` inside it never fires, with no diagnostic. OCCT catches
`Standard_Failure` internally to set `IsDone() == false`, so that is the
difference between a kernel that reports failures and one that quietly stops.

`setjmp` is a separate mechanism needing a separate flag and `-lsetjmp` at link.
It is not hypothetical: OCCT's CMake defines `OCC_CONVERT_SIGNALS` on every
non-Windows target, so `OCC_CATCH_SIGNALS` expands to a real `setjmp` inside OCCT,
and 6 of `TKernel`'s 127 objects carry a lowered pair.

### What this does not settle

The verification package links Swift built against the Swift SDK's no-exceptions
C++ runtime together with a C++ target using wasi-sdk's exception-enabled one.
That holds for one file. #2172 took it as far as compiling and archiving one
OCCT toolkit, 119 of `TKernel`'s 127 source files; #2173 closed the eight platform
gaps behind the other eight and took it to **127 of 127**, archived as a real
`libTKernel.a` under `--require-complete`. Neither linked any of it.

**#2174 did, and OCCT runs.** A C++ `main` over an archive of every object the
49-toolkit build produces constructs a `Handle`, builds a box, measures its volume,
meshes it, makes OCCT raise a `Standard_Failure` from inside its own compiled code
and catches it, under `wasmkit`. With no Swift and no bridge, deliberately, so that
a failure would be a statement about the archive rather than about the manifest.
That settles the libc++ seam, `operator new` and
`-lwasi-emulated-getpid`. It also settled `-lsetjmp`, and **#2175 unsettled that one
again in the other direction**: `Scripts/build-occt-wasm.sh` now passes
`-UOCC_CONVERT_SIGNALS`, so no OCCT function carries a lowered `setjmp` at all and the
clean archive has zero references to `__wasm_setjmp`. Read #2174's `libs` case with
that in mind, and see #2758.

**#2175 closed the Swift half.** Five calls through the OCCTSwift public API, over the
bridge, over OCCT, in one module, including two that must fail and do. See
[Phase 0](#phase-0-decision-spike-done-and-the-verdict-is-go-with-conditions).

What remains open is now a short list rather than the shape of the thing: nothing has
run in a browser (#2052), no test target has been built for wasm, there is no
numerical parity check against the Apple kernel, and the module is 26.98 MB brotli
against a 5 MB target (#2761).

The measurement logs are
[`Scripts/repro/2169/README.md`](../Scripts/repro/2169/README.md),
[`Scripts/repro/2172/README.md`](../Scripts/repro/2172/README.md),
[`Scripts/repro/2173/README.md`](../Scripts/repro/2173/README.md),
[`Scripts/repro/2174/README.md`](../Scripts/repro/2174/README.md) and
[`Scripts/repro/2175/README.md`](../Scripts/repro/2175/README.md).

## How a wasm application consumes this package (#2048)

The consumer is a SwiftWasm application using JavaScriptKit, and it reaches OCCTSwift with
`.package(url:, from: "…")`. That single detail decides the whole WASI configuration, because
**SwiftPM refuses to build any package that uses `.unsafeFlags` once it is resolved by version**.

Measured in [`Scripts/repro/2048/`](../Scripts/repro/2048/README.md), which puts OCCTSwift's target
shape and none of its content through a real dependency graph, and therefore needs no OCCT:

| How the dependency is declared | `.unsafeFlags` in it |
|---|---|
| `.package(path:)` | accepted |
| `.package(url:, branch:)` | accepted |
| `.package(url:, from: "1.0.0")` | **refused** |

A `.when(platforms: [.wasi])` condition does not exempt it, so the flags cannot be hidden behind a
condition. The restriction is on the requirement, not the flag.

### Where each flag lives now

`PackageDescription` offers `headerSearchPath`, `define` and four warning controls for C and C++,
and `linkedLibrary` / `linkedFramework` for the linker. That list is the whole answer to what can
be expressed safely.

**In the manifest, because they have a safe spelling**: every library NAME
(`-lOCCT-wasm`, `-lc++`, `-lc++abi`, `-lunwind`, `-lsetjmp`, `-lwasi-emulated-getpid`) as
`.linkedLibrary`, and every define and header search path.

**In a toolset the consumer passes**, because nothing else can carry them:
`-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false`, `-mllvm -wasm-enable-sjlj`, the `-L` into
wasi-sdk's `lib/wasm32-wasip1/eh`, and the `-L` for `libOCCT-wasm.a`.
`Scripts/make-wasi-toolset.py` writes one, reading the exception flags from
`Scripts/wasm-toolchain-versions.txt` so a toolset cannot drift away from the flags the kernel was
built with:

```bash
python3 Scripts/make-wasi-toolset.py --wasi-sdk "$WASI_SDK_PREFIX" \
    --occt-lib-dir <where libOCCT-wasm.a is> -o toolset.json
OCCTSWIFT_WASI=1 TOOLCHAINS=swift swift build --toolset toolset.json \
    --swift-sdk swift-6.4.0-RELEASE_wasm --triple wasm32-unknown-wasip1
```

Only `-lunwind` and the kernel archive actually need a `-L`. `libsetjmp.a` and
`libwasi-emulated-getpid.a` are in the Swift SDK's own `WASI.sdk`, which is already the link's
sysroot. `libc++abi.a` is there too, which is worse than absent: it is the no-exceptions flavour,
so the `-L` into wasi-sdk's `eh` directory has to **precede** the sysroot, not merely be present.

**In the source, because a guarded `#include` needs no setting at all**: the threading shim. A
bridge source that includes `wasi-std-threading.hpp` under `#if defined(__wasi__)` needs only the
header search path the manifest already has. The toolset's `-include` works too, and was measured
to; the `#include` is preferred because a consumer who forgets a toolset entry gets six errors
naming `std::mutex`, while a consumer who forgets nothing cannot forget this.

### The alternatives, and why not

- **A SwiftPM build plugin** returns `[Command]`, each a process producing files. There is no API
  by which a plugin changes another target's compiler flags.
- **A prebuilt binary artefact.** `binaryTarget` takes an `xcframework`, which is Apple-only, or an
  `artifactbundle`, which holds executables. Neither is a static library for a wasm triple.
- **More in `Scripts/cmake/wasi-swift-sdk.cmake`.** That file compiles OCCT and reaches nothing
  SwiftPM builds, so it cannot carry a flag the bridge or the link needs.

### How far it gets today: all the way (#2175)

With the manifest above and a generated toolset, SwiftPM builds the `OCCT` target, compiles all 74
files of `Sources/OCCTBridge/src` as C++, compiles all 230 files of `Sources/OCCTSwift`, links
against `libOCCT-wasm.a` and produces a module that runs. `Scripts/repro/2175/spike` is the
consumer that does it, and `Scripts/repro/2175/run.sh build` is the command.

The three things this section listed as blocking are closed:

- **`libOCCT-wasm.a`** exists, from #2174 and #2266. `Scripts/build-occt-wasm.sh` writes it and
  `Libraries/occt-headers-wasm/`.
- **The bridge header's missing includes.** #2256 added `<stdint.h>` for the 19
  `unknown type name 'int32_t'` errors. #2175 added **`<stdbool.h>`** for the 1,198
  `unknown type name 'bool'` errors that appear only when Swift builds the same headers as a clang
  module in C, across 14 of this directory's 18 headers. Both have the same cause: #2049 guarded
  `#import <Foundation/Foundation.h>` out on WASI, and Foundation was what transitively supplied
  each of them.
- **The bridge's `.mm` files carrying `-fwasm-exceptions`.** #2256 settled it by compiling them as
  C++ with `-x c++` from the toolset; the clang crash in the `WebAssembly Exception Information`
  pass is real and is avoided rather than fixed. Building the bridge without the flag was never an
  alternative: that is exactly the configuration
  [#2171](https://github.com/SecondMouseAU/OCCTSwift/issues/2171) measured, where every outermost
  `catch (...)` stops firing and nothing says so.

One thing the manifest **did** claim that nothing used, found by #2175: it carries
`.headerSearchPath("../../Scripts/wasm-shims")` and a comment saying the bridge reaches the
threading shim by a guarded `#include`, and no bridge source included it. It does now, in
`OCCTBridge_Internal.h` under `#if defined(__wasi__)`, which is where the `std::mutex` declarations
that need it are.


## Plan

### Phase 0. Decision spike: DONE, and the verdict is GO WITH CONDITIONS

**The gate is closed.** #2175 linked and ran Swift, over the OCCTSwift public API, over the C
bridge, over OCCT, in one `wasm32-unknown-wasip1` module under the pinned `wasmkit`, on
2026-09-25. The measurement log is [`Scripts/repro/2175/README.md`](../Scripts/repro/2175/README.md)
and `Scripts/repro/2175/run.sh` reproduces every number below. This section is the memo the issue
asked for; the numbered plan it replaces is at the end of it, struck through, because what it asked
for was done.

**Path B is the path.** It is not a preference: it is the one that linked and ran. A and C were
never attempted and are now moot, because B answers the question they existed to answer. The ABI
seam, which this doc called "the one thing that can kill the whole idea", is settled: the Swift
SDK's no-exceptions C++ runtime and wasi-sdk's exception-enabled one coexist in one 141 MB module,
for the reason #2174 found (libc++ ABI-tags every header-inline symbol with whether exceptions are
on, so the two definitions cannot collide), and OCCT raises across the seam into a bridge `catch`
and out to Swift.

#### Which calls ran, and what they returned

Five calls, through the published Swift surface and not through the bridge, because the question is
whether a SwiftWasm application consuming this package can do real CAD work.

| Call | Swift entry point | Result |
|---|---|---|
| box | `Shape.box(width:height:depth:)` | volume **6000.0**, 6 faces, 12 edges, 8 vertices |
| fuse | `Shape.fused(with:tolerance:)` | volume **1875.0** on two 10-cubes overlapping in one octant, against 1000 + 1000 − 125 |
| STEP export | `Exporter.writeSTEP(shape:to:name:)` | **36,189 bytes**, 806 entities, header `ISO-10303-21;` |
| STEP import | `Shape.load(fromPath:)` | volume **1875.0**, 12 faces, against the written shape's own numbers |
| must fail, a raise | `Shape.box(width: 0, height: 0, depth: 0)` | **nil**, and one diagnostic record: `OCCTShapeCreateBox: Standard_DomainError` |
| must fail, OCCT's own handler | `Shape.load(fromPath:)` on a malformed file | throws `ImportError.readFailed(status: IFSelect_RetFail)`, and **zero** bridge records |

**The must-fail call is the one that makes the other four mean anything**, and it is why this memo
can say "go". #2171 measured that a translation unit built without `WASM_CXX_EH_FLAGS` returns
correct boxes, correct fuses and correct STEP files and answers every error by trapping the module,
with no diagnostic anywhere. So:

- `Shape.box(0, 0, 0)` reaches `BRepPrimAPI_MakeBox`, which throws `Standard_DomainError` from a
  `TKPrim` object of the archive. The unwinder crosses from OCCT into the bridge's outermost
  `catch (...)`, and Swift gets `nil`. `nil` alone would prove nothing, so the assertion is on the
  diagnostic channel (#1161/#2077): exactly one record, classified as an OCCT failure, carrying
  `Standard_Failure::ExceptionType()`. **The bridge's error contract holds on wasm.**
- the malformed STEP read is the mirror: `IFSelect_WorkSession::ReadFile` catches inside OCCT's own
  translation units and returns `IFSelect_RetFail`, so the refusal reaches Swift **and the bridge's
  capture stays empty**. That is OCCT's internal handlers still working, which is the half that
  disappears silently if the exception flags miss a file.

#### Module size, against the 5 MB target

The target is a target and not a gate, and it did not change the verdict. The figures carry the
Swift runtime, Foundation, the Swift layer, the bridge and whatever of OCCT six calls reach.

| Module | Uncompressed | `gzip -9` | `brotli -q 11` |
|---|---|---|---|
| `HelloPlain`, the Swift runtime alone | 7,159,728 | 1,899,494 | 1,352,699 |
| `HelloFoundation`, + Foundation | 60,380,095 | 20,060,965 | **13,112,239** |
| **`OCCTWasmSpike`**, + the bridge + OCCT | **141,861,273** | 41,110,844 | **26,976,003** |

**Foundation is already 2.6x over the target before any of this package is in the module.** By wasm
section, `HelloFoundation` is 15,828,699 bytes of `CODE` and **37,615,734 bytes of `DATA`**, and
stripping debug information moves 4,635 bytes of it, so that is internationalisation data rather
than anything a release pipeline drops. `Sources/OCCTSwift` has 219 files that `import Foundation`.

So the size question is not primarily an OCCT question, and no size work of any kind has been tried:
no `wasm-opt`, no `FoundationEssentials`, no `-Osize`, no link-time inspection. That is #2761, which
holds the numbers and the levers.

#### Host imports: OCCT adds none

A linked wasip1 module's host imports are its remaining undefined symbols, each named
`__imported_wasi_snapshot_preview1_<field>`.

| Module | `wasi_snapshot_preview1` | from any other module |
|---|---|---|
| a hello-world C program (#2174) | 5 | 0 |
| `probe-step.wasm`, C++ over OCCT (#2266) | 16 | 0 |
| `HelloPlain`, the Swift runtime alone | 14 | 0 |
| `HelloFoundation`, + Foundation | **34** | 0 |
| **`OCCTWasmSpike`**, + the bridge + OCCT | **34** | 0 |

**The set difference is empty.** A host that can run a SwiftWasm app using Foundation's file APIs
can run this module with no additional host function of any kind, and nothing is imported from any
module other than `wasi_snapshot_preview1`. That is the answer #2052 was waiting for.

#### File I/O: the path-taking API needs no change

This was expected to be the awkward part and it is not. `Exporter.writeSTEP` and
`Shape.load(fromPath:)` work unchanged against a directory the host preopens. The pattern is the
one CascadeStudio (MIT, `zalo/CascadeStudio`) uses in production under Emscripten: write the bytes
into the virtual filesystem, call the unchanged path-taking OCCT entry point, read the bytes back,
unlink. Emscripten gives you MEMFS at `/`; WASI gives you nothing until the host preopens, and the
equivalent is `@bjorn3/browser_wasi_shim`'s `PreopenDirectory(name, entries)` of in-memory `File`s,
passed in the `fds` array a SwiftWasm app already builds for the Swift runtime.

**No bytes-in/bytes-out variant of the OCCT or OCCTSwift API is needed.** The adaptation is
host-side. A bytes-**out** convenience already exists and already works:
`Exporter.stepData(shape:name:)` returned the same 36,189 bytes once `/tmp` was preopened, because
that is what `FileManager.default.temporaryDirectory` resolves to here. There is no bytes-**in**
equivalent and there does not need to be.

**Measured under `wasmkit`, where a preopen is a real directory on disk. Inferred for the browser**,
where it is in-memory, from the shim's documented behaviour and from the import list above being
the same either way. Nothing here has run in a browser; that is #2052.

#### Blockers hit

| # | Blocker | State |
|---|---|---|
| [#2757](https://github.com/SecondMouseAU/OCCTSwift/issues/2757) | a function carrying both a lowered `setjmp` and wasm exceptions emits an **invalid** `br_table`, and the module dies at the first OCCT call | **fixed here**, with `-UOCC_CONVERT_SIGNALS`; the upstream LLVM report still needs a reduction |
| [#2758](https://github.com/SecondMouseAU/OCCTSwift/issues/2758) | `-mllvm -wasm-enable-sjlj` and `-lsetjmp` are now inert, and four places still call them load-bearing | open, cosmetic |
| [#2759](https://github.com/SecondMouseAU/OCCTSwift/issues/2759) | 196 of 230 Swift files `import simd`, which does not exist on wasm | **worked around here** with a WASI-only `simd` target; the shape of the real answer is open |
| [#2760](https://github.com/SecondMouseAU/OCCTSwift/issues/2760) | `Shape.isSelfIntersecting(hardTimeout:)` needs a second thread, so it cannot exist on wasip1 non-threads | **removed here** under `#if !os(WASI)`; the API decision is open |
| [#2761](https://github.com/SecondMouseAU/OCCTSwift/issues/2761) | module size, and Foundation being 2.6x the target on its own | open, and explicitly not a gate |

Two more were fixed in place and need no issue: `OCCTBridge.h` needed `<stdbool.h>` as well as the
`<stdint.h>` #2256 added (1,198 `unknown type name 'bool'` errors across 14 of the 18 bridge
headers, invisible to every `.mm` because they compile as C++), and no bridge source included the
threading shim although `Package.swift` said the bridge relied on a guarded `#include` of it.

#### The go/no-go

**GO, with four conditions.** The evidence for "go" is that the thing this whole effort exists to
prove has been done end to end: the published Swift API, on the real kernel, returning correct
geometry and refusing correctly, with no host function beyond what a SwiftWasm app already needs
and no change to the path-taking file API. The two failure paths are the load-bearing part, and
both behaved.

The conditions are things that are **not** proven and that a later phase must not assume:

1. **Size is unaddressed and is the largest open risk to the product goal** (#2761). 26.98 MB brotli is
   not shippable to a browser, 13.11 MB of it is Foundation before OCCT is involved, and nothing has
   been tried. Phase 2 should start with `FoundationEssentials`, not finish with it.
2. **Nothing has run in a browser** (#2052). Everything here is `wasmkit` on macOS. The browser
   filesystem shape is inferred, not measured, and the import list is the reason to expect it to
   hold rather than a proof that it does.
3. **Six calls are not a test suite.** No per-domain test target has been built for wasm, let alone
   run, and there is no numerical parity check against the Apple kernel. Phase 4 is where that
   stops being true, and it should come earlier in the order than "after the API work" if the
   Phase 2 changes are going to be trusted.
4. **The Swift-layer surface now differs by platform** (#2759, #2760) and both differences were
   made by this spike under time pressure. Neither is settled API design; both need deciding before
   anything downstream depends on either.

A **no-go** would have looked like: the module not linking, the raise trapping instead of arriving
as `nil`, OCCT's internal handlers silently gone, or the path-taking API needing to be replaced.
None of those happened. The one thing that did stop the module dead, #2757, is fixed by one flag
and the fix is the semantically correct setting for this target rather than a workaround.

<details>
<summary>The original Phase 0 plan, for the record</summary>

1. ~~Stand up a SwiftWasm toolchain (swift.org Swift SDK for WebAssembly) and confirm a trivial
   `swift build --swift-sdk … wasm` runs.~~ Done in #2169.
2. ~~Pick 3 representative bridge functions, plus a fourth that must fail.~~ Done, and the fourth
   became two: a raise that crosses OCCT into the bridge, and a failure OCCT handles internally.
3. ~~Attempt each path far enough to link and call those functions from Swift.~~ Path B linked and
   ran; A and C were not attempted and are moot.
4. ~~Deliverable: a one-page decision memo recording which path linked and ran, binary size, and
   blockers hit.~~ This section.

> ~~Stop here and reassess if no path links the spike functions. That is the go/no-go gate.~~

</details>

### Phase 1. Build pipeline

- ~~Add a wasm target to `build-occt.sh` (or a sibling `build-occt-wasm.sh`).~~ Done:
  `Scripts/build-occt-wasm.sh` builds all 49 toolkits and 5,488 source files, and
  packages `Libraries/libOCCT-wasm.a` and `Libraries/occt-headers-wasm/` (#2174, #2266).
- ~~Drop or guard the bridge header's `#import <Foundation/Foundation.h>`.~~ Done in
  #2049, with `<stdint.h>` (#2256) and `<stdbool.h>` (#2175) restored behind it.
- **Still open: distribution.** `xcframework` packaging is Apple-only, so wasm needs
  its own path (a release-asset `.a` + headers, consumed through `.linkedLibrary` plus
  a consumer-side toolset; there is no `binaryTarget` for wasm, and `unsafeFlags` is
  not available to a package consumed by version, see
  [How a wasm application consumes this package](#how-a-wasm-application-consumes-this-package-2048)).
  Nothing ships the 153 MB archive or the 7,160-file header tree yet, and both are
  gitignored, so a versioned consumer today resolves a tree that contains neither.
  #2175's spike reaches them through a **path** dependency and therefore does not
  exercise this.

### Phase 2. Swift layer portability

The whole layer compiles and runs as of #2175. What is left is deciding what the wasm
API surface should be, rather than making it build.

- ~~Replace any `URLSession`/socket use.~~ Re-verified 2026-09-25: **zero** occurrences
  in `Sources/OCCTSwift`.
- ~~Conditionalise the Foundation surface.~~ Not needed to build. `Data`, `URL`, `Date`
  and `FileManager` all work.
- **`import simd`, in 196 of 230 files** (#2759). A WASI-only target named `simd`
  stands in today; the real answer is probably removing the gratuitous imports.
- **`Shape.isSelfIntersecting(hardTimeout:)`** is `#if !os(WASI)` (#2760), and it is
  the first case of a class: any API whose contract needs a second thread.
- **`FoundationEssentials` instead of `Foundation`** wherever a file only uses `Data`,
  `URL`, `Date` or `JSONEncoder`, which is the biggest single lever on module size
  (#2761). 219 of 230 files `import Foundation` today.

### Phase 3. File I/O: smaller than it looked

**#2175 removed the premise of this phase.** The path-taking STEP entry points work
unchanged against a preopened directory, and `Exporter.stepData` already returns bytes
by writing to `FileManager.default.temporaryDirectory` and reading back, which works
as soon as the host preopens that directory. No MEMFS shim, no bytes-in/bytes-out
variant of the OCCT or OCCTSwift API, no "largest API-surface task".

What is left is host-side and belongs with #2052: the browser shim's
`PreopenDirectory` of in-memory `File`s, and a documented recipe for handing bytes in
and getting them out. That has not been run in a browser; see Phase 0's file-I/O
finding for exactly what is measured and what is inferred.

### Phase 4. Test + CI

- A wasm test path (the pinned `wasmkit`, or a headless browser runner) for a **subset** of the
  per-domain suites. Full parity is unrealistic initially; target the modeling +
  IO domains first.
- A GitHub Actions matrix entry that builds the wasm slice and runs the subset.
- **Bring this forward.** #2175 ran six calls and no test target, and Phase 2's
  remaining work changes the Swift layer's API surface. Changing an API surface with
  no wasm test coverage is how the third condition on Phase 0's GO gets violated.

### Phase 5. Consumer validation

- A minimal SwiftWasm sample app (JavaScriptKit) that imports OCCTSwift, builds a
  box, fuses two shapes, and exports STEP, proving the goal end to end.
- `Scripts/repro/2175/spike` is that app with `print` in place of JavaScriptKit and
  `wasmkit` in place of a browser. What Phase 5 adds is the browser and the bytes
  crossing into JavaScript.

## Effort & risk

- **Phase 0 (spike): done**, #2169 through #2175 and #2266, and its verdict is GO with
  four conditions. It cost more than the "~1 week" forecast here and it found five
  defects in merged code plus one codegen defect that no C++-only probe could reach,
  which is what the money bought.
- **Phases 1 to 5:** weeks-to-months. The path-dependence this section warned about is
  gone with the path choice; what replaces it as the dominant risk is **module size**
  (#2761), which is largely Foundation's rather than OCCT's, and which no phase has an
  owner for yet.

This is a **porting project, not a recompile**. The existing arm64 xcframework is
the wrong architecture/libc/libc++ and is unusable on wasm.

## Prior art

- **`andymai/occt-wasm`**: actively maintained, tracks **OCCT 8.0.0** (the exact
  GA this repo pins), built with emsdk, ~4.5 MB brotli. It was the strongest candidate
  OCCT-side input for Path A, which was not taken; its brotli figure is still the only
  published number this effort's own sizes can be read against.
  <https://github.com/andymai/occt-wasm>
- **CascadeStudio** (`zalo/CascadeStudio`, MIT): a browser CAD app over
  opencascade.js. Its `packages/cascade-core/src/worker/FileUtils.js` is the prior art
  for #2175's file-I/O finding: write bytes into the virtual filesystem, call the
  unchanged path-taking OCCT entry point, read the bytes back, unlink. The pattern is
  what is useful, not the code. <https://github.com/zalo/CascadeStudio>
- **opencascade.js** (donalffons), older JS/Embind port, stale at OCCT 7.4.0p1.
  <https://github.com/donalffons/opencascade.js>
- **OCCT `samples/webgl`**: Open Cascade's in-tree Emscripten reference build.

## Key references

- Swift SDKs for WebAssembly, <https://www.swift.org/documentation/articles/wasm-getting-started.html>
- `swiftlang/swift` `docs/WebAssembly.md`, triples, wasi-sdk linking, no dynamic linking
- Swift for Wasm, December 2025 updates, <https://forums.swift.org/t/swift-for-wasm-december-2025-updates/83778>
- C++ interoperability status, <https://www.swift.org/documentation/cxx-interop/status/>
- Swift + Emscripten pitch, <https://forums.swift.org/t/using-swiftpm-with-emscripten/84783>
- Swift on Emscripten libc (experiment), <https://forums.swift.org/t/emsdk-libc-instead-of-wasi/79361>
- wasi-sdk vs emscripten ABI, <https://github.com/WebAssembly/wasi-sdk/issues/222>, <https://github.com/emscripten-core/emscripten/issues/9479>
- Component Model, <https://component-model.bytecodealliance.org/>

## Relationship to other docs

- [`platform-expansion.md`](platform-expansion.md), the Linux/Windows/Android
  review. Wasm is a separate axis (different ABI problem) and is tracked here.
- The bridge being pure-C++/C-linkage (verified clean) is a prerequisite that
  benefits any non-Apple port, wasm included.
