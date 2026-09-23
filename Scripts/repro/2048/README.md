# #2048: can OCCTSwift's wasm build be consumed as a SwiftPM dependency?

The consumer #1689 is building is a SwiftWasm application using JavaScriptKit, and it reaches
OCCTSwift with `.package(url:, from: "...")`. That one detail governs the whole WASI configuration,
because **SwiftPM refuses to build any package that uses `.unsafeFlags` once it is resolved by
version**, and as `Package.swift` stood every wasm flag was an unsafe flag.

So the question is not which flags to add. It is where flags can come from at all when the package
carrying them is a published dependency.

`run.sh` answers that with nine cases. It needs **no OCCT**: the stub has OCCTSwift's target shape
and none of its content, so the whole matrix runs today, while `libOCCT-wasm.a` is still #2174's
work in progress.

## What the stub is

`stub/` is a package with the same four-layer shape as OCCTSwift and nothing in it:

| Stub target | Stands in for | What it carries |
|---|---|---|
| `StubKernel` | the `OCCT` target | `path: "Libraries"`, one empty `dummy.c`, a header search path into a prebuilt header tree, and a `.linkedLibrary` naming a static archive that is not in the package sources |
| `StubBridge` | `Sources/OCCTBridge` | C++ over a flat C surface, an outermost `catch (...)`, a `std::mutex` the wasip1 libc++ does not declare, and a `getpid()` |
| `StubSjLj` | the `OCC_CATCH_SIGNALS` sites | a `setjmp`/`longjmp` round trip |
| `StubOCCT` | `Sources/OCCTSwift` | the Swift surface the application imports |

`consumer/` is the application: it declares the dependency and nothing else. It carries **no build
setting of any kind**, which is the point, because an application consuming a published package has
nowhere to put one.

`run.sh` materialises the prebuilt archive and a copy of the real threading shim into a work
directory, commits the stub as a git repository with a `1.0.0` tag, and builds the consumer against
it. The archive is compiled with the swift.org toolchain's `clang++` against the **Swift SDK's**
`WASI.sdk`, not wasi-sdk's own sysroot, for the reasons `Scripts/cmake/wasi-swift-sdk.cmake` gives
at length; compiling it the other way makes the threading shim's `static_assert` refuse the build,
which is the assertion doing its job.

## The rule, measured

The refusal is about the **requirement**, not the flag, and not the platform:

| How the dependency is declared | `.unsafeFlags` in it |
|---|---|
| `.package(path:)` | accepted |
| `.package(url:, branch:)` | accepted |
| `.package(url:, from: "1.0.0")` | **refused**: `the target 'StubBridge' in product 'StubOCCT' contains unsafe build flags` |

A `.when(platforms: [.wasi])` condition does not exempt it. A versioned dependency whose unsafe
flags are conditioned on WASI is refused while building for macOS, which is why this cannot be
solved by hiding the flags behind a condition.

## Which flags have a safe spelling

`PackageDescription` offers exactly these, and the list is the whole answer to "can this be
expressed safely":

| Setting | Safe members |
|---|---|
| `CSetting` / `CXXSetting` | `headerSearchPath`, `define`, the four warning controls |
| `LinkerSetting` | `linkedLibrary`, `linkedFramework` |

So, flag by flag:

| What the WASI build needs | Safe spelling | Verdict |
|---|---|---|
| `-include` of the threading shim | none | **replace it**: a guarded `#include` from a bridge source needs no setting at all (case 4), or the toolset supplies `-include` (case 8) |
| `-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false` | none | toolset |
| `-mllvm -wasm-enable-sjlj` | none | toolset |
| `-lc++abi`, `-lunwind` | `.linkedLibrary` | **safe**, manifest |
| `-lsetjmp` | `.linkedLibrary` | **safe**, manifest |
| `-lwasi-emulated-getpid` | `.linkedLibrary` | **safe**, manifest |
| `-lOCCT-wasm` | `.linkedLibrary` | **safe**, manifest |
| `-L <wasi-sdk>/…/eh` | none | toolset |
| `-L <the kernel archive's directory>` | none | toolset |
| `-D` defines, header search paths | `.define`, `.headerSearchPath` | **safe**, manifest |

Case 4 is what makes the library rows worth stating separately: with the names in the manifest and
no `-L` anywhere, the link fails on `-lSTUBKERNEL-wasm` and `-lunwind` **and on nothing else**.
`libsetjmp.a` and `libwasi-emulated-getpid.a` are already in the Swift SDK's `WASI.sdk`, which is
the link's sysroot. `libc++abi.a` is there too, which is worse than it being absent: it is the
no-exceptions flavour, so the toolset's `-L` into wasi-sdk's `lib/wasm32-wasip1/eh` has to
**precede** the sysroot rather than merely be present.

## The recommendation, and the two it beats

**A toolset file, written by `Scripts/make-wasi-toolset.py` and passed as
`swift build --toolset toolset.json`.** It is the consumer's file rather than the package's, so the
`.unsafeFlags` rule does not apply to it, and every flag it carries names a property of the machine
(where wasi-sdk is installed, where the kernel archive was put) that a published manifest could not
know anyway. Cases 7 and 8 build a **versioned** dependency for `wasm32-unknown-wasip1` this way and
run it.

The alternatives on the issue, and why not:

- **A SwiftPM build plugin.** A build-tool plugin returns `[Command]`, each a process to run that
  produces files. There is no API by which a plugin changes another target's compiler flags, so
  this cannot carry `-fwasm-exceptions` at all.
