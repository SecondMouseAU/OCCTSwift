# #2169: the pinned wasm toolchain, and the package that proves it

`standalone/` is the smallest package with the shape OCCTSwift has: a Swift target calling a C++
target over a flat C surface. It builds for `wasm32-unknown-wasip1` and runs, and it is what
`Scripts/install-wasm-toolchain.sh --verify` builds and runs. `transcript.txt` is a recorded run
from a tree with no wasi-sdk in it.

The pins themselves live in [`Scripts/wasm-toolchain-versions.txt`](../../wasm-toolchain-versions.txt);
the narrative is in [`docs/wasm-feasibility.md`](../../../docs/wasm-feasibility.md). This page is
the measurement log: what was tried, what the machine said, and what that ruled out.

## Measurements, 2026-09-22, macOS 27.0 arm64

### Xcode's Swift toolchain cannot link for wasm

`swift build --swift-sdk swift-6.4.0-RELEASE_wasm --triple wasm32-unknown-wasip1` with Xcode's
`/usr/bin/swift` compiles every file and then fails at the link step:

    error: unableToFind(tool: "swift-autolink-extract")

`xcrun --find wasm-ld` also fails. The swift.org 6.4.0-RELEASE toolchain carries `wasm-ld`,
`swift-autolink-extract`, a clang that lists `wasm32` under `-print-targets`, the wasm32
compiler-rt builtins, and `wasmkit`. Select it with `TOOLCHAINS=swift`; `swift --version` then
reports `(swift-6.4-RELEASE)` rather than `(swiftlang-6.4.0.34.1 clang-2100.3.34.1)`.

### wasi-sdk is not needed as a compiler, and is needed for exceptions

The Swift SDK's artifact bundle carries a complete WASI sysroot at
`swift-6.4.0-RELEASE_wasm/wasm32-unknown-wasip1/WASI.sdk`, including `libc++.a`, `libc++abi.a` and
the libc++ headers, and the swift.org clang compiles and links C++ against it with nothing but
`-target wasm32-unknown-wasip1 --sysroot=<WASI.sdk>` plus a `-resource-dir` pointing at the
bundle's clang resources for the builtins. Non-throwing C++ needs nothing else.

Throwing C++ does not link:

    wasm-ld: error: ...: undefined symbol: __cxa_allocate_exception
    wasm-ld: error: ...: undefined symbol: __cxa_throw

The cause is the sysroot's C++ runtime, not the flags. `llvm-ar t` on the bundle's `libc++abi.a`
lists `cxa_noexception.cpp.o` and no `cxa_exception.cpp.o`, and `llvm-nm --defined-only` finds no
`__cxa_throw`. The headers are not the no-exceptions build (its `__config_site` sets only
`_LIBCPP_HAS_THREADS 0`), so the failure surfaces at link rather than at compile.

wasi-sdk 34.0 ships the C++ runtime twice, at `lib/wasm32-wasip1/eh` and `lib/wasm32-wasip1/noeh`.
The `eh` flavour defines `__cxa_throw` and comes with a `libunwind.a`, and adding
`-L<wasi-sdk>/share/wasi-sysroot/lib/wasm32-wasip1/eh -lc++abi -lunwind` to the link is what makes
`standalone/` link and run. That is the whole of wasi-sdk's role here. OCCT throws
`Standard_Failure` pervasively, so it is not optional, but it is a set of link-time archives, not
the second compiler the old prerequisites list implied.

### wasmkit runs the standardised exception encoding only

With `-fwasm-exceptions` alone, clang emits the legacy encoding and wasmkit 0.3.1 refuses the
module:

    Error: "Message(text: "Illegal opcode: [6]")" at offset 0x282

Adding `-mllvm -wasm-use-legacy-eh=false` emits `try_table` / `exnref` instead, and the same
module runs. Both flags are pinned together as `WASM_CXX_EH_FLAGS`. This is the reason the runtime
choice reaches the compiler flags, and the reason for pinning a runtime at all rather than leaving
it to whatever is on the machine.

## Running the negative cases

The verification is only worth having if it fails when the toolchain is wrong. Both injections
were run:

| Injection | Result |
|-----------|--------|
| Drop the `-L.../eh -lc++abi -lunwind` linker settings from `standalone/Package.swift` | Link fails: `undefined symbol: __cxa_throw`, `__cxa_begin_catch`, `_Unwind_CallPersonality` and five more |
| Replace `WASM_CXX_EH_FLAGS` with a bare `-fwasm-exceptions` | Builds, then wasmkit refuses it: `Illegal opcode: [6]` |

**Re-running these needs one thing that is not obvious.** SwiftPM caches the compiled manifest
against `Package.swift`'s **content**, not against `Scripts/wasm-toolchain-versions.txt` that the
manifest reads. Injecting the second case by editing the pins file alone gives a no-op rebuild and
a module that still runs clean, which reads as evidence that the flag was unnecessary.

Neither `rm -rf .build` nor `touch Package.swift` clears it. A touch changes mtime and the cache
key is a content hash, so the touched build is just as stale. What does work, measured:

| After editing the pins file | Next build |
|---|---|
| nothing | stale |
| `touch Package.swift` | stale |
| append a comment line to `Package.swift` | picks up the edit |
| `swift build --manifest-cache none` | picks up the edit |
| `rm -f ~/Library/Caches/org.swift.swiftpm/manifests/manifest.db*` | picks up the edit |

`--manifest-cache none` is the one to reach for, since it changes no file.

A third case is covered by the package itself rather than by the toolchain: `wasm_probe_sum`
returns minus the length of the caught message, and `main.swift` checks for `-26.0`, so a build
where the throw never happened or the message was lost fails instead of printing a plausible
number.

## What this does not establish

`standalone/` links Swift built against the Swift SDK's no-exceptions C++ runtime together with a
C++ target using wasi-sdk's exception-enabled one. That works for this package. Whether it holds
for a kernel the size of OCCT, where the two libc++ builds meet across far more of the ABI, is
[#2171](https://github.com/SecondMouseAU/OCCTSwift/issues/2171)'s spike, and building OCCT itself
is [#2174](https://github.com/SecondMouseAU/OCCTSwift/issues/2174).
