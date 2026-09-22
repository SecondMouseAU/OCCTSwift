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
[#2170](https://github.com/SecondMouseAU/OCCTSwift/issues/2170), exactly six names are gone and the
rest of the surface OCCT uses survives:

| Missing | Still present |
|---|---|
| `std::mutex` | `std::lock_guard` |
| `std::recursive_mutex` | `std::unique_lock` |
| `std::shared_mutex` | `std::once_flag` |
| `std::shared_lock` | `std::defer_lock` |
| `std::condition_variable` | `std::atomic`, `std::atomic_flag` |
| `std::this_thread::yield` | |

**One force-included shim header supplies those six names, and no OCCT source is patched for this
class at all.** The shim is wired into the WASI build's `CMAKE_CXX_FLAGS` as `-include` and is
tracked in #2170. A patch in `Scripts/patches-wasi/` that touches any of the six names is wrong by
construction, whether or not it compiles.

### Why a shim rather than patches

Two reasons, and the second is the expensive one.

**Patching per site does not terminate.** 76 files across the four modules this build compiles
(`FoundationClasses`, `ModelingData`, `ModelingAlgorithms`, `DataExchange`) use the missing names.
Fifteen of those 76 are files our own carried patches already modify, because nine carried patches
inject `std::mutex` or `std::recursive_mutex` as thread-safety fixes (#341, #344, #349, #353, #374,
#1153, #1154, #1157, #1403). `Standard_Mutex.hxx` is deprecated in 8.0.0 in favour of `std::mutex`,
and upstream's mutable-static-elimination series keeps converting more internals to it, so the
surface grows at every kernel bump.

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

The shim keeps the types and drops the enforcement, which is sound here for the reason
`docs/wasm-feasibility.md` already gives: the bridge serialises every OCCT call through one
`std::recursive_mutex`, TBB is off, and the runtime is single-threaded.

## What is patched today

| File | Site | Gap in wasi-libc | Patch |
|---|---|---|---|
| `src/FoundationClasses/TKernel/OSD/OSD_Chronometer.cxx` | `GetProcessCPU()` | `times()`, `struct tms` | `wasi-osd-chronometer.patch` |
| `src/FoundationClasses/TKernel/OSD/OSD_Directory.cxx` | `Build()` | `umask()` | `wasi-osd-directory.patch` |
| `src/FoundationClasses/TKernel/OSD/OSD_Directory.cxx` | `BuildTemporary()` | `mkdtemp()` | `wasi-osd-directory.patch` |

Two properties of that set are unverified, because no wasm build has completed:

- **The chronometer patch's `times()` stub sits inside the source's `#ifndef CLK_TCK` block**, so it
  exists only in translation units where `CLK_TCK` is undefined. The same patch also makes
  `GetProcessCPU()` return zeros without calling `times()` at all, so the stub may be dead weight
  rather than load-bearing. Which of the two it is gets settled by the first TKernel compile, not by
  reading.
- **`BuildTemporary()`'s WASI branch calls `getpid()`**, which wasi-libc supplies only under
  `-D_WASI_EMULATED_GETPID` with `-lwasi-emulated-getpid`. See the next section.

## CMake flags: none are passed

`Scripts/build-occt-wasm.sh` passes **no** WASI emulation define and links **no** emulation library.
An earlier version of this page listed `_WASI_EMULATED_PROCESS_CLOCKS`, `_WASI_EMULATED_GETPID`,
`-lwasi-emulated-process-clocks` and `-lwasi-emulated-getpid` under a "Required CMake Flags"
heading, and PR #2076's body claimed the build passed them. They exist on no branch that survived
that PR.

Whether any of them are actually required is a question for the first compile that gets far enough
to answer it, and `getpid()` in the directory patch is the one concrete candidate. Nothing should
be added to the build script on the strength of this page.

## Gaps that are known and not yet closed

Not a checklist, and not complete: the authority on what is missing is a compile, which is what
[#2172](https://github.com/SecondMouseAU/OCCTSwift/issues/2172) exists to run. What has been seen so
far, outside the threading class, all of it under `src/FoundationClasses/TKernel/OSD/`:

- `OSD_File.cxx`: `mkstemp()`, and `fcntl` record locking (`F_WRLCK`, `F_RDLCK`, `F_SETLKW`,
  `F_UNLCK`, `F_SETLK`).
- `OSD_Process.cxx`: `<pwd.h>` and the `getpwuid(getuid())` call that uses it.
- `OSD_signal.cxx`: POSIX signal handling.
- `OSD_Host.cxx`: `<netdb.h>` and `gethostbyname()`.
- `OSD_Path.cxx`: `struct utsname` and `uname()`.

These are the subject of [#2173](https://github.com/SecondMouseAU/OCCTSwift/issues/2173), which
writes them one file per patch.

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
