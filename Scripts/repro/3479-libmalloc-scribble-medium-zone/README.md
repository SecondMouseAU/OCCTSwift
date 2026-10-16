# #3479: libmalloc segfaults under MallocScribble (not OCCT, not OCCTSwift)

The `release-mode-tests` job died now and then with `SIGSEGV ... Address 5555555555555555`, in the
thread suites that build a smooth `ThruSections` loft. `0x55` is the byte `MallocScribble` writes
over a freed block. The crash was inside libmalloc's own free-list scan, not in our code.

`malloc_scribble_probe.c` shows that nothing of ours is needed. It is a plain C program: each thread
owns a ring of blocks, writes only inside its own block, and frees them in rotation (`mix=1` adds
`calloc`, `realloc` and `posix_memalign`). `run.sh` compiles it and runs the cases below.

## Measured (GitHub-hosted runners, 30 s per case)

| runner | OS | Xcode | Swift | 8 threads, to 4 MB, scribble | 3 threads, to 4 MB, scribble | no malloc env | `MallocMediumZone=0` | `MallocSpaceEfficient=1` |
|---|---|---|---|---|---|---|---|---|
| macos-15 | 15.7.9 (24G830) | 26.3 | 6.2.4 | crash (139) | crash (139) | ok | ok | ok |
| macos-26 | 26.6.2 (25G83) | 26.6 | 6.3.3 | ok | ok | ok | ok | ok |

`macos-latest` resolved to `macos-26-arm64` when this was measured.

Other findings on macos-15:

- One thread never crashes. Three or more do, with `malloc`/`free` only as well as with the mix.
- Blocks up to 300 KB are fine, up to 1 MB crash with 8 threads but not with 3, up to 4 MB crash with 3.
- `MallocPreScribble` alone and no malloc environment pass.
- These do not help: `MallocMediumZoneEnabled=0`, `MallocLargeCache=0`, `MallocNanoZone=0`,
  `MallocMaxMagazines=1`, `MallocMadvise=0`, `MallocMediumMadvise=0`.

## Why the suite met it

`GeomFill_AppSurf` fits a smooth loft with least-squares matrices that grow with the number of
sections, a few megabytes for a thread rod, and `Shape.threadedShaft` builds one of those per call.
The Swift test runner calls it from several threads at once. The same tests run serially under
scribble pass, a TSan build of the kernel reports no race in the loft, and Guard Malloc finds no bad
write, which is what a program with no memory error looks like.

## Fix

`Scripts/release-mode-test.sh` and `.github/workflows/malloc-scribble-stress.yml` add
`MallocMediumZone=0`. Scribbling, pre-scribbling and guard edges stay on, so the #3130 hazard is
still caught for every block the medium zone does not own.