- **A prebuilt binary artefact.** `binaryTarget` takes an `xcframework`, which is Apple-only, or an
  `artifactbundle`, which holds executables. Neither is a static library for a wasm triple. This is
  not a matter of effort; the shape does not exist.
- **Pushing more into `Scripts/cmake/wasi-swift-sdk.cmake`.** That file compiles OCCT and reaches
  nothing SwiftPM builds, so it cannot carry a single flag the bridge or the link needs.

## The nine cases

Run `bash Scripts/repro/2048/run.sh`. It exits non-zero if any case stops producing the outcome it
asserts, which is the point of asserting rather than printing.

| # | Setup | What it establishes |
|---|---|---|
| 1 | `.unsafeFlags`, versioned dependency | refused, and the message names the target and product |
| 2 | the same, path dependency | accepted, and the build reaches the link. The restriction is the requirement |
| 3 | safe settings only, no shim, no toolset | compile fails on `std::mutex`, so the shim is load-bearing |
| 4 | shim by a guarded `#include`, no toolset | compiles with no setting at all; the link then fails on exactly `-lSTUBKERNEL-wasm` and `-lunwind` |
| 5 | toolset with the `-L`s but **no** exception flags | **builds clean, and the outermost `catch (...)` does not fire** |
| 6 | setjmp present, exception flags on, no `-wasm-enable-sjlj` | refused, and the diagnostic names setjmp |
| 7 | toolset with the `-L`s, the exception flags and the sjlj flag | a versioned dependency builds for wasm and every case passes |
| 8 | the same, shim force-included by the toolset | also works, so the shim has two viable mechanisms |
| 9 | Objective-C++ plus `-fwasm-exceptions`, compiled directly | **clang crashes**, see below |

Cases 5 and 6 are the negatives. Case 5 is the one worth reading twice: it is the failure mode
[#2171](https://github.com/SecondMouseAU/OCCTSwift/issues/2171) measured, reproduced here through a
dependency and a toolset rather than through one package. The build is green, there is no
diagnostic, and the module traps instead of returning the refusal the bridge contract promises.

## The blocker case 9 found, which is not about SwiftPM

`Sources/OCCTBridge/src` is 33 **Objective-C++** files, and the recommendation puts
`-fwasm-exceptions` on every one of them. The pinned toolchain's clang crashes when it does:

| Language | Flags | Result |
|---|---|---|
| Objective-C++ | `-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false` | **crash**, `Running pass 'WebAssembly Exception Information'` |
| Objective-C++ | `-fwasm-exceptions` alone (legacy encoding) | **crash**, same pass |
| Objective-C++ | `-fwasm-exceptions … -fno-objc-exceptions` | **crash**, same pass |
| Objective-C++ | no exception flags | compiles |
| C++ | `-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false` | compiles |

The same source file, one `-x` apart. Without the exception flags the bridge compiles and every
outermost `catch (...)` silently stops firing, which case 5 shows is not an option, so the bridge's
sources have to reach the compiler as C++ rather than Objective-C++ before any of this links. That
is a finding for #2174 and #2175 rather than something this issue can fix, and it is recorded here
because case 9 will start failing when the toolchain fixes it.

## A bug this probe found in its own recommendation

Cases 7 and 8 failed on their first full run, with
`Error: "Message(text: "Illegal opcode: [6]")"`, which is wasmkit refusing the legacy
exception-handling encoding. The toolset was giving the **C** compiler only `-mllvm
-wasm-enable-sjlj` while giving the C++ compiler the encoding flag as well, on the reasoning that
`-fwasm-exceptions` is a C++ flag. `-wasm-use-legacy-eh=false` is an `-mllvm` option and applies to
any language, so the single C object came out in the legacy encoding and the runtime refused the
whole module. `-fwasm-exceptions` on a C compile is accepted with no diagnostic, measured, so both
compilers now get the same set and `make-wasi-toolset.py`'s `--self-test` has a case that fails if
that is undone.

## How far the real package gets now

The stub is the proof; this is the state of the thing it stands for. With the manifest this PR
lands and a toolset from `Scripts/make-wasi-toolset.py`:

```bash
OCCTSWIFT_WASI=1 TOOLCHAINS=swift swift build --toolset toolset.json \
    --swift-sdk swift-6.4.0-RELEASE_wasm --triple wasm32-unknown-wasip1
```

SwiftPM loads the manifest, plans the WASI graph, builds the `OCCT` target and starts compiling
`Sources/OCCTBridge/src`. Nothing in the manifest is the obstacle any more. The first failure is in
the bridge header, 19 instances of one cause:

```
Sources/OCCTBridge/include/OCCTBridge.h:901:3: error: unknown type name 'int32_t'
```

`#2049` wrapped that header's `#import <Foundation/Foundation.h>` in `#if !defined(__wasi__)`, and
Foundation is what was transitively supplying `<stdint.h>`. One guarded `#include <stdint.h>` is the
fix. It is not in this PR because `Sources/OCCTBridge/` belongs to another change in flight.

## What is NOT verified here

- **Nothing about OCCT.** No `libOCCT-wasm.a` exists yet (#2174). The kernel in this probe is one
  translation unit that throws.
- **Nothing about the real bridge.** Case 9 says the real bridge cannot be compiled with these
  flags as it stands.
- **Nothing about the link at OCCT's scale.** The libc++ seam between the Swift SDK's runtime and
  wasi-sdk's `eh` flavour holds for the stub, as it held for one file in #2169 and #2171. A larger
  link can resolve weak symbols the other way.
