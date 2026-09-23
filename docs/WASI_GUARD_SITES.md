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

### The shim is a consumer requirement too, not only OCCT's

`Scripts/build-occt-wasm.sh` force-includes the shim into OCCT's own compile. #2174 measured that
anything which merely **includes** OCCT needs it as well: **40 of the 7,160 files OCCT installs as
headers** name one of the eight, among them `Poly_Triangulation.hxx`, `GeomAdaptor_Curve.hxx`,
`BSplCLib_Cache.hxx`, `NCollection_IncAllocator.hxx` and `Message_ProgressIndicator.hxx`, which are
not obscure. A translation unit that includes `Poly_Triangulation.hxx` and no shim is eight errors,
measured, and `Scripts/repro/2174/run.sh libs` runs that as one of its negative cases.

That is a requirement on the **consumer's** build, which for this repo means `Package.swift`'s
`OCCTBridge` target and belongs to #2048. Nothing on the OCCT side needs to change for it.

## What is patched today

Eleven patches, one per file: ten under `src/FoundationClasses/TKernel/` and one under
`src/DataExchange/TKDESTEP/`. The last column is what the WASI branch does; each patch's own header
says why that is safe for every in-tree caller, names them, and says whether it extended a condition
that was already there or had to add one.

| File | Gap in wasi-libc | What the WASI branch does | Patch |
|---|---|---|---|
| `Message/Message_PrinterSystemLog.cxx` | `<syslog.h>`, `openlog`, `syslog` | `send()` writes the message to stderr; the constructor and destructor hold nothing | `wasi-message-printersyslog.patch` |
| `OSD/OSD_Chronometer.cxx` | `<sys/times.h>`, `times()`, `struct tms` | `GetProcessCPU()` reports 0.0 user and 0.0 system | `wasi-osd-chronometer.patch` |
| `OSD/OSD_Directory.cxx` | `umask()`, `mkdtemp()` | `Build()` skips the umask; `BuildTemporary()` names the directory itself | `wasi-osd-directory.patch` |
| `OSD/OSD_File.cxx` | `mkstemp()`, `F_RDLCK`/`F_WRLCK`/`F_UNLCK`/`F_SETLK`/`F_SETLKW` | `BuildTemporary()` creates the name from `getentropy()` with `O_EXCL`; `SetLock()`/`UnLock()` record the lock and call nothing, leaving `myError` untouched | `wasi-osd-file.patch` |
| `OSD/OSD_Host.cxx` | `<netdb.h>`, `gethostbyname()`, `struct hostent` | `InternetAddress()` returns an empty string; `uname()` and `gethostname()` are untouched and still work | `wasi-osd-host.patch` |
| `OSD/OSD_Path.cxx` | a populated `struct utsname` in the fallback branch | joins the `__EMSCRIPTEN__` arm and returns `OSD_LinuxREDHAT`, so paths parse with the Unix grammar | `wasi-osd-path.patch` |
| `OSD/OSD_Process.cxx` | `<pwd.h>`, `getpwuid()`, `getuid()` | `UserName()` returns an empty string, as it already does on Emscripten; `IsSuperUser()` returns false | `wasi-osd-process.patch` |
| `OSD/OSD_signal.cxx` | `<signal.h>`, `sigaction`, `sigemptyset`, `sigaddset`, `sigprocmask` | a third top-level arm installs no handler; `SetSignal()` leaves `OSD::SignalMode()` at `OSD_SignalMode_AsIs` and `ControlBreak()` never raises | `wasi-osd-signal.patch` |
| `Standard/Standard_MMgrOpt.cxx` | `<sys/mman.h>`, `mmap()`, `munmap()` | `Initialize()` leaves `myMMap` at 0, so `AllocMemory()`/`FreeMemory()` take the malloc/free path the class already implements | `wasi-standard-mmgropt.patch` |
| `Standard/Standard_StackTrace.cxx` | `<execinfo.h>`, `backtrace()` | joins the arm `OCCT_UWP` and iOS already take: a `Message_Trace` and `false` | `wasi-standard-stacktrace.patch` |
| `STEPConstruct/STEPConstruct_AP203Context.cxx` | `<pwd.h>`, `getpwnam()`, and `timezone` | the AP203 person is built from an empty `OSD_Process::UserName()` with no gecos lookup, as on Emscripten, so the record carries an empty name; the UTC offset is exactly zero, matching the `localtime()` that supplies the timestamp beside it | `wasi-stepconstruct-ap203context.patch` |

