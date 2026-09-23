---
nav_exclude: true
search_exclude: true
---

# WebAssembly feasibility & plan

This doc captures the analysis of building OCCTSwift for WebAssembly so that the
**OCCTSwift Swift API can be reused inside a SwiftWasm app** (e.g. a browser app
driven by JavaScriptKit, or a server-side wasm runtime). Written June 2026 as a
forward plan. The toolchain is now pinned and has been run end to end, see
[Pinned toolchain](#pinned-toolchain), and one OCCT toolkit compiles and archives
for `wasm32-unknown-wasip1`. **Nothing containing OCCT has been linked**, which is
the line every claim below is measured against.

The goal is fixed. The *path* to reach it is deliberately left open, see
[Three paths](#three-paths-to-one-wasm-module). The path choice is the **output of
the decision spike** (Phase 0 below), not a premise of this plan.

## Goal

Compile the existing Swift public API (`Shape`, `Wire`, `Surface`, …) → the C bridge
→ OCCT, all the way down to a single wasm module that a SwiftWasm application can
call. The consumer is **Swift**, not JavaScript, that is the only thing that
justifies this work, because OCCT-in-the-browser already exists for JS consumers
(see [Prior art](#prior-art)).

## What's already in our favour

Two structural facts make this more tractable than the `platform-expansion.md`
(Linux/Windows/Android) review assumed:

1. **The bridge is already wasm-shaped.** Despite the `.mm` extension, the 17
   bridge files contain **zero Objective-C runtime**, no `NSString`, `NSObject`,
   `@try`, `@autoreleasepool`. It is pure C++ with a flat C-linkage surface
   (`double` / `int32_t` / `const char*` / `bool` / opaque `OCCT*Ref` pointers).
   The only ObjC touch is one `#import <Foundation/Foundation.h>` in the header,
   which is removable. A flat C ABI is exactly the recommended seam for
   Swift-on-wasm. *(Note: this supersedes the stale "57k-line .mm, audit for
   ObjC-isms" claim in `platform-expansion.md`, the bridge has since been split
   into per-area files and verified clean.)*

2. **OCCT is already configured headless.** `build-occt.sh` ships
   Visualization / OpenGL / GLES / FreeType / TBB / VTK / Draw all **OFF**; only
   FoundationClasses, ModelingData, ModelingAlgorithms, DataExchange + RapidJSON
   are ON. That is precisely the subset that ports to wasm (no GL context, no
   native threading).

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

**Not established.** None of this has met OCCT. The probe's largest object is a few kilobytes,
the libc++ seam rests on weak symbol resolution that a larger link could resolve the other way, and
`operator new` and `std::bad_alloc` under the 4 GB ceiling were not probed. Those move to #2172,
the first OCCT compile, and #2174, the full library.

## What breaks in the Swift layer

The Swift API leans on Foundation harder than the bridge does: **~70 files**
`import Foundation`, ~128 `URL`, ~35 `Data`, 8 `FileManager` uses.

- `Data` / `URL` / `Date` / `JSONEncoder` work via **FoundationEssentials** on wasm.
- **`URLSession` is unavailable** on wasm (no sockets).
- **`FileManager` file I/O is sandboxed**: the STEP / STL / glTF read/write
  functions that take file paths need a **virtual filesystem** (Emscripten MEMFS,
  or WASI preopens). This is the single biggest API-surface task after linking.
- **4 GB single-heap ceiling** (wasm32; Swift does not target wasm64) caps model
  size, and the linked module will be large (occt-wasm is ~4.5 MB brotli for OCCT
  alone. Swift + Foundation adds more).

## Three paths to one wasm module

The goal requires Swift and OCCT in one module with a **shared ABI**. There are
three ways to get there. **We are not choosing between them yet**. Phase 0 picks
the winner with evidence.

| Path | Approach | Trade-off | Maturity (June 2026) |
|------|----------|-----------|----------------------|
| **A. Swift-on-Emscripten** | Compile Swift against emsdk libc so it matches an Emscripten-built OCCT. Reuse a prebuilt OCCT 8.0.0 wasm (e.g. `andymai/occt-wasm`). | Most direct *if* it works; reuses existing OCCT wasm builds. | **Experimental**. March 2026 Swift pitch + Embedded-Swift/emsdk PoC; no packaged toolchain. |
| **B. OCCT-on-wasi-sdk** | Port OCCT to build with wasi-sdk so it matches standard SwiftWasm. | Standard, well-supported Swift side; OCCT side is uncharted (OCCT assumes POSIX/threads). | OCCT headless core has no hard Emscripten dep, but no known wasi-sdk port exists. |
| **C. Two components** | Keep OCCT (Emscripten) and Swift (wasi) as separate wasm modules; bridge via the **Component Model / WIT** at a typed interface, not the C ABI. | Avoids ABI linking entirely; adds a serialization boundary across every call. | WASI 0.2 shipped; 0.3 landing 2026. Heaviest runtime model. |

The toolchain pinned below is **path B's**: it is the one the bounded work items
(#2169 through #2175) attempt, and #2175 is still the go/no-go that can send the
question back to A or C. Pinning a toolchain is not the path decision; it is what
makes an attempt at one reproducible.

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
`libTKernel.a` under `--require-complete`. Neither **linked any of it**.

So every statement in this document about what an OCCT wasm build does at runtime
is an argument from the source and its callers, not an observation. In particular
the libc++ seam rests on weak symbol resolution that a larger link could resolve
the other way, `operator new` and `std::bad_alloc` are unprobed, and `-lsetjmp`
and `-lwasi-emulated-getpid` have never been on a link line. Those are #2174's,
which is why that issue smoke-links a module of its own before #2175 brings Swift
and the bridge in. The measurement logs are
[`Scripts/repro/2169/README.md`](../Scripts/repro/2169/README.md),
[`Scripts/repro/2172/README.md`](../Scripts/repro/2172/README.md) and
[`Scripts/repro/2173/README.md`](../Scripts/repro/2173/README.md).

## Plan

### Phase 0. Decision spike (gates everything)

The one thing that can kill the whole idea is the ABI seam. Validate it cheaply
before porting 3,500 operations.

1. ~~Stand up a SwiftWasm toolchain (swift.org Swift SDK for WebAssembly) and
   confirm a trivial `swift build --swift-sdk … wasm` runs.~~ Done in #2169, see
   [Pinned toolchain](#pinned-toolchain).
2. Pick **3 representative bridge functions**: `OCCTShapeBox` (pure compute),
   one boolean (e.g. `OCCTShapeFuse`, exercises the allocator hard), and one
   STEP/STL export (exercises the virtual FS + string I/O). **A fourth was added
   at #2175's revalidation**: one call that must *fail*, because all three of the
   above are happy paths and the failure mode [#2171 measured](#c-exceptions-on-wasip1-what-is-proven-2171)
   is silent. A translation unit that missed the exception flags returns correct
   boxes, correct fuses and correct STEP files, and answers every error by
   trapping the module.
3. Attempt each path far enough to **link and call those functions** from Swift:
   - **A**: build/obtain OCCT-on-emscripten + Swift-on-emscripten, link, call.
   - **B**: cross-build just the bridge + minimal OCCT TKBRep subset with
     wasi-sdk, link against wasi Swift, call. This is the one under way; see
     [Pinned toolchain](#pinned-toolchain) and
     [Which sysroot compiles OCCT](#which-sysroot-compiles-occt-and-why-it-is-not-wasi-sdks).
   - **C**: wrap the functions as a WIT interface across two components.
4. **Deliverable:** a one-page decision memo recording which path linked and ran,
   binary size, and blockers hit. This selects the path for Phase 1.

> Stop here and reassess if no path links the spike functions. That is the
> go/no-go gate.

### Phase 1. Build pipeline

- Add a wasm target to `build-occt.sh` (or a sibling `build-occt-wasm.sh`) for the
  chosen toolchain. `xcframework` packaging is Apple-only, so wasm needs its own
  distribution path (a checked-in/release-asset `.a` + headers, or vendored
  sources, consumed via SwiftPM `linkerSettings`/unsafeFlags, there is no
  `binaryTarget` for wasm).
- Drop the `#import <Foundation/Foundation.h>` from the bridge header (or guard it)
  so the bridge compiles under the wasm toolchain.

### Phase 2. Swift layer portability

- Conditionalise the Foundation surface: keep `Data`/`URL`/`Date`; route or stub
  `FileManager`/path-based I/O through a virtual FS abstraction.
- Replace any `URLSession`/socket use (audit confirms none in the kernel paths,
  but re-verify).
- `#if canImport` / `#if os(WASI)` guards where platform divergence is needed.

### Phase 3. File I/O over a virtual FS

- The STEP/IGES/STL/glTF read+write bridge functions take file paths. Provide a
  MEMFS (Emscripten) or preopen (WASI) shim so a SwiftWasm app can hand bytes in
  and get bytes out without a real filesystem. This is the largest API-surface
  task.

### Phase 4. Test + CI

- A wasm test path (the pinned `wasmkit`, or a headless browser runner) for a **subset** of the
  per-domain suites. Full parity is unrealistic initially; target the modeling +
  IO domains first.
- A GitHub Actions matrix entry that builds the wasm slice and runs the subset.

### Phase 5. Consumer validation

- A minimal SwiftWasm sample app (JavaScriptKit) that imports OCCTSwift, builds a
  box, fuses two shapes, and exports STEP, proving the goal end to end.

## Effort & risk

- **Phase 0 (spike):** ~1 week. **High information value, low cost.** Do this first.
- **Phases 1 to 5:** weeks-to-months and **highly path-dependent**. Path A's risk is
  toolchain immaturity, Path B's is an uncharted OCCT port, Path C's is per-call
  overhead and the component tooling. The spike retires the dominant risk before
  any of that is committed.

This is a **porting project, not a recompile**. The existing arm64 xcframework is
the wrong architecture/libc/libc++ and is unusable on wasm regardless of path.

## Prior art

- **`andymai/occt-wasm`**: actively maintained, tracks **OCCT 8.0.0** (the exact
  GA this repo pins), built with emsdk, ~4.5 MB brotli. The strongest candidate
  OCCT-side input for Path A. <https://github.com/andymai/occt-wasm>
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
