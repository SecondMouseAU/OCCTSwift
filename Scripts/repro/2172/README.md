# #2172: TKernel on wasm32-unknown-wasip1, measured

The first real OCCT build of the wasm effort. `run.sh` reproduces every number below; it reads the
compiler and every flag out of the build tree CMake generated rather than restating them, so it
cannot drift from the build it describes.

    Scripts/build-occt-wasm.sh --toolkit TKernel    # the build; leaves Libraries/occt-build-wasm
    Scripts/repro/2172/run.sh                       # all four measurements
    Scripts/repro/2172/run.sh guards                # just the guard-site list, for #2173

## Measurements, 2026-09-23, macOS 27.0 arm64

Swift toolchain 6.4.0-RELEASE, Swift wasm SDK 6.4.0-RELEASE, wasi-sdk 34.0, all as pinned by
[`Scripts/wasm-toolchain-versions.txt`](../../wasm-toolchain-versions.txt). `Libraries/occt-src` at
`V8_0_1` plus all twenty-nine carried patches plus both WASI patches, which is the state
[`okf/policies/wasi-patch-base.md`](../../../okf/policies/wasi-patch-base.md) requires.

### Which sysroot compiles OCCT

The question #2172 existed to settle, and the working hypothesis it was handed survived, on
evidence the hypothesis did not have.

| | Swift SDK `WASI.sdk` | wasi-sdk 34.0 `wasm32-wasip1` |
|---|---|---|
| `_LIBCPP_HAS_THREADS` | 0 | 1, in both `eh` and `noeh` |
| libc++ `_LIBCPP_VERSION` | 210106, LLVM 21 | LLVM 23.1.0 |
| `__cxa_throw` in `libc++abi.a` | absent | present in the `eh` flavour |
| `libunwind.a` | absent | present in the `eh` flavour |

The threads row was already #2170's. The **libc++ version row is new and is the stronger argument**:
the two sysroots are two libc++ major releases apart, so building OCCT against wasi-sdk's would put
two different libc++ implementations under one set of mangled names in one module. The Swift side
links `WASI.sdk`'s copy and cannot be told otherwise. The bridge's flat C ABI keeps C++ types out
of Swift's way; it does nothing about which definition the linker picks for a symbol both archives
define.

So OCCT is compiled against the **Swift SDK's `WASI.sdk`**, with the **swift.org toolchain's
clang**, and wasi-sdk contributes exactly one thing: the exception-enabled `libc++abi` and
`libunwind` in `lib/wasm32-wasip1/eh`, which `WASI.sdk` has no equivalent of. That is the
combination PR #2180 built, linked and ran end to end.

The mechanism is [`Scripts/cmake/wasi-swift-sdk.cmake`](../../cmake/wasi-swift-sdk.cmake), a
toolchain file this repo owns. `Scripts/build-occt-wasm.sh` used to reach for a `swift-wasi-sdk.cmake`
that exists in neither install and fall through to wasi-sdk's own `wasi-sdk-p1.cmake`, which selects
wasi-sdk's clang and its default sysroot; that fallback was what always ran.

### 119 of 127, and the eight

`TKernel` has **127 source files**, 126 `.cxx` and one `.c` (`Resource/Resource_ConvertUnicode.c`).
**119 compiled. 8 did not.** Both numbers come from the build tree, the denominator from the object
rules CMake generated and the numerator from the objects on disk, so neither is a sample and neither
is rounded.

The eight are the whole platform-gap list for this toolkit, produced in one pass because the build
runs with `-k`, and re-emitted with `-ferror-limit=0` so nothing is truncated at clang's default of
twenty. Every one is a filesystem, process or signal surface. Not one threading diagnostic appears
anywhere, at any site, in any of the 127.

| File | Symbol or header at fault |
|---|---|
| `Message/Message_PrinterSystemLog.cxx` | `<syslog.h>` at `:89` |
| `OSD/OSD_File.cxx` | `mkstemp` at `:767`; `fcntl` record locking `F_WRLCK` `:1394`, `F_RDLCK` `:1397`, `F_SETLKW` `:1404`, `F_UNLCK` `:1509`, `F_SETLK` `:1510` |
| `OSD/OSD_Host.cxx` | `<netdb.h>` at `:29` |
| `OSD/OSD_Path.cxx` | `struct utsname` incomplete at `:44` |
| `OSD/OSD_Process.cxx` | `<pwd.h>` at `:44` |
| `OSD/OSD_signal.cxx` | `<signal.h>` refuses without `_WASI_EMULATED_SIGNAL`; then `struct sigaction` `:799` `:1053` `:1099`, `sigemptyset` `:823`, `sigaddset` `:850` `:866`, `SIG_UNBLOCK` `:851` `:867`, `SIG_DFL` `:1068` `:1097`, and `SIGHUP` `SIGINT` `SIGQUIT` `SIGILL` `SIGKILL` `SIGBUS` `SIGSEGV` `SIGFPE` `SIGSYS` throughout |
| `Standard/Standard_MMgrOpt.cxx` | `<sys/mman.h>` refuses without `_WASI_EMULATED_MMAN`; then `PROT_READ` `PROT_WRITE` `MAP_PRIVATE` `:766`, `MAP_FAILED` `:767`, `munmap` `:873` |
| `Standard/Standard_StackTrace.cxx` | `<execinfo.h>` at `:34` |

