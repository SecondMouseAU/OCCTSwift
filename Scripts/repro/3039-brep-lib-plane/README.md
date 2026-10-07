# #3039: BRepLib::Plane() creates its global without a lock

`BRepLib::Plane()` creates a process-global `Geom_Plane` the first time it is called, and every
vertex `BRepLib_MakeEdge2d` builds goes through it. Two threads making their first 2D edge together
can both see a null handle and both assign; the loser releases the plane the other has read through.
The result is a wrong vertex (zeros or denormal garbage) or SIGSEGV, SIGBUS or SIGTRAP. Carried
patch `0056` makes the plane a function-local static.

## Files

| file | what |
|---|---|
| `probe.cxx` | pure OCCT: N threads at a spin barrier each build a half circle and check both vertices. `warm` calls `BRepLib::Plane()` once first |
| `harness.py` | runs a binary in N fresh processes and counts clean, wrong vertex and each signal |
| `run.sh` | builds `asset`, `control`, `patched` and runs every row; exits 1 unless control fails and patched and warm are clean |
| `transcript.txt` | the run in the patch's README entry |

## Method

The race can only happen on the first `BRepLib::Plane()` call of a process, so every draw is a fresh
process. `run.sh` links the probe three ways: the archive as shipped (`asset`); the unmodified
`BRepLib.cxx` from `Libraries/occt-src`, recompiled and linked ahead of the archive (`control`); and
the same file with `0056` applied to a copy (`patched`). `warm` is `control` with the plane created
before the threads start. `control` shows the same defect as `asset` at a higher rate, so the
override toolchain is not what creates it. The transcript's `asset` row ran against a local
`libOCCT-macos.a` whose sha256 the transcript prints first; a local copy can lag the pinned asset, so
`control` is the row that decides.

```
Scripts/repro/3039-brep-lib-plane/run.sh --occt-src Libraries/occt-src
```

## Result

3000 fresh processes per row, 16 threads: `asset` 129 failures, `control` 368, `warm` 0, `patched` 0.
At 4 threads: 79, 749, 0, 0. See `transcript.txt` and the patch's entry in `Scripts/patches/README.md`.

The Swift-level test is `Tests/OCCTThreadTests/Issue3039BRepLibPlaneFirstUseTests.swift`.

## Not in the kernel's way

`BRepBuilderAPI::Plane()` returns the same global and is fixed with it. Nothing else reads
`thePlane`. The wasm kernel builds the same `BRepLib.cxx`; whether its threading model can reach the race
is not measured here, and no wasm file is touched.
