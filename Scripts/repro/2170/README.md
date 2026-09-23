# #2170: the std threading shim, and the probe that holds it down

The shim is [`Scripts/wasm-shims/wasi-std-threading.hpp`](../../wasm-shims/wasi-std-threading.hpp).
`Scripts/build-occt-wasm.sh` force-includes it with `-include`, and **no OCCT source is patched for
the threading class at all**. Why that is the mechanism, and what the previous attempt cost, is in
[`docs/WASI_GUARD_SITES.md`](../../../docs/WASI_GUARD_SITES.md).

This directory is the measurement log and the regression test.

    ./run.sh              # both cases
    ./run.sh --no-shim    # the failing case on its own
    ./run.sh --shim       # compile, link and RUN the module

`probe.cxx` is not a synthetic exercise of the missing names. Every construct in it is copied from
a site the kernel build actually compiles, and the file says which one beside each: `Units.cxx` and
carried patch `0033` for the `static std::recursive_mutex` taken again from under itself,
`Plugin.cxx` for `std::shared_mutex` with a nested `std::shared_lock`,
`NCollection_IncAllocator.cxx` for `std::make_unique<std::shared_mutex>`, `BRepGraph_CacheRegistry.cxx`
for `std::lock` over two deferred `unique_lock`s, patches `0014`/`0015` for the plain mutex, and
`Standard_Condition.hxx` in full for the condition variable. It also touches every name that
SURVIVES in this libc++, so it fails if the shim ever shadows one.

## Measurements, 2026-09-22, macOS 27.0 arm64

Swift toolchain 6.4.0-RELEASE, Swift wasm SDK 6.4.0-RELEASE, sysroot
`swift-6.4.0-RELEASE_wasm/wasm32-unknown-wasip1/WASI.sdk`, all as pinned by
[`Scripts/wasm-toolchain-versions.txt`](../../wasm-toolchain-versions.txt).

### The probe

| Case | Result |
|---|---|
| `-fsyntax-only`, no shim | **35 errors**, across all eight names |
| `-fsyntax-only`, shim force-included | **0 errors** |
| linked and run under wasmkit | prints `probe: 11`, exits 0 |

### Eight names, not six

#2170 measured six missing names by compiling a probe. Compiling the real files found two more,
and neither could have been found by grepping for the six:

| Name | How it was missed |
|---|---|
| `std::cv_status` | `condition_variable`'s return type. Nothing names it directly. |
| `std::lock` | `BRepGraph_CacheRegistry.cxx:47` and `BRepGraph_LayerRegistry.cxx:54` call the variadic multi-lock on two deferred `unique_lock`s. The statement names none of the six. |

`std::try_lock`, `std::timed_mutex`, `std::shared_timed_mutex`, `std::condition_variable_any`,
`std::thread` and `std::notify_all_at_thread_exit` are equally absent and are deliberately not
supplied: the four modules this build compiles use none of them, measured at zero occurrences.

### 75 files, not 76

#2170 says 76 files across `FoundationClasses`, `ModelingData`, `ModelingAlgorithms` and
`DataExchange`, excluding `GTests/`. Re-measured against `Libraries/occt-src` at `V8_0_1` plus all
twenty-nine carried patches, it is **75 excluding `GTests/` and 76 including it**: exactly one
GTests file uses the names, and this build compiles no GTests. The fifteen of them that carried
patches modify reproduce exactly.

### Compiling the real files

Every one of the 75, `-fsyntax-only`, against `Libraries/occt-src` in the main checkout, with
`-I` for all 493 package directories, `WASM_CXX_EH_FLAGS` from the pins, and CMake's generated
`Standard_Version.hxx` supplied from the macOS install tree:

| | Files clean | Total errors |
|---|---|---|
| Without the shim | **2 of 75** | 836 |
| With the shim | **72 of 75** | 50 |

The two that compile without the shim are `Standard_Mutex.hxx`, which only names `std::mutex` in
the deprecation comment that points at it, and `LibCtl_Library.gxx`.

