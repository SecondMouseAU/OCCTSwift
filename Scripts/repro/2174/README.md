---
nav_exclude: true
search_exclude: true
---

# #2174: `libOCCT-wasm.a` for the full module set, linked and run

`run.sh` reproduces every number below. Like [`Scripts/repro/2172/run.sh`](../2172/run.sh) and
[`Scripts/repro/2173/run.sh`](../2173/run.sh) it reads the compiler, the sysroot and every flag out
of the build tree CMake generated rather than restating them, so it cannot drift from the build it
describes.

    Scripts/build-occt-wasm.sh                # the build: 49 toolkits, one pass, with -k
    Scripts/build-occt-wasm.sh --census-only  # the same completeness census, no rebuild
    Scripts/repro/2174/run.sh partial         # the archive, while one file does not compile
    OCCT_WASM_ARCHIVE=Libraries/occt-build-wasm/libOCCT-wasm-partial.a \
        Scripts/repro/2174/run.sh             # everything below

Measurements, 2026-09-23, macOS 27.0 arm64. Swift toolchain 6.4.0-RELEASE, Swift wasm SDK
6.4.0-RELEASE, wasi-sdk 34.0, all as pinned by
[`Scripts/wasm-toolchain-versions.txt`](../../wasm-toolchain-versions.txt). `Libraries/occt-src` at
`V8_0_1` plus all twenty-nine carried patches plus the ten WASI patches, which is the state
[`okf/policies/wasi-patch-base.md`](../../../okf/policies/wasi-patch-base.md) requires.

`llvm-ar`, `llvm-nm` and `llvm-objdump` are the **pinned** toolchain's, at
`/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin`. There is no `llvm-nm` on
the default macOS PATH at all, and host `nm -g` on a wasm object lists undefined symbols as though
they were defined, which has already produced two wrong conclusions in this initiative.

## The headline

**OCCT links and runs on `wasm32-unknown-wasip1`.** A C++ `main` over an archive of every object the
49-toolkit build produces constructs and releases a `Handle`, builds a solid, measures its volume,
meshes it, makes OCCT raise a `Standard_Failure` from inside its own compiled code and catches it,
under `wasmkit`, with no Swift and no bridge anywhere in the picture. It gzips to 2.4 MB and
brotlis to 1.9 MB.

