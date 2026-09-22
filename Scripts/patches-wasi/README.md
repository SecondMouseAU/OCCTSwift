# WASI-only OCCT source patches

These are **not** carried upstream-bound patches. They are WASI-specific source changes that only
`Scripts/build-occt-wasm.sh` applies, on top of everything in [`../patches/`](../patches/README.md).

`Scripts/patches-wasi/` holds two patches, and the table below has one row per file. Both the count
and the table are checked against the directory by `Scripts/check-inventory-prose.py`, so adding or
removing a patch without editing this page fails `gate-scripts`.

| Patch | What it does |
|---|---|
| `wasi-osd-chronometer.patch` | `OSD_Chronometer.cxx` for the wasm32-wasi clock surface |
| `wasi-osd-directory.patch` | `OSD_Directory.cxx` for the wasm32-wasi filesystem surface |

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

Drop a `git diff` (`-p1`, prefixes `a/`, `b/`) here, and add its row to the table above.
`build-occt-wasm.sh` applies this directory after the carried set, idempotently, and aborts if a
patch does not apply cleanly.

Numbering is deliberately not used here: these are not upstream-bound, so they have no place in the
carried sequence and nothing cites them by number.
