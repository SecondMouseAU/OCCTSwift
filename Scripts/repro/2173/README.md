---
nav_exclude: true
search_exclude: true
---

# #2173: the eight TKernel platform gaps, closed and measured

`run.sh` reproduces every number below. Like `Scripts/repro/2172/run.sh` it reads the compiler and
every flag out of the build tree CMake generated rather than restating them, so it cannot drift
from the build it describes.

    Scripts/build-occt-wasm.sh --toolkit TKernel --require-complete   # the build
    Scripts/repro/2173/run.sh                                         # guards, mman, archive
    Scripts/repro/2173/run.sh negative                                # the flag's own negative case
    Scripts/repro/2173/run.sh all                                     # everything, two rebuilds

## Measurements, 2026-09-23, macOS 27.0 arm64

Swift toolchain 6.4.0-RELEASE, Swift wasm SDK 6.4.0-RELEASE, wasi-sdk 34.0, all as pinned by
[`Scripts/wasm-toolchain-versions.txt`](../../wasm-toolchain-versions.txt). `Libraries/occt-src` at
`V8_0_1` plus all twenty-nine carried patches, which is the state
[`okf/policies/wasi-patch-base.md`](../../../okf/policies/wasi-patch-base.md) requires every patch
in `Scripts/patches-wasi/` to be authored and verified in.

### 127 of 127

| | Before #2173 | After |
|---|---|---|
| `TKernel` source files compiled | 119 of 127 | **127 of 127** |
| archive | `libTKernel-partial.a`, 119 members | `libTKernel.a`, **127 members** |
| archive size | 3,073,886 bytes | 3,154,798 bytes |
| defined symbols, `llvm-nm --defined-only` | 6,033 | 6,298 |
| members carrying 32-bit memory relocations | 105 | 113 |
| members carrying 64-bit memory relocations | 0 | 0 |

`llvm-ar`, `llvm-nm` and `llvm-objdump` are the **pinned** toolchain's, at
`/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin`. There is no `llvm-nm` on
the default macOS PATH at all, and host `nm -g` on a wasm object lists undefined symbols as though
they were defined. `file` cannot tell wasm32 from wasm64, measured in #2172, which is why the
relocation-width rows are there and the `file` row is not a wasm32 check.

### The eight, before and after

`run.sh guards` compiles each of the eight twice: once from the pre-image, which git hands it into
a scratch directory so the checkout is never mutated, and once from the patched tree.

| File | Errors before | After | Patch |
|---|---|---|---|
| `Message/Message_PrinterSystemLog.cxx` | 1 | 0 | `wasi-message-printersyslog.patch` |
| `OSD/OSD_File.cxx` | 6 | 0 | `wasi-osd-file.patch` |
| `OSD/OSD_Host.cxx` | 1 | 0 | `wasi-osd-host.patch` |
| `OSD/OSD_Path.cxx` | 1 | 0 | `wasi-osd-path.patch` |
| `OSD/OSD_Process.cxx` | 1 | 0 | `wasi-osd-process.patch` |
| `OSD/OSD_signal.cxx` | 43 | 0 | `wasi-osd-signal.patch` |
| `Standard/Standard_MMgrOpt.cxx` | 6 | 0 | `wasi-standard-mmgropt.patch` |
| `Standard/Standard_StackTrace.cxx` | 1 | 0 | `wasi-standard-stacktrace.patch` |

**The five ones are ones because a missing header is a fatal diagnostic**, which ends the
translation unit before anything below it is seen. That is the practical finding of this issue: the
#2172 list is complete for the files it names and is not complete for the sites inside them.
Guarding `<pwd.h>` in `OSD_Process.cxx` uncovered `getuid()` in `IsSuperUser()`, which wasi-libc
does not declare either; guarding `<netdb.h>` in `OSD_Host.cxx` uncovered `struct hostent` in
`InternetAddress()`. Both are exactly the defect PR #2076 shipped in this file, one level deeper.

`OSD_signal.cxx`'s 43 is measured with no emulation define, which is how the build runs. #2172's
17 for the same file is with `-D_WASI_EMULATED_SIGNAL`. The two configurations differ; neither
number is wrong.

### Why `Standard_MMgrOpt.cxx` is patched rather than answered with `-D_WASI_EMULATED_MMAN`

This is the one file of the eight a build flag could have answered, and #2172's measurement that it
compiles with **zero** errors under `-D_WASI_EMULATED_MMAN` is correct. It is also not the
question. `run.sh mman` compiles, links and **runs** the call the file actually makes:

    Standard_MMgrOpt's call  mmap(0x60000000, 65536, PROT_READ|PROT_WRITE, MAP_PRIVATE, fd=-1)
                             -> MAP_FAILED (errno 8, Bad file descriptor)
    control                  mmap(NULL, 65536, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, fd=-1)
                             -> ok (errno 0, Success)