### Eight, where #2170 predicted three

#2170 compiled the 75 **threading-dependent** files across four modules and found three that still
failed: `OSD_signal.cxx`, `Standard_StackTrace.cxx` and `Standard_MMgrOpt.cxx`. All three reproduce
here. The five extra are not a contradiction and not a regression: `Message_PrinterSystemLog.cxx`,
`OSD_File.cxx`, `OSD_Host.cxx`, `OSD_Path.cxx` and `OSD_Process.cxx` name none of the eight threading
symbols, measured at zero occurrences each, so they were never in that population. #2170 measured
every threading-dependent file in four modules; this measures every file in one toolkit. The
populations overlap and neither contains the other.

The five were already listed under "Gaps that are known and not yet closed" in
`docs/WASI_GUARD_SITES.md`, from reading rather than from a compile. What is new is that the list is
now **complete for this toolkit** rather than a set of things somebody happened to notice, and that
`Message_PrinterSystemLog.cxx` was on nobody's list at all.

### How much of it is a define and how much is source work

Measured, and recorded here rather than acted on: these files belong to #2173, and
[`okf/policies/wasi-patch-base.md`](../../../okf/policies/wasi-patch-base.md) governs how their
patches are written. Each file recompiled with `-D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_MMAN
-D_WASI_EMULATED_GETPID -D_WASI_EMULATED_PROCESS_CLOCKS` added and nothing else changed:

| File | Errors remaining |
|---|---|
| `Standard/Standard_MMgrOpt.cxx` | **0** |
| `Message/Message_PrinterSystemLog.cxx` | 1 |
| `OSD/OSD_Host.cxx` | 1 |
| `OSD/OSD_Path.cxx` | 1 |
| `OSD/OSD_Process.cxx` | 1 |
| `Standard/Standard_StackTrace.cxx` | 1 |
| `OSD/OSD_File.cxx` | 6 |
| `OSD/OSD_signal.cxx` | 17 |

`Standard_MMgrOpt.cxx` is the finding here: it needs **no source change at all**, only
`-D_WASI_EMULATED_MMAN` at compile and `-lwasi-emulated-mman` at link. Adding a define to the build
script is a decision `docs/WASI_GUARD_SITES.md` reserves for evidence, and this is the evidence;
the decision itself is #2173's, because the link half of it cannot be verified until #2174.

`OSD_signal.cxx` is the other end. `_WASI_EMULATED_SIGNAL` supplies the `SIG*` constants and
`signal()`, and supplies no `struct sigaction`, `sigemptyset`, `sigaddset` or `SIG_UNBLOCK`, which
is what the seventeen are. OCCT's signal handling there is `sigaction`-based throughout.

### The exception and setjmp flags reach OCCT, and both fail silently without an assertion

#2171 established that a translation unit compiled without `WASM_CXX_EH_FLAGS` still lets an
exception propagate through it, while its stack cleanup never runs and a `try`/`catch` written
inside it never fires, with no diagnostic anywhere. `Scripts/build-occt-wasm.sh` now puts the flags
into `CMAKE_CXX_FLAGS` for the whole build, and asserts before CMake starts that they produce a
handler at all.

At kernel scale, over the 119 objects that compiled:

| Observable | Count |
|---|---|
| objects referencing `__cxa_throw`, so they can raise | 59 |
| objects referencing `__cxa_begin_catch`, so they carry a compiled handler | 44 |
| objects referencing `__wasm_setjmp`, so a `setjmp` pair was lowered | 6 |

The six are `OSD/OSD_ThreadPool.cxx`, `Resource/Resource_Manager.cxx` and the four
`Storage/Storage_*Data.cxx` and `Storage/Storage_Schema.cxx` files.

**That setjmp appears at all is a correction to `Scripts/repro/2171/README.md`**, which says
`OCC_CATCH_SIGNALS` expands to nothing "in this build" because `OCC_CONVERT_SIGNALS` is not defined.
That is true of the bridge's own compile. It is not true of OCCT's: `adm/cmake/occt_defs_flags.cmake:48`
adds `-DOCC_CONVERT_SIGNALS` for every non-Windows target, and the generated `flags.make` for this
build carries it, as does the macOS build's. So `OCC_CATCH_SIGNALS` expands to a real `setjmp`
inside OCCT on every platform, `-mllvm -wasm-enable-sjlj` is required rather than precautionary, and
`-lsetjmp` will be required at link.

