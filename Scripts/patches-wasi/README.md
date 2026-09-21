# WASI-only OCCT source patches

These are **not** carried upstream-bound patches. They are WASI-specific source changes that only
`Scripts/build-occt-wasm.sh` applies, on top of everything in [`../patches/`](../patches/README.md).

| Patch | What it does |
|---|---|
| `wasi-osd-chronometer.patch` | `OSD_Chronometer.cxx` for the wasm32-wasi clock surface |
| `wasi-osd-directory.patch` | `OSD_Directory.cxx` for the wasm32-wasi filesystem surface |

## Why this is a separate directory, and not `Scripts/patches/`

Three pieces of machinery glob `Scripts/patches/*.patch` with no filter, so a WASI patch parked
there is not merely untidy:

1. **`build-occt.sh` would apply it to every platform.** Its loop has no filter, and both patches
   here apply *cleanly* to the pinned source, so WASI workarounds would land in the macOS, iOS and
   ThreadSanitizer kernels **silently**. A conflict would at least have been loud; clean application
   is the worse outcome.
2. **`check-inventory-prose.py` parses the first four characters of each filename as the patch
   number** and raises `ValueError: invalid literal for int() with base 10: 'wasi'`. That is a
   required check, so `gate-scripts` cannot pass while a non-numeric name sits in that directory.
3. **The kernel cache key and the TSan stamp both hash `patches/*.patch`.** A WASI-only change
   would move both for a reason that has nothing to do with the native kernel, and per
   [#2063](https://github.com/SecondMouseAU/OCCTSwift/issues/2063) a cache key cannot be
   overwritten once written, so quietly changing what feeds that hash is worth avoiding.

So the invariant is: **`Scripts/patches/` contains only `NNNN-` numbered patches that every platform
carries.** Anything platform-specific gets its own directory and its own applier.

## Adding one

Drop a `git diff` (`-p1`, prefixes `a/`, `b/`) here. `build-occt-wasm.sh` applies this directory
after the carried set, idempotently, and aborts if a patch does not apply cleanly.

Numbering is deliberately not used here: these are not upstream-bound, so they have no place in the
carried sequence and nothing cites them by number.
