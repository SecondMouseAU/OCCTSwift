# WASI-only OCCT source patches

These are **not** carried upstream-bound patches. They are WASI-specific source changes that only
`Scripts/build-occt-wasm.sh` applies, on top of everything in [`../patches/`](../patches/README.md).

`Scripts/patches-wasi/` holds ten patches, one per OCCT source file, and the table below has one
row per file. Both the count and the table are checked against the directory by
`Scripts/check-inventory-prose.py`, so adding or removing a patch without editing this page fails
`gate-scripts`.

Eight of the ten close the platform gaps [#2172](https://github.com/SecondMouseAU/OCCTSwift/issues/2172)
measured by compiling every one of `TKernel`'s 127 source files, and with them that toolkit builds
127 of 127. Every one of those eight carries, in its own header, what its WASI branch returns and
why that value is safe for each of its in-tree callers.

| Patch | What it does |
|---|---|
| `wasi-message-printersyslog.patch` | `Message_PrinterSystemLog.cxx`: no `<syslog.h>`, so `send()` writes to stderr |
| `wasi-osd-chronometer.patch` | `OSD_Chronometer.cxx` for the wasm32-wasi clock surface |
| `wasi-osd-directory.patch` | `OSD_Directory.cxx` for the wasm32-wasi filesystem surface |
| `wasi-osd-file.patch` | `OSD_File.cxx`: no `mkstemp()` and no `fcntl` record locking |
| `wasi-osd-host.patch` | `OSD_Host.cxx`: no `<netdb.h>`, so `InternetAddress()` is empty |
| `wasi-osd-path.patch` | `OSD_Path.cxx`: joins the Emscripten arm, so paths parse as Unix |
| `wasi-osd-process.patch` | `OSD_Process.cxx`: no `<pwd.h>` and no `getuid()` |
| `wasi-osd-signal.patch` | `OSD_signal.cxx`: no signal delivery, so nothing is installed |
| `wasi-standard-mmgropt.patch` | `Standard_MMgrOpt.cxx`: no `mmap()`, so the malloc path is the only one |
| `wasi-standard-stacktrace.patch` | `Standard_StackTrace.cxx`: no `<execinfo.h>`, so `StackTrace()` returns false |

## The threading class is handled by a shim, and never by a patch here

The Swift wasip1 SDK ships a libc++ built with `_LIBCPP_HAS_THREADS 0`, which removes six `std`
names OCCT uses in 76 files across the four modules this build compiles. **None of that is patched.**
A single force-included shim header supplies the missing names, wired into the WASI build's
`CMAKE_CXX_FLAGS` as `-include`, tracked in
[#2170](https://github.com/SecondMouseAU/OCCTSwift/issues/2170).

So: **a patch in this directory that mentions `std::mutex`, `std::recursive_mutex`,
`std::shared_mutex`, `std::shared_lock`, `std::condition_variable` or `std::this_thread::yield` is
wrong by construction.** Fix the shim instead. The reasoning, and what the previous attempt cost, is
in [`../../docs/WASI_GUARD_SITES.md`](../../docs/WASI_GUARD_SITES.md).

What does belong here is the filesystem, process, signal and host surface that wasi-libc genuinely
lacks.

## Why this is a separate directory, and not `Scripts/patches/`

Three pieces of machinery glob `Scripts/patches/*.patch` with no filter, so a WASI patch parked
there is not merely untidy:

1. **`build-occt.sh` would apply it to every platform.** Its loop has no filter, so a WASI patch
   that happens to apply to the pinned source lands in the macOS, iOS and ThreadSanitizer kernels
   **silently**. A conflict would at least have been loud; clean application is the worse outcome,
   and whether any given patch conflicts is not a property anyone can rely on.
2. **`Scripts/patches/` is NNNN-named, and this sequence is not.** Two checks and three counted
   facts in `check-inventory-prose.py` read a carried patch's number off the first four characters
   of its filename. A `wasi-` name there used to crash the gate outright
   ([#2148](https://github.com/SecondMouseAU/OCCTSwift/issues/2148)); it is now reported by name,
   with this directory as the place it belongs.
3. **The kernel cache key and the TSan stamp both hash `patches/*.patch`.** A WASI-only change
   would move both for a reason that has nothing to do with the native kernel, and per
   [#2063](https://github.com/SecondMouseAU/OCCTSwift/issues/2063) a cache key cannot be
   overwritten once written, so quietly changing what feeds that hash is worth avoiding.

So the invariant is: **`Scripts/patches/` contains only `NNNN-` numbered patches that every platform
carries.** Anything platform-specific gets its own directory and its own applier.

## Adding one

**Generate the diff with [`../patches/`](../patches/README.md) already applied, and verify it in
that same state.** That is the rule, it is owned by
[`okf/policies/wasi-patch-base.md`](../../okf/policies/wasi-patch-base.md), and PR #2076 is why it
is written down: its fifteen patches were authored against a pristine `V8_0_1` and checked by
applying them to one, which is how nobody noticed that nine carried patches inject `std::mutex`
and `std::recursive_mutex` into OCCT and that 15 of the 76 threading-dependent files are files we
patch ourselves.

```bash
cd Libraries/occt-src
git checkout .                                   # a clean V8_0_1
for p in ../../Scripts/patches/*.patch; do git apply "$p"; done
# ... make the WASI change ...
git diff -- src/path/to/File.cxx > ../../Scripts/patches-wasi/wasi-<thing>.patch
git apply --check ../../Scripts/patches-wasi/wasi-<thing>.patch   # in THIS state
```

A patch that applies to vanilla but not to the patched tree, or the reverse, is a defect. Keep the
`diff --git` and `index` lines `git diff` emits (`-p1`, prefixes `a/`, `b/`): the `index` pre-image
blob is the exact identity of the tree the patch was cut from, and
`check-wasi-patch-base.py --tree` checks it against the real file. The eight #2173 added all carry
one. The two that predate it, `wasi-osd-chronometer.patch` and `wasi-osd-directory.patch`, were
hand trimmed and carry no `index` line, which is not a defect, only a weaker patch: `--tree` still
runs `git apply --check` on them and simply has no blob to compare.

Then add the patch's row to the table above. `build-occt-wasm.sh` applies this directory after the
carried set, idempotently, and aborts if a patch does not apply cleanly.

**If the file is one a carried patch also touches**, declare it in the patch preamble, one line per
carried patch:

```
Applies-After: 0033-Interface_Static-thread-safety-mutex-1157.patch
```

That is the record that the diff was regenerated in the patched state, and it is what fails loudly
at the next kernel repin rather than quietly: a retired or renumbered carried patch leaves the
trailer unresolvable, and the WASI patch gets re-verified instead of sitting on a state that no
longer exists. No file here collides today: #2173 added eight patches and not one of their ten target files is
touched by any of the twenty-nine carried patches, so no `Applies-After:` trailer is needed yet.
`check-wasi-patch-base.py` reports that as `0 shared target file(s)`, and the day it stops saying
zero is the day the trailer becomes mandatory.

Numbering is deliberately not used here: these are not upstream-bound, so they have no place in the
carried sequence and nothing cites them by number.

## What checks a patch here, and what it cannot

Three checks, none of which needs a wasm build:

- `python3 Scripts/check-wasi-patch-base.py` (#2168) reads both patch sets as text and fails on a
  shared target file with no `Applies-After:`, an `Applies-After:` that no longer resolves, a
  context line the carried set deletes, an added line using a member belonging to some other class,
  or two patches here editing one file. It **cannot** run `git apply --check`, so a patch whose
  context simply is not in the patched tree, for a file no carried patch touches, is invisible to
  it. `--tree Libraries/occt-src --require-tree` is the mode that does the real check, and it is
  not in `gate-scripts`, which has no checkout.
- `python3 Scripts/check-preprocessor-balance.py` (#2167) fails when a patch leaves a file's
  `#if`/`#else`/`#endif` unbalanced, which three of #2076's fifteen did on every platform rather
  than only WASI.
- `python3 Scripts/check-inventory-prose.py` (#1408) fails when the count and the table above stop
  matching this directory.

"The patch applies cleanly" is a narrow claim, and each of the properties #2076 got wrong (it
preprocesses, it was cut from the right tree, it edits the class it names) needs its own check.