Both negative cases were run, because both failures are silent:

| Injection | Result |
|---|---|
| `Storage_Schema.cxx` recompiled with `-fwasm-exceptions` and `-mllvm -wasm-use-legacy-eh=false` removed | compiles clean, and `__cxa_begin_catch` drops from 1 reference to 0. The handler is gone and nothing says so |
| `OSD_ThreadPool.cxx` recompiled with `-mllvm -wasm-enable-sjlj` removed | compiles clean, and the object is left with an undefined `setjmp` instead of `__wasm_setjmp` / `__wasm_setjmp_test` / `__wasm_longjmp`. The link is where it would fail |

### The archive

Archiving is the part the issue asked to prove, and it is proved on the 119 that compiled. A
complete `libTKernel.a` cannot exist until #2173 closes the eight, so the script writes
`libTKernel-partial.a`, under a name that cannot be mistaken for the real thing.

| Property | Value |
|---|---|
| path | `Libraries/occt-build-wasm/libTKernel-partial.a` |
| size | 3,073,886 bytes |
| members | 119 |
| defined symbols across the archive, `llvm-nm --defined-only` | 6,033 |
| `file` on a member | `WebAssembly (wasm) binary module version 0x1 (MVP)` |
| `llvm-objdump` on a member | `file format wasm` |
| members carrying 32-bit memory relocations | 105 |
| members carrying 64-bit memory relocations | 0 |

`llvm-ar` and `llvm-nm` are the pinned toolchain's, at
`/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin`. There is no `llvm-nm` on
the default macOS PATH at all, and host `nm -g` on a wasm object lists undefined symbols as though
they were defined, which has already produced one wrong conclusion in this initiative.

**`file` cannot tell wasm32 from wasm64.** Measured: the same source compiled
`--target=wasm32-unknown-wasip1` and `--target=wasm64-unknown-unknown` produces byte-identical
`file` output, `WebAssembly (wasm) binary module version 0x1 (MVP)`, and identical `llvm-nm`
addresses. So "`file` says WebAssembly" is not a wasm32 check and is not reported as one. What does
distinguish them is the width of the memory-address relocations, and `run.sh archive` prints the
control alongside the count: a wasm32 object relocates as `R_WASM_MEMORY_ADDR_REL_SLEB`, a wasm64
object as `R_WASM_MEMORY_ADDR_REL_SLEB64`. The first attempt at this check matched only the
non-PIC `..._LEB` spelling and reported 0 and 0, which reads exactly like a clean result.

The 14 members with no memory relocation at all are the ones that reference no data.

## Two defects in `Scripts/build-occt-wasm.sh` this build found

Both are pre-existing and both are fixed in the same PR, because neither could be worked around.

1. **The OCCT tag was spelled with dots.** `OCCT_TAG="V${OCCT_VERSION}"` gave `V8.0.1` where
   `Scripts/build-occt.sh` gives `V8_0_1`. Upstream carries both tags and they are the same commit,
   so the clone worked; `git describe --tags --exact-match` resolves the underscore spelling, so the
   reuse check rejected every tree the script had itself cloned, on every run after the first.
2. **CMake re-includes a toolchain file inside every `try_compile` sub-project**, and a `-D` cache
   entry does not reach one. The toolchain file's required-variable check therefore fired inside
   `CMakeDetermineCompilerABI`'s `try_compile` after the parent project had configured fine. The
   variables are exported as well as passed.

## What this does not establish

- **Nothing here is linked.** The archive is 119 objects; no `wasm-ld` has run over it. The libc++
  seam, `operator new`, `std::bad_alloc` and the link-order question #2171 left open are all still
  open, and they are #2174's.
- **One toolkit.** `TKernel` depends on nothing else in OCCT, which is why it is first. The 75
  threading-dependent files #2170 measured are spread over four modules, and only some of them are
  here.
- **The eight are not fixed.** They are recorded, and #2173 owns them.

## Related

- [`Scripts/repro/2170/README.md`](../2170/README.md), the threading shim and its probe.
- [`Scripts/repro/2171/README.md`](../2171/README.md), what exceptions do on wasip1, and the one
  correction this page makes to it.
- [`docs/WASI_GUARD_SITES.md`](../../../docs/WASI_GUARD_SITES.md), where the guard-site list lives.
- [`docs/wasm-feasibility.md`](../../../docs/wasm-feasibility.md), the plan of record.