wasi-libc's emulation serves anonymous private mappings out of `malloc()` and refuses everything
else. `Standard_MMgrOpt.cxx` defines `MMAP_FLAGS` as `(MAP_PRIVATE)` for every platform its `#elif`
chain does not name, and `Initialize()` leaves `myMMap` at -1 for those same platforms, so the
define would have bought a file that compiles and an `AllocMemory()` that throws
`Standard_OutOfMemory` on every large block for as long as `MMGT_OPT=1` is set in the host
environment. The control is in the probe so that a failure is a statement about OCCT's flags rather
than about `mmap()` being absent.

`wasi-standard-mmgropt.patch` leaves `myMMap` at 0 instead, which is the state the class is already
in on every platform where `MMGT_MMAP` is off, and the build still passes no emulation define and
links no emulation library. The second half of the argument is that `-lwasi-emulated-mman` cannot
be verified by anything until the full library links (#2174), and
[`docs/WASI_GUARD_SITES.md`](../../../docs/WASI_GUARD_SITES.md) reserves adding an emulation flag
to the build script for evidence that covers both halves.

Worth recording for scale: this build never instantiates the class at all. OCCT selects
`Standard_MMgrOpt` only under `OCCT_MMGT_OPT_FLEXIBLE`, which
`src/FoundationClasses/TKernel/CMakeLists.txt` defines only when `USE_MMGR_TYPE` is `FLEXIBLE`, and
`Scripts/build-occt-wasm.sh` leaves it at OCCT's `NATIVE` default. The patch is written to be
correct under `FLEXIBLE`, not to be correct only here.

### `--require-complete`, and its negative case

`Scripts/build-occt-wasm.sh --toolkit TKernel` prints `N of M source files compiled` and exits with
whatever the build tool returned. While eight failures were the expected result of #2172 that was
the right behaviour, and the review on PR #2187 is where the next step was set down: the flag
arrives with the work that makes it satisfiable, so the change from "eight expected failures" to
"zero tolerated failures" is a reviewable line rather than a silent change of meaning.

`--require-complete` turns the count into the assertion. It fails, naming the shortfall, unless
every source file produced an object, a real (not `-partial`) archive was linked, and the
denominator is not zero; the last clause is #2098's rule that a check which examined nothing must
fail rather than pass. It requires `--toolkit`, because the full build runs without `-k` under
`set -e` and already stops at the first file that does not compile.

Proved rather than assumed, per
[`okf/policies/prove-the-test-fails.md`](../../../okf/policies/prove-the-test-fails.md).
`run.sh negative` hides `wasi-standard-stacktrace.patch`, restores `Standard_StackTrace.cxx` to its
pre-image, and rebuilds:

    hidden: wasi-standard-stacktrace.patch; Standard_StackTrace.cxx is back at its pre-image
    exit status: 1  (0 would mean the flag does not work)
    >>> TKernel: 126 of 127 source files compiled.
    ERROR: --require-complete was given and TKernel is INCOMPLETE:
           126 of 127 source files compiled, 1 short.
    restored: wasi-standard-stacktrace.patch
    restore build exit status: 0
    >>> COMPLETE: 127 of 127, as --require-complete demands.

The restore runs on a trap, so an interrupted run still puts the patch back.

One correction to the review comment that asked for the flag: as of `aabfc1c7` the script does
**not** exit 0 on an incomplete `--toolkit` build. `make -k` returns 2 and the script passes that
through, measured on the 119-of-127 baseline before any of this work. What is true, and is what the
flag fixes, is that the exit status is the **build tool's** rather than a statement about the
toolkit, and the two counts are printed and never compared.

## What this does not establish

- **Nothing here is linked.** 127 objects in an archive; no `wasm-ld` has run over them. The libc++
  seam, `-lsetjmp`, `-lwasi-emulated-getpid` and the link order are all #2174's.
- **Nothing here is run**, except the `mmap` probe. Every claim about what a WASI branch returns is
  an argument from the source and its callers, written into each patch's header, not an
  observation of OCCT executing on a wasm runtime.
- **One toolkit.** The other three modules this build compiles are unmeasured, and #2174 enumerates
  their gaps the same way: by compiling.

## Related

- [`Scripts/repro/2172/README.md`](../2172/README.md), where the eight came from.
- [`docs/WASI_GUARD_SITES.md`](../../../docs/WASI_GUARD_SITES.md), the guard-site record.
- [`Scripts/patches-wasi/README.md`](../../patches-wasi/README.md), the patch directory's rules.
- [`okf/policies/wasi-patch-base.md`](../../../okf/policies/wasi-patch-base.md), how these are cut.
