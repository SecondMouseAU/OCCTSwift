---
nav_exclude: true
search_exclude: true
---

# WASI build guard sites

A record of which OCCT source sites the `wasm32-wasip1` build changes, which gaps are deliberately
not changed there, and how a new guard is written. It describes the state of
[`Scripts/patches-wasi/`](../Scripts/patches-wasi/README.md), not a plan.

**This is not a status board.** It carries no task list and no progress marks, because the version
of this page that did carry them listed work as pending that had been attempted and reverted, and
work as required that no build ever performed. The plan of record is
[`docs/wasm-feasibility.md`](wasm-feasibility.md) and the issue sequence it names.

It also does not restate patch bodies. The patch files are the text, and a copy of a hunk in a
markdown page is a copy with no update path: this page previously showed an `OSD_Directory`
body that the patch on disk had stopped containing. Read
`Scripts/patches-wasi/wasi-osd-directory.patch` for what it does.

## The threading class is not patched. Not here, not ever.

The Swift wasip1 SDK ships a libc++ configured with `_LIBCPP_HAS_THREADS 0`. Measured against that
SDK's sysroot by syntax-only compile, in
[#2170](https://github.com/SecondMouseAU/OCCTSwift/issues/2170), eight names are gone and the rest
of the surface OCCT uses survives:

| Missing | Still present |
|---|---|
| `std::mutex` | `std::lock_guard` |
| `std::recursive_mutex` | `std::unique_lock` |
| `std::shared_mutex` | `std::once_flag`, `std::call_once` |
| `std::shared_lock` | `std::defer_lock`, `std::try_to_lock`, `std::adopt_lock` |
| `std::condition_variable`, `std::cv_status` | `std::atomic`, `std::atomic_flag` |
| `std::this_thread::yield` | |
| `std::lock` | |

Six of those eight are the ones #2170 measured by probe. `std::cv_status` and `std::lock` were
found by compiling the real files, and neither is reachable by grepping for the other six:
`cv_status` is `condition_variable`'s return type and nothing names it directly, and `std::lock`
is called on two deferred `unique_lock`s in `BRepGraph_CacheRegistry.cxx:47` and
`BRepGraph_LayerRegistry.cxx:54`, statements that name none of the six.

**One force-included shim header supplies all eight, and no OCCT source is patched for this class
at all.** It is [`Scripts/wasm-shims/wasi-std-threading.hpp`](../Scripts/wasm-shims/wasi-std-threading.hpp),
wired into the WASI build's `CMAKE_CXX_FLAGS` as `-include`. A patch in `Scripts/patches-wasi/`
that touches any of those names is wrong by construction, whether or not it compiles.

The shim adds to namespace `std`, which is formally undefined behaviour, and it says so in its own
header comment. What makes it defensible is that it targets one pinned libc++ and checks that
libc++'s configuration rather than assuming it: a `static_assert` fails if `_LIBCPP_HAS_THREADS` is
ever non-zero, the definitions sit inside `#if !_LIBCPP_HAS_THREADS` so they vanish rather than
collide, and `Scripts/build-occt-wasm.sh` runs a preflight compile before CMake starts so the
mismatch is one legible error instead of "the C++ compiler is not able to compile a simple test
program".

### Why a shim rather than patches

Two reasons, and the second is the expensive one.

**Patching per site does not terminate.** 75 files across the four modules this build compiles
(`FoundationClasses`, `ModelingData`, `ModelingAlgorithms`, `DataExchange`) use the missing names,
excluding `GTests/`, which this build does not compile; 76 if `GTests/` is counted, which is where
#2170's own figure came from. Fifteen of the 75 are files our own carried patches already modify,
because nine carried patches inject `std::mutex` or `std::recursive_mutex` as thread-safety fixes
(#341, #344, #349, #353, #374, #1153, #1154, #1157, #1403). `Standard_Mutex.hxx` is deprecated in
8.0.0 in favour of `std::mutex`, and upstream's mutable-static-elimination series keeps converting
more internals to it, so the surface grows at every kernel bump.

**The substitute that was tried is unsound.** Closed PR #2076 replaced the missing types with
hand-written spinlocks in `OSD/OSD_Environment.cxx`, `Plugin/Plugin.cxx`, `Units/Units.cxx`,
`UnitsAPI/UnitsAPI.cxx`, `Standard/Standard_Condition.hxx` and
`NCollection/NCollection_IncAllocator.hxx`, all under `src/FoundationClasses/TKernel/`. A spinlock
cannot stand in for a `std::recursive_mutex`, which is what the two units files hold: the second
acquisition on the same thread spins on a flag only that thread could clear, and in a
single-threaded runtime nothing ever will. The same argument retires the `std::shared_mutex`
sites, where a reader lock taken twice is ordinary and expected. Substituting a non-recursive
primitive for a recursive one is not a WASI problem; it converts a working lock into a hang on any
platform that takes that branch.

That failure compiles. `Scripts/repro/2170/run.sh` rebuilt it deliberately, against the shim's own
probe, and the module built clean and then hung at the second acquisition until it was killed,
which is why the probe is linked and run rather than only type-checked.

The shim keeps the types and drops the enforcement, which is sound here for the reason
`docs/wasm-feasibility.md` already gives: the bridge serialises every OCCT call through one
`std::recursive_mutex`, TBB is off, and the runtime is single-threaded. Every `lock()` returns at
once and every `try_lock()` returns true, so re-entrancy is safe by construction rather than by
bookkeeping.

### Which sysroot, and why the shim can be wrong for a build

Whether the eight names are missing is a property of the sysroot, and the two in play disagree.
wasi-sdk 34.0's own `wasm32-wasip1` sysroot sets `_LIBCPP_HAS_THREADS 1` in both its `eh` and
`noeh` `__config_site` and supplies all eight itself; the Swift SDK's `WASI.sdk` sets it to 0.

**Settled by [#2172](https://github.com/SecondMouseAU/OCCTSwift/issues/2172): OCCT is compiled
against the Swift SDK's `WASI.sdk`, so the shim applies and is required.** wasi-sdk contributes one
thing, the exception-enabled `libc++abi` and `libunwind` in `lib/wasm32-wasip1/eh`, and compiles
nothing. The threads row is the smaller half of the argument; the larger half is that the two
sysroots ship libc++ 21 and libc++ 23, so building OCCT against wasi-sdk's would put two libc++
implementations under one set of mangled names in a module whose Swift half links `WASI.sdk`'s
copy either way. `Scripts/cmake/wasi-swift-sdk.cmake` is the mechanism and carries the measurements.

Until #2172, `Scripts/build-occt-wasm.sh` resolved a `swift-wasi-sdk.cmake` that exists in neither
install and fell back to `wasi-sdk-p1.cmake`, so wasi-sdk's compiler and default sysroot were what
always ran. The preflight remains, because the answer to its error is never "drop the shim" by
reflex: it names both causes and their opposite fixes.

### Rejected: shadowing `__config_site` with `-I`

libc++'s sanctioned extension point for a platform with no threads is
`_LIBCPP_HAS_THREAD_API_EXTERNAL`, set in `__config_site`. It is not reachable from here. The
sysroot's `include/c++/v1` is searched ahead of any user `-I`, so taking that route would mean
editing the installed SDK, which is out of scope. Measured in #2170.

## What is patched today

| File | Site | Gap in wasi-libc | Patch |
|---|---|---|---|
| `src/FoundationClasses/TKernel/OSD/OSD_Chronometer.cxx` | `#include <sys/times.h>` at `:27`, and `GetProcessCPU()` | `<sys/times.h>` itself, `times()`, `struct tms` | `wasi-osd-chronometer.patch` |
| `src/FoundationClasses/TKernel/OSD/OSD_Directory.cxx` | `Build()` | `umask()` | `wasi-osd-directory.patch` |
| `src/FoundationClasses/TKernel/OSD/OSD_Directory.cxx` | `BuildTemporary()` | `mkdtemp()` | `wasi-osd-directory.patch` |

One property of that set is settled, and one is not.

**Settled: `wasi-osd-chronometer.patch` compiles, and until
[#2179](https://github.com/SecondMouseAU/OCCTSwift/issues/2179) it could not, in either
configuration.** As merged in PR #2043 it included `<sys/times.h>` at `OSD_Chronometer.cxx:27`
unguarded, and in this SDK's sysroot that header opens with `#ifndef _WASI_EMULATED_PROCESS_CLOCKS`
/ `#error WASI lacks process-associated clocks`. Compiled against that sysroot:

- with no emulation define, which is how `Scripts/build-occt-wasm.sh` runs, the translation unit
  died at the include and the patch's own guard never executed;
- with `-D_WASI_EMULATED_PROCESS_CLOCKS`, the header then declared `clock_t times (struct tms *);`
  and the patch's `static clock_t times(struct tms *buf)` failed as "static declaration of 'times'
  follows non-static declaration".

The patch now guards the include and both uses of what it supplies, with the same `#ifndef __wasi__`
in each place, and carries no `times()` stub: `GetProcessCPU()` already returned zeros without
calling `times()`, so the stub was never reachable and only ever collided. Widening an existing
condition was not available at `:27`, which is the usual answer and the one this page's rules ask
for first: the only condition in force there is the file-wide `#ifndef _WIN32`, and excluding WASI
from that sends WASI into the Windows branch below. The measurement is
`Scripts/repro/2179/run.sh`, which compiles the reduced probe and the real file, before and after,
in both configurations, and checks that the guards change nothing on native macOS.

**Unverified: `BuildTemporary()`'s WASI branch calls `getpid()`**, which wasi-libc supplies only
under `-D_WASI_EMULATED_GETPID` with `-lwasi-emulated-getpid`. See the next section. Unlike the
chronometer site, this one has not been reduced to a probe, so it stays a question for the first
compile that reaches it.

## CMake flags: none are passed

`Scripts/build-occt-wasm.sh` passes **no** WASI emulation define and links **no** emulation library.
An earlier version of this page listed `_WASI_EMULATED_PROCESS_CLOCKS`, `_WASI_EMULATED_GETPID`,
`-lwasi-emulated-process-clocks` and `-lwasi-emulated-getpid` under a "Required CMake Flags"
heading, and PR #2076's body claimed the build passed them. They exist on no branch that survived
that PR.

`_WASI_EMULATED_PROCESS_CLOCKS` was briefly the counter-example to that, and #2179 is why it no
longer is. `OSD_Chronometer.cxx` included `<sys/times.h>` unguarded, and that header `#error`s
without the define, so the define looked required; supplying it then broke the patch instead, by
declaring the `times()` the patch redeclared `static`. Either way was a hard error. The fix was to
guard the include and stop needing the define at all, which is what the patch now does. **No
emulation define is required by anything currently patched**, and the episode is the argument for
this section's rule rather than an exception to it.

`_WASI_EMULATED_GETPID` remains genuinely open, with `getpid()` in the directory patch as the one
concrete candidate. Nothing should be added to the build script on the strength of this page.

What the script **does** pass, since #2172, is the exception and setjmp flags: `WASM_CXX_EH_FLAGS`
from `Scripts/wasm-toolchain-versions.txt` plus `-mllvm -wasm-enable-sjlj`, in `CMAKE_CXX_FLAGS`,
reaching every translation unit. Those are not emulation defines and this section's rule does not
cover them. They are there because #2171 measured that their absence is silent, and because 44 of
the 119 `TKernel` objects that compile carry a compiled catch handler and 6 carry a lowered `setjmp`
pair. A preflight asserts they produce a handler before CMake starts.

## Gaps that are known and not yet closed

**Complete for `TKernel`, and measured rather than noticed.**
[#2172](https://github.com/SecondMouseAU/OCCTSwift/issues/2172) compiled all 127 of its source
files against the pinned toolchain in one pass: 119 compiled and 8 did not. Not one threading
diagnostic appears anywhere in the 127. The eight are below, with every diagnostic each one
produces at `-ferror-limit=0`, which is what makes this a list rather than a sample. They are the
subject of [#2173](https://github.com/SecondMouseAU/OCCTSwift/issues/2173), which writes them one
file per patch. `Scripts/repro/2172/run.sh guards` regenerates the list.

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

`Message/Message_PrinterSystemLog.cxx` was on no list before this compile, which is the argument
for running one.

**`Standard/Standard_MMgrOpt.cxx` needs no source change.** Recompiled with `-D_WASI_EMULATED_MMAN`
and nothing else altered, it produces zero errors. That is a candidate for the emulation define the
section above reserves for evidence, and the evidence is in `Scripts/repro/2172/README.md`; the link
half, `-lwasi-emulated-mman`, cannot be verified until #2174. At the other end, `_WASI_EMULATED_SIGNAL`
leaves `OSD/OSD_signal.cxx` with seventeen errors, because it supplies the `SIG*` constants and no
`struct sigaction`, `sigemptyset`, `sigaddset` or `SIG_UNBLOCK`, and OCCT's handling there is
`sigaction`-based throughout.

The modules beyond `TKernel` have not been compiled. Their gaps are #2174's to enumerate the same
way.

## How a new guard is written

Upstream OCCT already supports WebAssembly through Emscripten, and its guards are sitting at most of
these sites already. So:

- **Extend the condition that is there.** `|| defined(__wasi__)` added to an existing
  `defined(__EMSCRIPTEN__)` test is one token, and it leaves one structure for the next kernel bump
  to merge. A parallel `#ifdef __wasi__` block beside the existing condition is wrong even when it
  compiles. Exactly one of PR #2076's fifteen patches extended the existing condition; the other
  fourteen built the parallel structure, and three of those left files that no compiler could
  preprocess on any platform.
- **Guard the call site, not only the `#include`.** PR #2076's `OSD_Process` patch excluded
  `<pwd.h>` on WASI and left `getpwuid(getuid())` compiling below it.
- **Say in the patch header what the WASI branch returns, and why that value is safe for every
  caller.** `OSD_Directory::BuildTemporary` returning something that is not a directory is the
  cautionary case.
- **Author and verify against the patched tree**, meaning `Libraries/occt-src` after
  `Scripts/patches/` has been applied, not a pristine `V8_0_1` checkout.

## Related

- [`Scripts/patches-wasi/README.md`](../Scripts/patches-wasi/README.md), the directory's own rules
  and the reason it is separate from `Scripts/patches/`.
- [`docs/wasm-feasibility.md`](wasm-feasibility.md), the plan of record.
- [#1689](https://github.com/SecondMouseAU/OCCTSwift/issues/1689), the parent.
