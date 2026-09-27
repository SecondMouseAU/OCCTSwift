# #2179: `wasi-osd-chronometer.patch` could not compile in either configuration

`Scripts/patches-wasi/wasi-osd-chronometer.patch` as PR #2043 merged it was a catch-22 against the
Swift 6.4 wasip1 sysroot, and neither half needed a full OCCT build to show.

`OSD_Chronometer.cxx:27` includes `<sys/times.h>` unguarded. That header in
`swift-6.4.0-RELEASE_wasm.artifactbundle/.../WASI.sdk` opens with:

```c
#ifndef _WASI_EMULATED_PROCESS_CLOCKS
#error WASI lacks process-associated clocks; ...
#else
...
clock_t times (struct tms *);
```

So:

- **bare**, which is how `Scripts/build-occt-wasm.sh` invokes the compiler, the translation unit
  dies at the include and the patch's `#ifdef __wasi__` guard never runs;
- **with `-D_WASI_EMULATED_PROCESS_CLOCKS`**, the header declares `times()` and the patch's own
  `static clock_t times(struct tms* buf)` stub fails as "static declaration of 'times' follows
  non-static declaration".

`CLK_TCK` is defined nowhere in that sysroot, so the `#ifndef CLK_TCK` branch holding the stub is
taken rather than skipped. The stub is also unreachable by design: the same patch makes
`GetProcessCPU()` return zeros without calling `times()` at all.

## The fix

Delete the stub, guard the include, and guard the two uses of what the include supplies
(`struct tms` and `times()`) with the same `#ifndef __wasi__`. `GetProcessCPU()` sets both
out-parameters to 0.0 on WASI, which is what `GetThreadCPU()` in the same file already does for a
platform it cannot serve. `_WASI_EMULATED_PROCESS_CLOCKS` is not added to the build: the emulation
it unlocks measures wall clock rather than CPU time, and it is what breaks the second
configuration.

## Running it

```bash
Scripts/repro/2179/run.sh /path/to/Libraries/occt-src
```

Nine rows, all of which must read `OK`. The argument is the patched OCCT tree (`V8_0_1` plus
`Scripts/patches/`), which a linked worktree does not have, so pass the main checkout's. Nothing
mutates it: the file is copied out and patched in a temp directory. Omit the argument and the four
full-file rows are skipped, leaving the four reduced-probe rows.

| File | What it is |
|---|---|
| `run.sh` | The harness. Both probes and the real file, before and after, in both configurations, plus a native macOS row. |
| `probe-before.cxx` | The reduced site as the patch left it before the fix. Must fail both ways. |
| `probe-after.cxx` | The reduced site as the patch leaves it after. Must pass both ways. |
| `wasi-osd-chronometer.before.patch` | The patch as it stood, kept so the "before" rows survive the fix. |

The harness aborts rather than reporting green if the OCCT headers are missing, because without
them every compile fails on the first `#include` and the two "must fail" rows would pass for a
reason that has nothing to do with this patch.