All three of the link-only risks [#2171](https://github.com/SecondMouseAU/OCCTSwift/issues/2171)
recorded as unreachable are now measured, and all three resolve in the port's favour. The libc++
seam, which #2171 called the one worth re-checking at OCCT scale, turns out not to be a race at
all.

**One source file of 5,488 does not compile**, `TKDESTEP`'s `STEPConstruct_AP203Context.cxx`, and it
is on the STEP writer's own path, so a STEP module does not link and the real `libOCCT-wasm.a`
cannot be written yet. That gap is recorded here and handed on, not patched here.

Six defects turned up on the way, five of them in merged code and each invisible to every check
that existed. The sixth is in this issue's own new code and the build caught it within the hour.

| Defect | What it did | How it read |
|---|---|---|
| the combine step nested instead of flattening | `libOCCT-wasm.a` defined **zero** symbols | the file existed, and its size was within 400 bytes of the correct one |
| the completeness regex could not match a dot in a file name | the denominator was 2 short in `TKExpress` and 2 short in `TKDESTEP` | `--require-complete` would have said COMPLETE with a generated parser missing |
| the same regex named only the `cxx` and `c` extensions | `TKMesh`'s vendored `.cpp` had no rule, so it reported **67 of 66** | an object on disk that the denominator does not know about |
| the census subtracted one grand total from the other | a toolkit one short and a toolkit one over cancelled | `TOTAL 5487 of 5487` and `0 source file(s) did not compile`, with two toolkits wrong |
| the header copy filtered on three extensions | all 382 `.lxx` files were dropped | thousands of headers were copied, so "did any land" passed |
| the header copy rebuilt the install tree's structure | headers landed one level below where `Package.swift` looks | nothing had ever compiled against the tree, so nothing said so |

## The combine step did not produce a linkable archive

`Scripts/build-occt-wasm.sh` built the combined library with
`for lib in "${static_libs[@]}"; do llvm-ar rcs libOCCT-wasm.a "$lib"; done`. **`llvm-ar r` inserts
each operand as a member**, so given per-toolkit `.a` files it produces an archive whose members are
archives. `run.sh combine` reproduces it on two real toolkit archives, `libTKernel.a` and
`libTKMath.a`:

|  | `llvm-ar rcs` in a loop | `llvm-ar -M` / `addlib` |
|---|---|---|
| members | 2 | 268 |
| of which are themselves archives | **2** | 0 |
| defined symbols, `llvm-nm --defined-only` | **0** | 13,544 |
| size, bytes | 6,483,536 | 6,483,168 |
| `[ -f ] && [ -s ]`, the check that was there | PASSES | PASSES |

The two sizes differ by 368 bytes in 6.5 MB, which is the point: **a size taken off the broken
archive looks exactly right**, and the script's own check accepted it. What `wasm-ld` says, and the
only thing that would have said anything:

    wasm-ld: warning: nested.a: archive member 'libTKernel.a' is neither Wasm object file nor LLVM bitcode
    wasm-ld: warning: nested.a: archive member 'libTKMath.a' is neither Wasm object file nor LLVM bitcode

The macOS sibling, `Scripts/build-occt.sh`, uses `libtool -static`, which flattens. `llvm-ar` has no
`-static`; an MRI script does, because `addlib` means "add the MEMBERS of that archive" where `r`
means "add that file". The MRI script also arrives on stdin, so it has no `ARG_MAX` ceiling, which
is what the incremental loop was for.

The fix carries its own checks, and `run.sh combine` runs all three against both archives, which is
the negative case [`prove-the-test-fails`](../../../okf/policies/prove-the-test-fails.md) asks for:

    nested   members=2      archive-members=2    symbols=0        REJECTED: defines no symbols
    flat     members=268    archive-members=0    symbols=13544    accepted

## The completeness denominator was four source files short

#2172 derived a toolkit's expected object count with
`grep -oE "CMakeFiles/${tk}\.dir/[A-Za-z0-9_/]+\.(cxx|c)\.obj"`. That character class cannot match a
source file name containing a dot, and OCCT has four, all generated parsers:

| Toolkit | Real | Under the old regex | Invisible to it |
|---|---|---|---|
| `TKExpress` | 63 | 61 | `ExprIntrp/ExprIntrp.tab.c`, `ExprIntrp/lex.ExprIntrp.c` |
| `TKDESTEP` | 1,735 | 1,733 | `StepFile/lex.step.cxx`, `StepFile/step.tab.cxx` |

So `--require-complete` would have reported either toolkit COMPLETE with one of its parsers
missing, and `TKDESTEP`'s parser is the STEP reader that #1689's scope is built on. `TKernel`, which
is every toolkit #2172 and #2173 ever counted, has no such file, which is why one toolkit could not
find this. The class is now `[^ :]+`.

## The libc++ seam is not link-order dependent

This is the question #2171 left open in the strongest terms: WASI.sdk's prebuilt `libc++.a`
references no `__cxa_throw`, so its copies of `std::__throw_*` **abort** where wasi-sdk's `eh`
runtime throws; those symbols are weak; our definition won #2171's small link; and #2171 recorded
that the outcome was link-order dependent and had to be re-checked at OCCT scale.

Re-checked at OCCT scale it passes, and the reason is better than "it won again". The two
definitions **cannot collide, because they do not share a name.** libc++ gives every header-inline
symbol an ABI tag built from the ODR-relevant properties of the build, and whether exceptions are
enabled is one of them. From the pinned sysroot's own `__config`:

```c
#  if !_LIBCPP_HAS_EXCEPTIONS
#    define _LIBCPP_EXCEPTIONS_SIG n
#  else
#    define _LIBCPP_EXCEPTIONS_SIG e
#  endif

#  define _LIBCPP_ODR_SIGNATURE \
    _LIBCPP_CONCAT(_LIBCPP_CONCAT(_LIBCPP_HARDENING_SIG, _LIBCPP_EXCEPTIONS_SIG), _LIBCPP_VERSION)
```

and the symbols, measured with the pinned `llvm-nm`:

| Where | `std::__throw_out_of_range(const char*)`, mangled | Exceptions |
|---|---|---|
| our own object, compiled with the build's flags | `_ZNSt3__220__throw_out_of_rangeB8n`**`e`**`210106EPKc` | on |
| WASI.sdk's prebuilt `libc++.a` | `_ZNSt3__220__throw_out_of_rangeB8n`**`n`**`210106EPKc` | off |
| wasi-sdk's `eh` `libc++.a` (LLVM 23) | `_ZNSt3__220__throw_out_of_rangeB9nqe230100EPKc` | on, different version |

The aborting definition is spelled `nn210106` and **nothing compiled with exceptions ever
references that name**. libc++'s own comment on the tag says as much: "This ensures that no ODR
violation can arise from mixing two TUs compiled with different [ODR-relevant properties]". The
seam is safe by construction rather than by link order, and 68 members of WASI.sdk's `libc++.a`
are pulled into the module without incident, because what they supply (`locale`, `ios`, `string`,
`stdexcept`'s exception classes) is not ABI-tagged and does not differ.

The probe's case 5 is the behavioural half of the same claim: `std::vector<int>::at(3)` on a vector
of size 1 raises, and `catch (const std::out_of_range&)` fires. The aborting definition would not
have reached the catch.

## `operator new` throws `std::bad_alloc`

#2171's second open question, "which of the two runtimes supplies `operator new` decides whether it
throws or aborts", unprobed there. `probe-alloc.cxx` asks for 3.5 GB, which a 32-bit linear memory
cannot satisfy whatever the allocator does:

    requesting 3670016000 bytes with operator new[]...
    caught std::bad_alloc: std::bad_alloc
    exit status: 0

So an OCCT allocation failure under the wasm32 4 GB ceiling is a C++ exception the bridge can catch,
not a trap.

## The 49 toolkits: 5,487 of 5,488

One `cmake --build . -- -k` pass over the whole configure, 69 minutes on 10 cores, then a census of
every toolkit against the object rules CMake generated for it.

| | |
|---|---|
| toolkits | **49**, across six modules |
| source files with an object rule | **5,488** |
| compiled | **5,487** |
| did not compile | **1** |
| objects on disk with no rule | 0 |
| per-toolkit archives produced | 48 of 49 |

`Scripts/build-occt-wasm.sh --census-only` re-derives that table over the finished tree in about a
second, and `Scripts/repro/2174/run.sh census-negative` proves it can see an absence: hiding one
object takes the missing count from 1 to 2, names the file, and restoring it puts the count back.

### The one file, and it is not an incidental one

| Toolkit | File | Gap |
|---|---|---|
| `TKDESTEP` | `STEPConstruct/STEPConstruct_AP203Context.cxx` | `<pwd.h>` at `:64`, and `getpwnam()` at `:181` below it |

Its include sits behind `#if !defined(_WIN32) && !defined(__ANDROID__) && !defined(__EMSCRIPTEN__)`,
a guard upstream already widens for the other wasm platform it supports, and the only use is
`getpwnam(user)` to turn a user name into a gecos full name when writing an AP203 person record.
The `else` arm two lines down already answers "no user name" with `"Unknown"`, so the class handles
not resolving one.

**Its consequence is measured rather than assumed.** `probe-step.cxx` writes a STEP file, and it
does not link: 20 undefined symbols, every one a member of `STEPConstruct_AP203Context`, all
referenced from `STEPConstruct_ContextTool.cxx.obj`, which the STEP writer pulls unconditionally.
So this single file is on the path #1689's scope is built around, and closing it is what stands
between this build and a complete `libOCCT-wasm.a`. Per this issue's scope the patch is **not**
written here; the gap is handed on the way #2172 handed its eight to #2173.

Expect #2173's shape to repeat: a missing header is a fatal diagnostic, so one error means one
include and not one site, and guarding it uncovers whatever was below it. Here that is already
visible: the include is one error and `getpwnam` is the second.

### The counting was wrong three times, in two directions

#2172 derived the denominator with
`grep -oE "CMakeFiles/${tk}\.dir/[A-Za-z0-9_/]+\.(cxx|c)\.obj"`, and the full module set broke it
three ways. `TKernel`, which is every toolkit #2172 and #2173 ever counted, has none of the three
shapes.

| Defect | Where | Measured |
|---|---|---|
| the character class cannot match a dot in a file name | `TKExpress`'s two generated parsers | counted 61 against a real 63 |
| the same | `TKDESTEP`'s two generated parsers | counted 1,733 against a real 1,735 |
| the extension list named `cxx` and `c` only | this configure compiles nine `.cpp` files, one of them `TKMesh`'s vendored `BRepMesh/delabella.cpp` | counted 66 against a real 67, so the toolkit reported **67 of 66** |

The first two make `--require-complete` say COMPLETE with a generated parser missing. The third puts
an object on disk that no rule accounts for, which means the denominator does not describe the
build and no number derived from it is worth anything. The pattern is now `[^ :]+\.obj`: it names
the object and nothing about the source, because naming part of a source file name is a guess about
someone else's build system.

### And the totals cancelled

Worth writing down because it is the exact failure this effort exists to remove, in this issue's own
new code. With `TKDESTEP` one object short and `TKMesh` one object over, a census that subtracted
one grand total from the other printed:

    TOTAL            5487 of 5487 across 49 toolkits
    ERROR: 0 source file(s) did not compile, in 2 toolkit(s).

A green total, an error naming no files, and two toolkits wrong. Shortfalls are now summed per
toolkit, surpluses are counted separately and fail on their own, and the TOTAL line carries both:

    TOTAL             5487 of 5488  across 49 toolkits, 1 missing, 0 unruled

## The combined archive

`libOCCT-wasm.a` proper cannot be written while a toolkit is short, and
`Scripts/build-occt-wasm.sh` refuses to: its census gates install and combine, which is the whole
point of it. What is measured instead is `libOCCT-wasm-partial.a`, every object that compiled,
under a name that cannot be mistaken for the real thing, exactly as #2172 did with
`libTKernel-partial.a`.

| Property | Value |
|---|---|
| path | `Libraries/occt-build-wasm/libOCCT-wasm-partial.a` |
| members | 5,487 objects |
| members that are archives | **0** |
| defined symbols, `llvm-nm --defined-only` | **291,081** |
| size | 163,252,434 bytes |
| size, gzipped | 35,982,070 bytes |
| first member, `file(1)` | `WebAssembly (wasm) binary module version 0x1 (MVP)` |
| its memory relocations | `R_WASM_MEMORY_ADDR_I32`, `R_WASM_MEMORY_ADDR_REL_SLEB`, so wasm32 |

`file` cannot tell wasm32 from wasm64, measured in #2172, which is why the relocation row is there
and the `file` row is not a wasm32 check.

Per toolkit, from `run.sh partial`. Four toolkits are more than 10 MB and `TKDESTEP` has no archive
at all:

| Toolkit | Bytes | Members | Defined symbols |
|---|---|---|---|
| `TKBool` | 12,322,256 | 240 | 17,917 |
| `TKGeomAlgo` | 11,366,736 | 364 | 19,454 |
| `TKDEIGES` | 10,600,510 | 460 | 22,864 |
| `TKGeomBase` | 10,346,722 | 291 | 14,553 |
| `TKShHealing` | 8,818,696 | 112 | 10,016 |
| `TKTopAlgo` | 8,079,856 | 156 | 12,384 |
| `TKBO` | 7,913,834 | 88 | 11,644 |
| `TKV3d` | 7,628,970 | 203 | 13,697 |
| `TKBRep` | 5,819,608 | 111 | 8,563 |
| `TKFillet` | 5,785,316 | 114 | 8,199 |
| `TKOffset` | 5,321,388 | 34 | 5,519 |
| `TKXSBase` | 5,024,222 | 198 | 11,933 |
| `TKFeat` | 3,366,990 | 35 | 4,357 |
| `TKG3d` | 3,343,622 | 99 | 7,597 |
| `TKMath` | 3,328,504 | 141 | 7,246 |
| `TKernel` | 3,154,798 | 127 | 6,298 |
| `TKStd` | 3,058,144 | 28 | 5,516 |
| `TKMesh` | 2,834,662 | 67 | 4,490 |
| `TKHLR` | 2,433,094 | 86 | 3,955 |
| `TKService` | 2,203,114 | 103 | 5,764 |
| `TKLCAF` | 2,108,646 | 95 | 5,223 |
| ...27 more, all under 2 MB | | | |
| **`TKDESTEP`** | **no archive** | | |

`run.sh partial` prints all 48.

## The smoke link, and what it runs

Three executables, all C++, no Swift and no bridge anywhere, linked with the pinned toolchain
against the archive above and run under `wasmkit`.

### `probe.wasm`, 8,700,335 bytes

    OCCT smoke probe, wasm32-unknown-wasip1, C++ only (no Swift, no bridge)
    case handle                 PASS  Geom_CartesianPoint(1,2,3) x+y+z=6.0, refcount 1 held=1, 2 holders=2
    case raise-from-occt        PASS  MakeBox(0,0,0) raised from TKPrim and was caught as Standard_DomainError
    case modelling              PASS  box 10x20x30 volume=6000.0 faces=6 edges=12
    case mesh                   PASS  IsDone=1 triangles=12 nodes=24
    case libcxx-seam            PASS  vector::at(3) on size 1 threw std::out_of_range: vector
    failures: 0

The raise is the one the issue asked for and it is deliberately not local: `BRepPrimAPI_MakeBox(0,0,0)`
reaches `BRepPrim_GWedge.cxx`, which `throw`s `Standard_DomainError` from a `TKPrim` object of the
archive, and the handler is in the probe. So the unwinder crosses the archive boundary rather than
staying inside one translation unit, which is what #2171 could not test.

**One correction to the probe, recorded because it is the fixture trap
[`measure-dont-assume`](../../../okf/policies/measure-dont-assume.md) describes.** The modelling
case first counted edges with a `TopExp_Explorer` and asserted 12. An explorer visits a shared
sub-shape once per owner, so a box yields 24, and the probe reported FAIL against a perfectly
correct solid. `TopExp::MapShapes` counts the 12.

### `probe-alloc.wasm`, 168,088 bytes

    requesting 3670016000 bytes with operator new[]...
    caught std::bad_alloc: std::bad_alloc

A separate executable because the answer might have been a trap, and a trap would have taken every
other case with it.

### `probe-step.wasm`, which does not link

Covered above: it is the measurement of what the one uncompiled file costs.

## The three risks #2171 left open

### The libc++ seam is not link-order dependent

#2171 recorded this as the one to re-check at OCCT scale: WASI.sdk's prebuilt `libc++.a` references
no `__cxa_throw`, so its `std::__throw_*` helpers **abort** where wasi-sdk's `eh` runtime throws;
our definition won that spike's link; and weak symbols make which one wins a property of link order.

It is not a race. libc++ ABI-tags every header-inline symbol with `_LIBCPP_ODR_SIGNATURE`, and
whether exceptions are enabled is one of the properties that tag encodes:

```c
#  if !_LIBCPP_HAS_EXCEPTIONS
#    define _LIBCPP_EXCEPTIONS_SIG n
#  else
#    define _LIBCPP_EXCEPTIONS_SIG e
#  endif
```

So the three definitions in play have three different names, measured with the pinned `llvm-nm`:

| Where | `std::__throw_out_of_range(const char*)` | Exceptions |
|---|---|---|
| the OCCT archive, and our own objects | `_ZNSt3__220__throw_out_of_rangeB8n`**`e`**`210106EPKc` | on |
| WASI.sdk's prebuilt `libc++.a` | `_ZNSt3__220__throw_out_of_rangeB8n`**`n`**`210106EPKc` | off |
| wasi-sdk's `eh` `libc++.a`, LLVM 23 | `_ZNSt3__220__throw_out_of_rangeB9nqe230100EPKc` | on, other version |

**Nothing compiled with exceptions can reference the aborting name.** libc++'s own comment on the
tag says so: it exists "to ensure that no ODR violation can arise from mixing two TUs compiled with
different" ODR-relevant properties. The link bears it out: 68 members of WASI.sdk's `libc++.a` are
pulled into the module, and `--why-extract` shows **none** of them pulled for a `__throw_` helper.
Case 5 is the behavioural half: a `std::out_of_range` raised inside a 163 MB OCCT archive is
caught.

The tags carry the library version, so they will change at the next SDK bump. `run.sh libs` prints
them rather than asserting them, for that reason.

### `operator new` throws `std::bad_alloc`

Unprobed in #2171. A 3.5 GB request, which a 32-bit linear memory cannot satisfy whatever the
allocator does, raises and the catch fires. An OCCT allocation failure under the wasm32 ceiling is
therefore a C++ exception the bridge can catch, not a trap.

### `-lsetjmp`, `-lwasi-emulated-getpid`, and the rest of the link line

Every one of these is a claim that something is load-bearing, and each is worth nothing until the
link has been watched to fail without it. `run.sh libs` removes one piece at a time:

| Removed | Result |
|---|---|
| `-lsetjmp` | link fails: `undefined symbol: __wasm_setjmp`, `__wasm_longjmp`, `__c_longjmp` |
| `-L<wasi-sdk eh> -lc++abi -lunwind` | link fails: `undefined symbol: __cxa_allocate_exception`, `__cxa_begin_catch`, `__cxa_end_catch` |
| the compiler-rt resource directory | fails before the link: `cannot open .../libclang_rt.builtins.a` |
| the threading shim | 8 compile errors, `no type named 'mutex' in namespace 'std'` and friends |

`-lsetjmp` is now settled rather than predicted: #2172 measured six `TKernel` objects carrying a
lowered `setjmp` pair, and this is the link that needs them.

**`-lwasi-emulated-getpid` is settled too, and the answer is "yes, when a caller reaches it".**
`docs/WASI_GUARD_SITES.md` has carried it as genuinely open. Two members of the archive reference
`getpid`, and `probe.wasm` pulls neither, so it links clean without the library; that is why the
question could not be answered by the main probe. `probe-getpid.cxx` calls
`OSD_Process::ProcessId()` directly:

| | |
|---|---|
| without `-lwasi-emulated-getpid` | link fails, `undefined symbol: getpid` |
| with it | links, and runs: `OSD_Process::ProcessId() = 42` |

### The threading shim is a consumer requirement, not only OCCT's

New, and it belongs to #2048 rather than here. `Scripts/build-occt-wasm.sh` force-includes
`Scripts/wasm-shims/wasi-std-threading.hpp` into OCCT's own compile. Anything that merely
**includes** OCCT needs it as well: `Message_ProgressIndicator.hxx`, `NCollection_IncAllocator.hxx`
and `Poly_Triangulation.hxx` name `std::mutex` and `std::shared_mutex` in **public** headers, and 40
of the 7,160 files OCCT installs as headers name one of the eight shimmed names. A translation unit that includes
`Poly_Triangulation.hxx` is eight errors without the shim, measured, which is the last row of the
table above. That is a requirement on `Package.swift`'s `OCCTBridge` target.

## Host imports, for #2052

A linked wasip1 module's host imports are its remaining undefined symbols, each named
`__imported_wasi_snapshot_preview1_<field>`.

| Module | `wasi_snapshot_preview1` imports | Imports from any other module |
|---|---|---|
| a hello-world C program, the control | 5: `fd_close`, `fd_fdstat_get`, `fd_seek`, `fd_write`, `proc_exit` | 0 |
| `probe-alloc.wasm` | 7: the five, plus `environ_get`, `environ_sizes_get` | 0 |
| **`probe.wasm`, OCCT** | **10**: those seven, plus `fd_prestat_dir_name`, `fd_prestat_get`, `fd_read` | 0 |

So **OCCT itself adds five to a C program's five**, and all ten are in the set a Swift-over-C++
wasip1 module already imports. The three OCCT adds over the allocation probe are the preopen and
read calls, which is the virtual filesystem: `fd_prestat_get` and `fd_prestat_dir_name` are how
wasi-libc discovers preopened directories at startup, and OCCT pulls them because it opens files.
Nothing here needs a host function beyond `wasi_snapshot_preview1`, which is what the browser-side
question in #2052 was about.

## Sizes, as distribution facts

| | Uncompressed | `gzip -9` | `brotli -q 11` |
|---|---|---|---|
| `libOCCT-wasm-partial.a` | 163,252,434 | 35,982,070 | |
| `probe.wasm` | 8,700,335 | 2,448,993 | **1,887,026** |
| `probe-alloc.wasm` | 168,088 | 62,398 | 52,908 |

**The archive's size is not a budget fact.** `wasm-ld` pulls only the members that resolve an
undefined symbol, so the linked module is a subset: 163 MB of archive produced an 8.7 MB module.
A bigger archive does not make a bigger module.

**`probe.wasm` is the first number comparable to `occt-wasm`'s ~4.5 MB brotli**, and brotli is the
column to read it in, since comparing a gzip size against a brotli one is the like-for-like mistake
this issue's own body warns about. At **1.89 MB brotli** it is well under that figure.

Read it as a floor and not as an answer. It carries no Swift runtime, no Foundation and no bridge,
and `wasm-ld` pulled only the OCCT that five small cases reach: a box, a volume, a mesh and a
raise. A module that also reads and writes STEP will pull `TKDESTEP`, `TKXSBase` and the XCAF chain,
which is 16 MB of archive on its own. #2175's module is the comparable measurement, and #1689's
5 MB figure is a target rather than a gate either way.

The header tree is **not** sized here. What the build script now produces is a flat copy of
`occt-install-wasm/include/opencascade`, and packaging is blocked by the census, so no such tree
exists to measure. The build tree's `include/opencascade` is 7,072 one-line forwarding stubs with
absolute paths into `Libraries/occt-src`, and its size is a fact about this machine.

## Two defects in the artefacts nobody had consumed

Both in the header-copy step, and both found the same way: by being the first work to compile
against what `Scripts/build-occt-wasm.sh` produces rather than against what it builds.

1. **382 `.lxx` files were dropped.** The copy filtered on `*.h`, `*.hxx` and `*.inl`. OCCT installs
   382 `.lxx` files and each is `#include`d by the `.hxx` of the same name, so a consumer fails on
   `Contap_Point.lxx file not found` the moment it includes `Contap_Point.hxx`. The check was "did
   any header land", and thousands had.
2. **The tree was one directory too deep.** The copy rebuilt the install tree's structure, leaving
   headers at `occt-headers-wasm/include/opencascade/`, and `Package.swift` reads
   `.headerSearchPath("occt-headers-wasm")`. Nothing this script had ever produced could be compiled
   against by the manifest that names it.

`Scripts/build-occt.sh`, the macOS and iOS sibling, has done `cp -R
occt-install-*/include/opencascade/* occt-headers/` all along: flat, and with no extension filter.
The wasm script now does the same, and counts the files on both sides rather than asking whether
any arrived.

## What this does not establish

- **`libOCCT-wasm.a` itself does not exist yet**, and neither does `occt-headers-wasm/`. The
  packaging step is gated on the census and the census is one file short. Everything above is
  measured on `libOCCT-wasm-partial.a`, which holds every object the build produced, and on the
  build tree's forwarding-stub headers. Closing `STEPConstruct_AP203Context.cxx` is what turns the
  partial archive into the real one; nothing else in the pipeline is waiting.
- **No STEP file has been written on wasm.** The writer does not link.
- **No Swift.** Deliberately. The bridge, the manifest and the Swift runtime are #2048's and
  #2175's, and #2048 has at least one more gap than it knew about: the threading shim is a consumer
  requirement, and its `.headerSearchPath` does not point at the headers.
- **One configure, one host.** macOS 27.0 arm64, 10 cores, 69 minutes.

## Related

- [`Scripts/repro/2172/README.md`](../2172/README.md), `TKernel` compiled and archived.
- [`Scripts/repro/2173/README.md`](../2173/README.md), the eight `TKernel` platform gaps closed.
- [`Scripts/repro/2171/README.md`](../2171/README.md), what exceptions do on wasip1, and the three
  questions it left for the link.
- [`docs/WASI_GUARD_SITES.md`](../../../docs/WASI_GUARD_SITES.md), the guard-site record.
- [`docs/wasm-feasibility.md`](../../../docs/wasm-feasibility.md), the plan of record.
