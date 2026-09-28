# #1689: can the project that asked for this use it?

`./run.sh` reproduces everything here. Measured 2026-09-28, macOS 27.0 arm64.

## Why a separate package

Every other wasm measurement in this repository looks at OCCTSwift from inside it, or through
`Scripts/repro/2175/spike`, which reaches it by a **path** dependency. Neither is what an
application does. #1689 came from the valvegear project, which consumes OCCTSwift as an ordinary
SwiftPM dependency, so this probe is a separate package that declares one and builds for
`wasm32-unknown-wasip1`.

It exercises exactly the list #1689 asked for, plus the one thing that list implies and nobody had
run.

## Result: seven of seven

```
PASS  box                     volume=7999.999999999998 expected=8000.0
PASS  cylinder                volume=1570.7963267948965 expected=1570.7963267948967
PASS  subtract (linkage)      volume=7607.3009183012755, a bar minus a pin hole
PASS  writeSTEP               19301 bytes (440 entities)
PASS  loadSTEP                volume=7607.300918301262 faces=8
PASS  stepData (bytes out)    19301 bytes, no path involved
PASS  mesh (three.js)         130 verts, 116 tris, 348 indices, 130 normals, maxIndex=129, allFinite=true
failures: 0
```

Module: **141,227,748** bytes uncompressed, **41,097,103** gzip, **26,990,019** brotli.

**An application's module is not meaningfully bigger than this repo's own spike**, which is worth
stating because it retires a suspicion rather than confirming one. `OCCTWasmSpike` is 26,976,003
brotli; this is 26,990,019, a difference of **14 KB in 27 MB**, and it does strictly more (a
cylinder, a boolean, and a full mesh with vertex, index and normal buffers). So the size is the
runtime, Foundation, the Swift layer, the bridge and the OCCT the linker reaches, essentially none
of it the consumer's own code, and the spike's figures were never an artefact of being artificial.

## The case that had never run

**`mesh` is the one worth the whole probe.** #1689's fourth requirement is "compatible with three.js
WebGL context", and a browser CAD app has to **display** geometry, not only export it. That means
tessellation, and `Scripts/repro/2175`'s six cases never touched it: box, fuse, STEP out, STEP in,
and two failures. So `Shape.mesh()` had never run on this target at all.

It also goes straight through the **WASI `simd` stand-in** (#2759), because `vertices` and `normals`
are `[SIMD3<Float>]`, which made it the most likely of the seven to be broken.

It is not broken. The assertion is on the shape of the buffers rather than on their existence, so a
mesh that came back empty or corrupt could not pass: indices divisible by three, `maxIndex` strictly
less than the vertex count, and every coordinate finite. That is a triangle-list index buffer a
renderer can upload unmodified.

## What the consumer path actually costs

Each step worked first time and needed no argument beyond the wasi-sdk prefix. Both scripts default
to the consumer's own checkout without being told where anything is.

| Step | Cost |
|---|---|
| `swift package resolve` | 14 s, cold |
| `fetch-occt-wasm.sh` into the checkout | 16 s, checksum verified before unpacking |
| `make-wasi-toolset.py` | instant |
| `swift build -c release` | minutes |

**The checkout has no kernel**, by design: `Libraries/` is gitignored in OCCTSwift, so a consumer
gets `dummy.c` and `include/` and nothing else. Step 2 is what makes the difference between a
download and a 69-minute OCCT build, and it is the step a consumer has to be told about, which is
what [`docs/guides/wasm-consumer-setup.md`](../../../docs/guides/wasm-consumer-setup.md) is for.

## Three papercuts, in about a hundred lines of consumer code

Recorded because they are what an integrator meets on day one, and none is in the API's
documentation.

1. **`@MainActor`.** A `var` at the top level of `main.swift` is main-actor isolated under the
   Swift 6 language mode and a `func` at the same level is not, so a helper that mutates a counter
   fails with `main actor-isolated var 'failures' can not be mutated from a nonisolated context`.
   `Scripts/repro/2175/spike` documents the same thing in its own source; a consumer has no reason
   to have read it.
2. **A misused API can report a compiler bug rather than a type error.** The first draft chained
   optionals (`box?.volume.map { ... } ?? false`) and got
   `error: failed to produce diagnostic for expression; please submit a bug report` on three lines,
   with the real mistake, a method that does not exist, named on only one of them. Breaking the
   expression into explicit locals produced the real error immediately.
3. **The subtraction is `subtracting(_:)`**, and reaching for a method called cut by analogy
   with other kernels finds nothing.

The probe is written with explicit locals throughout as a result, which is also why it reads more
plainly than it otherwise would.

## What this does NOT show

- **No browser.** This runs under `wasmkit`. `Scripts/repro/2052` is the browser measurement, and it
  does not include a renderer: nobody has driven three.js with these buffers.
- **No size work.** 41 MB gzip is the figure as it stands, with none of #2761's five levers tried.
- **One geometry.** A bar with a hole in it is a reasonable stand-in for a valve-gear linkage and is
  not a stress test.