**`TKernel` builds 127 of 127 with these applied**, which is the whole of the toolkit and not a
sample; `Scripts/build-occt-wasm.sh --toolkit TKernel --require-complete` is the command that says
so and fails rather than prints if it ever stops being true.

Two properties of that set are worth keeping on the page.

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

**Settled at compile, open at link: `getpid()` has two sites.**
`OSD_Directory::BuildTemporary()`, from `wasi-osd-directory.patch`, and `OSD_Process::ProcessId()`,
which `wasi-osd-process.patch` deliberately leaves alone. wasi-libc declares `getpid()`
unconditionally and, without `-D_WASI_EMULATED_GETPID`, only marks it `__deprecated__`, so both
compile with one warning each and the build is not blocked. The library half,
`-lwasi-emulated-getpid`, is real and unverifiable until something links (#2174).

**The complete 127-file build emits four warnings and no more**, which is small enough to list:
those two `getpid` deprecations; `-Wunused-private-field` on `OSD_File::ImperativeFlag`, which
`wasi-osd-file.patch`'s header explains; and `unknown pragma ignored` at
`OSD_Chronometer.cxx:111`, which is upstream's own `#pragma error "OS is not supported yet"` in
`GetThreadCPU()`'s final `#else`. That last one is not ours: it fires for any OS OCCT's chain does
not name, and it is a warning rather than an error because clang does not implement
`#pragma error`. `GetThreadCPU()` zeroes both out-parameters on its own first line before the
chain runs, so WASI gets 0.0 and 0.0, the same answer `GetProcessCPU()` gives here.

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

**`_WASI_EMULATED_MMAN` was the strongest candidate and it was rejected, on a measurement rather
than on taste.** #2172 established that `Standard_MMgrOpt.cxx` compiles with **zero** errors under
that define and no source change, which is true and is not the question. `Scripts/repro/2173/run.sh
mman` builds, links and **runs** the `mmap()` call that file actually makes, under the pinned
toolchain: `mmap(0x60000000, 65536, PROT_READ | PROT_WRITE, MAP_PRIVATE, -1, 0)` returns
`MAP_FAILED` with `EBADF`, while the control, the same call with `MAP_ANON`, succeeds. The
emulation serves anonymous private mappings out of `malloc()` and refuses everything else, and
OCCT's generic branch passes no `MAP_ANON` and a file descriptor of -1. The define would therefore
have bought a file that compiles and an `AllocMemory()` that throws `Standard_OutOfMemory` on every
large block whenever `MMGT_OPT=1` is set. `wasi-standard-mmgropt.patch` leaves `myMMap` at 0
instead, which is a state the class already supports, and the build still passes no emulation
define and links no emulation library.

`_WASI_EMULATED_GETPID`'s **library** half is settled by #2174 and the answer is that
`-lwasi-emulated-getpid` is required as soon as a caller reaches one of the two sites,
`OSD_Directory::BuildTemporary()` or `OSD_Process::ProcessId()`. Both still compile without the
define, which is why this section's rule is unchanged; what is new is that a probe calling
`OSD_Process::ProcessId()` fails to link with `undefined symbol: getpid` and links and runs with the
library. A probe that reaches neither site links clean without it, which is why nothing before
#2174 could tell. The library goes on the link line of anything that reaches those sites; the
define still goes nowhere.

What the script **does** pass, since #2172, is the exception and setjmp flags: `WASM_CXX_EH_FLAGS`
from `Scripts/wasm-toolchain-versions.txt` plus `-mllvm -wasm-enable-sjlj`, in `CMAKE_CXX_FLAGS`,
reaching every translation unit. Those are not emulation defines and this section's rule does not
cover them. They are there because #2171 measured that their absence is silent, and because 44 of
the 119 `TKernel` objects that compile carry a compiled catch handler and 6 carry a lowered `setjmp`
pair. A preflight asserts they produce a handler before CMake starts, and #2174's link settles the
other half: without `-lsetjmp` the module fails on `__wasm_setjmp`, `__wasm_longjmp` and
`__c_longjmp`, and without wasi-sdk's `eh` `libc++abi` and `libunwind` it fails on
`__cxa_allocate_exception`, `__cxa_begin_catch` and `__cxa_end_catch`.

## Gaps that are closed, and what is left

**`TKernel` is complete: 127 of 127.** [#2172](https://github.com/SecondMouseAU/OCCTSwift/issues/2172)
compiled all 127 of its source files against the pinned toolchain in one pass and found that 119
compiled and 8 did not, with not one threading diagnostic anywhere in the 127.
[#2173](https://github.com/SecondMouseAU/OCCTSwift/issues/2173) closed all eight, one patch per
file, and the table under "What is patched today" is that list. `Scripts/repro/2173/run.sh guards`
recompiles each of the eight twice, once from its pre-image and once from the patched tree, so the
before and after numbers are re-derivable rather than remembered:

| File | Errors before its patch | After |
|---|---|---|
| `Message/Message_PrinterSystemLog.cxx` | 1 | 0 |
| `OSD/OSD_File.cxx` | 6 | 0 |
| `OSD/OSD_Host.cxx` | 1 | 0 |
| `OSD/OSD_Path.cxx` | 1 | 0 |
| `OSD/OSD_Process.cxx` | 1 | 0 |
| `OSD/OSD_signal.cxx` | 43 | 0 |
| `Standard/Standard_MMgrOpt.cxx` | 6 | 0 |
| `Standard/Standard_StackTrace.cxx` | 1 | 0 |

The five one-error rows are one-error because a missing header is a **fatal** diagnostic that ends
the translation unit, so nothing below it is ever reached. That is why each of those patches had to
be written iteratively rather than from the #2172 list alone: guarding `<pwd.h>` in
`OSD_Process.cxx` uncovered `getuid()` in `IsSuperUser()`, which wasi-libc does not declare either,
and guarding `<netdb.h>` in `OSD_Host.cxx` uncovered `struct hostent` in `InternetAddress()`. **A
guard-site list produced by compiling is complete for the files it names and not for the sites
inside them.**

`OSD/OSD_signal.cxx`'s 43 is measured without any emulation define, which is how the build runs;
#2172's figure of 17 for the same file is with `-D_WASI_EMULATED_SIGNAL`, which supplies the `SIG*`
constants and `signal()` and supplies no `sigaction`, `sigemptyset`, `sigaddset` or `SIG_UNBLOCK`.
Neither number is wrong and they measure different configurations.

**`Scripts/build-occt-wasm.sh --toolkit TKernel --require-complete` is now the command.** The flag
is new in #2173 and turns the "N of M source files compiled" line from something printed into
something asserted: it exits non-zero, naming the shortfall, unless every source file of the
toolkit produced an object and a real (not `-partial`) archive was linked. While eight failures
were the expected, intended result of #2172, exiting on the build tool's own status was right;
from #2173 onwards a regression would otherwise hand a reader the same status a complete build
does. `Scripts/repro/2173/run.sh negative` proves the flag by hiding one patch and rebuilding:
126 of 127 and exit 1.

**The rest of the module set is closed too, and it took one more file.**
[#2174](https://github.com/SecondMouseAU/OCCTSwift/issues/2174) compiled all 49 toolkits in one
`-k` pass and got 5,487 of 5,488 source files, with one gap, in `TKDESTEP`:

| Toolkit | File | Gap | Closed by |
|---|---|---|---|
| `TKDESTEP` | `STEPConstruct/STEPConstruct_AP203Context.cxx` | `<pwd.h>` at `:63`, `getpwnam()` at `:181`, `timezone` at `:125` | `wasi-stepconstruct-ap203context.patch` ([#2266](https://github.com/SecondMouseAU/OCCTSwift/issues/2266)) |

**With it the 49-toolkit build is 5,488 of 5,488, 0 missing, 0 unruled**, and
`Scripts/build-occt-wasm.sh` goes on to install, combine and copy headers, which its census had
been gating.

The file repeated #2173's shape exactly: a missing header is a fatal diagnostic, so one error was
one include and not one site. Closing `<pwd.h>` uncovered `getpwnam()` in
`DefaultPersonAndOrganization()`, and closing that uncovered `timezone` in `DefaultDateAndTime()`,
which wasi-libc keeps inside `__wasilibc_unmodified_upstream` under the comment "WASI has no
timezone tables". Three sites in one file, found one error at a time, which is why the gap list
#2174 produced was complete for the file it named and not for the sites inside it.

Two of the three extended the condition that was already there, the shared
`#if !defined(_WIN32) && !defined(__ANDROID__) && !defined(__EMSCRIPTEN__)` that upstream spells at
the include and at the only use. The third joined `DefaultDateAndTime()`'s existing
`#if`/`#elif`/`#else` chain as a new `#elif defined(__wasi__)` arm, inside that one structure: no
arm in the chain fits WASI, since `_MSC_VER` is Windows, the `__FreeBSD__` arm is gated on a version
macro upstream will retire, and the `#else` reads the `timezone` that is not there.

**What a STEP file written from wasm carries**, which is the part worth deciding rather than
inheriting. The person record is built from `OSD_Process::UserName()` with no gecos lookup, exactly
as on Windows, Android and Emscripten, and on WASI that name is empty
(`wasi-osd-process.patch`), as is `OSD_Host::InternetAddress()` (`wasi-osd-host.patch`). So the file
carries ORGANIZATION `IP`/`Unspecified` and a PERSON with id `IP,` and an empty name. The `"Unknown"`
in the `else` arm two lines below was considered and not taken: it is inside the block WASI now
skips, so keeping it would mean nesting a second condition in a block WASI does not enter, and it
would diverge from Emscripten, where an empty user name already yields an empty name. The UTC offset
is exactly zero, which is not a fallback either: `OSD_Process::SystemDate()` supplies the timestamp
beside it from `localtime()`, which wasi-libc resolves to UTC for the same reason, so the two agree.

**It was not an incidental file.** `STEPConstruct_ContextTool` references it unconditionally and the
STEP writer pulls that, so before this patch a module that writes STEP did not link: 20 undefined
symbols, measured in [`Scripts/repro/2174/README.md`](../Scripts/repro/2174/README.md).
`Scripts/repro/2174/run.sh link` now links `probe-step.wasm`, runs it under `wasmkit` and requires
an AP203 file carrying a PERSON, an ORGANIZATION and a COORDINATED_UNIVERSAL_TIME_OFFSET, and
`run.sh step-negative` is the negative case for that assertion.

The other 48 toolkits, 5,487 files, needed nothing. That includes the 682 files of
`ApplicationFramework` and `Visualization` that OCCT's CMake pulls in behind `DataExchange`, which
had the most platform surface on paper and needed no guard in practice.

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
- **When no condition exists to extend, say so in the patch header.** Three of the ten patches are
  in that position and each one names the site and the reason: extending the file-wide
  `#ifndef _WIN32` would send WASI into the Windows branch. An unexplained new `#ifdef` reads the
  same as the mistake.
- **Widen the hunk until every member it touches appears in context.**
  `check-wasi-patch-base.py`'s `FOREIGN_MEMBER` rule fails a patch whose added lines use a `my<Name>`
  member that no context line shows, because that is what a hunk pasted into the wrong class looks
  like. `wasi-osd-file.patch` is cut with `git diff -U20` for exactly this reason; the default three
  lines of context left `myFILE`, `myError` and `myLock` unattested.
- **Refuse honestly, and check what "refuse" costs the caller first.** `OSD_File::SetLock()` on WASI
  records the lock and sets no error, because `OSD_File::Read()`, `Write()`, `Seek()` and `Close()`
  all open with `if (Failed()) { Perror(); }` and `Perror()` raises. Recording a truthful refusal
  there would have turned "this platform has no file locking" into "the next read on this file
  throws". Which of the two is honest depends on what the class does with the error, so read that
  before choosing.

## Related

- [`Scripts/patches-wasi/README.md`](../Scripts/patches-wasi/README.md), the directory's own rules
  and the reason it is separate from `Scripts/patches/`.
- [`docs/wasm-feasibility.md`](wasm-feasibility.md), the plan of record.
- [#1689](https://github.com/SecondMouseAU/OCCTSwift/issues/1689), the parent.