The three that still fail with it fail on POSIX surface, not on threading. Not one threading
diagnostic appears anywhere in the 50:

| File | Gap |
|---|---|
| `OSD/OSD_signal.cxx` | `<signal.h>` (`-D_WASI_EMULATED_SIGNAL`), `struct sigaction` |
| `Standard/Standard_MMgrOpt.cxx` | `<sys/mman.h>` (`-D_WASI_EMULATED_MMAN`), `mmap`, `munmap`, `PROT_*`, `MAP_*` |
| `Standard/Standard_StackTrace.cxx` | `<execinfo.h>` |

`OSD_signal.cxx` and `Standard_StackTrace.cxx` are already
[#2173](https://github.com/SecondMouseAU/OCCTSwift/issues/2173)'s. **`Standard_MMgrOpt.cxx` is
not**, and `docs/WASI_GUARD_SITES.md` does not list it: OCCT's optimised memory manager wants a
real `mmap`, and wasi-libc has only the emulation. That is a finding for #2173, not for this shim.

This is 72 of 75 compiled and 3 not, and the count is stated that way on purpose. A claim that
"the 75 compile" from a sample of five would be the same mistake PR #2076's "all 14 patches apply
cleanly" made: true of what it measured, and not the property anyone cared about.

### The shim does not apply to wasi-sdk's own sysroot

Measured, and it is the finding most likely to bite next. wasi-sdk 34.0's `wasm32-wasip1` sysroot
sets `_LIBCPP_HAS_THREADS 1` in **both** its `eh` and `noeh` `__config_site`, and supplies all
eight names itself; the probe compiles there with no shim at all. The Swift SDK's `WASI.sdk` sets
it to 0. So whether the shim is needed is a property of which sysroot the kernel build uses, and
`Scripts/build-occt-wasm.sh` resolves `swift-wasi-sdk.cmake` first and falls back to
`wasi-sdk-p1.cmake`, which selects wasi-sdk's compiler and its default sysroot. No
`swift-wasi-sdk.cmake` exists in either the wasi-sdk install or the Swift SDK artifact bundle, so
the fallback is what runs today.

Settling that is [#2172](https://github.com/SecondMouseAU/OCCTSwift/issues/2172)'s, and it reaches
further than this shim: the Swift side links the Swift SDK's threadless libc++, so a kernel built
against a libc++ with threads meets it across the ABI. What this issue adds is that the mismatch
cannot pass unnoticed. `build-occt-wasm.sh` runs a preflight compile with the toolchain file's own
compiler, triple and sysroot before CMake starts, and names both causes and their opposite fixes.

## Running the negative cases

Three injections, all run.

| Injection | Result |
|---|---|
| Remove the `-include` | Probe: 35 errors. The 75 real files: 2 compile instead of 72 |
| Force-include the shim into a host macOS compile, where `_LIBCPP_HAS_THREADS` is 1 | **Exactly one** diagnostic, the shim's own `static_assert`, naming both remedies. No redefinition cascade: the definitions are inside `#if !_LIBCPP_HAS_THREADS` |
| Replace `std::recursive_mutex`'s no-op lock with PR #2076's spinlock (`atomic_flag` + `test_and_set` spin) | **Compiles clean**, then hangs at `recursiveOuter()`'s second acquisition. Killed after 20s |

The third is the one that matters, and it is why `run.sh --shim` runs the module instead of
stopping at a green compile. A compile-only check cannot tell a sound stand-in from the one that
closed PR #2076.

A fourth case was run against the harness rather than the shim, and is recorded because it produced
a wrong number first. The no-shim sweep was scripted with `SHIM=${OVERRIDE:-<default>}`, which
treats an empty override as unset, so the "without" run silently used the shim and reported 72 of
75 clean for both columns. `${OVERRIDE-<default>}` is the fix. A negative case that quietly runs
the positive one reads exactly like a result.
