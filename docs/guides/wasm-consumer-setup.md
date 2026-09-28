# Building a SwiftWasm app against OCCTSwift

For an application that wants OCCTSwift's Swift API in a browser or a wasm runtime, rather than for
someone working on this package. The background, the measurements and the decisions are in
[`wasm-feasibility.md`](../wasm-feasibility.md); this page is the recipe and the sharp edges.

## Before you start: is this ready for you?

Verified end to end on 2026-09-28 against a real consumer package, not inferred from this
repository's own builds. What that probe does is in
[`Scripts/repro/1689/`](../../Scripts/repro/1689/README.md).

**Working, and proven through a package that depends on OCCTSwift rather than from inside it:**

| | |
|---|---|
| BRep construction | `Shape.box`, `Shape.cylinder`, booleans |
| STEP export | `Exporter.writeSTEP`, and `Exporter.stepData` for bytes with no path |
| STEP import | `Shape.load(fromPath:)` |
| Tessellation for a renderer | `Shape.mesh(...)`, giving `vertices`, `indices`, `normals` |
| Error handling | an OCCT raise arrives as `nil` plus a diagnostic record, not a trap |
| Cross-origin isolation | **not needed**. No COOP/COEP headers, no `SharedArrayBuffer` |

**Not ready, and you should plan around these:**

- **No release carries any of this yet.** Every file below landed on `main` after `v4.0.0-beta.3`
  was cut. Until a release includes them you must depend on a **branch or a revision**, which means
  no semantic versioning. This is the main reason to wait if you can.
- **Module size.** A small app doing the whole list above is about **141 MB uncompressed, 41 MB
  gzipped, 27 MB brotli**, and an application's module is within 14 KB of this repository's own
  probe, so almost none of that is your code. About 13 MB of the compressed total is Foundation,
  before any OCCT. Nothing has been
  optimised yet; [#2761](https://github.com/SecondMouseAU/OCCTSwift/issues/2761) holds the
  measurements and the untried levers. **If your budget is well under that, do the size work before
  the integration, not after.**
- **No browser integration has been run with a renderer.** The module runs in Chrome and the
  geometry comes out correct, but nobody has driven three.js with it.
- **No test suite runs on wasm.** Six smoke cases run in CI; no per-domain target has ever been
  compiled for this target ([#2793](https://github.com/SecondMouseAU/OCCTSwift/issues/2793)).

## The three commands

You need the pinned toolchain, the prebuilt kernel, and a toolset. Nothing else.

```bash
# 1. Toolchain: the swift.org Swift, its wasm SDK, and wasi-sdk. Versions and checksums are pinned
#    in Scripts/wasm-toolchain-versions.txt. This will not install the Swift toolchain itself; it
#    prints the exact command and stops, because that is a signed installer on macOS.
.build/checkouts/OCCTSwift/Scripts/install-wasm-toolchain.sh

# 2. Kernel: a 38 MB release asset, checksum-verified before it is unpacked. Seconds, against the
#    69-minute OCCT build it replaces. Run it INSIDE the OCCTSwift checkout; it defaults to that
#    checkout's own Libraries/.
.build/checkouts/OCCTSwift/Scripts/fetch-occt-wasm.sh

# 3. Toolset, then build. The toolset carries the flags a published manifest cannot: the exception
#    flags, and the -L/-I that name where the kernel landed on your machine.
python3 .build/checkouts/OCCTSwift/Scripts/make-wasi-toolset.py \
    --wasi-sdk "$WASI_SDK_PREFIX" -o toolset.json

OCCTSWIFT_WASI=1 TOOLCHAINS=swift swift build \
    --toolset toolset.json \
    --swift-sdk swift-6.4.0-RELEASE_wasm \
    --triple wasm32-unknown-wasip1 \
    -c release
```

`--occt-lib-dir` and `--occt-include-dir` default to the checkout's `Libraries/`, which is where
step 2 puts things, so you pass neither unless you moved them.

### Your `Package.swift`

```swift no-typecheck: a consumer's manifest, not this package's
dependencies: [
    // A branch, because no release carries the wasm support yet. Pin a revision if you want
    // reproducibility before the first release that does.
    .package(url: "https://github.com/SecondMouseAU/OCCTSwift.git", branch: "main")
]
```

## Three things that will cost you an afternoon otherwise

Each of these was hit while writing about a hundred lines of consumer code.

### `@MainActor` on anything that mutates top-level state

Under the Swift 6 language mode a `var` at the top level of `main.swift` is main-actor isolated,
while a `func` at the same level is not. So this fails to compile:

```swift no-typecheck: shows the error, deliberately
var failures = 0
func check(_ ok: Bool) {
    if !ok { failures += 1 }   // error: main actor-isolated var 'failures'
}                              // can not be mutated from a nonisolated context
```

Annotate the function:

```swift no-typecheck: the fix for the snippet above
var failures = 0

@MainActor
func check(_ ok: Bool) {
    if !ok { failures += 1 }
}
```

Not wasm-specific, but every SwiftWasm executable starts as a `main.swift`, so everybody meets it.

### A misused API can report a compiler bug instead of a type error

Chained optionals around this API produced:

```
error: failed to produce diagnostic for expression; please submit a bug report
```

rather than naming the mistake. If you get that, **suspect your own expression before the
toolchain**: break it into explicit locals with declared types and the real error usually appears.
In the case that produced it, the real error was a method that does not exist.

### The subtraction is `subtracting(_:)`

Booleans on `Shape` are `subtracting(_:)`, `fused(with:)` and `intersecting(_:)`. If you reach for a
method called cut, by analogy with other kernels, you will not find one. See
[`API_REFERENCE.md`](../API_REFERENCE.md).

## Getting bytes in and out without a filesystem

A wasm module has no filesystem beyond what the host preopens, and in a browser there is no
filesystem at all. This turned out not to need any API change.

**Out:** `Exporter.stepData(shape:name:)` returns `Data` with no path involved. It works by writing
to `FileManager.default.temporaryDirectory` and reading back, so the host must preopen that
directory; set `TMPDIR` and preopen it.

**In:** write the bytes into a preopened directory from the host, then call the ordinary
path-taking entry point. Under a browser shim that is a `File` in a `PreopenDirectory` map.

```js no-typecheck: host-side JavaScript, not Swift
// @bjorn3/browser_wasi_shim. Two preopens: a working directory, and /tmp for stepData.
const work = new PreopenDirectory("/work", new Map());
const tmp  = new PreopenDirectory("/tmp",  new Map());
const wasi = new WASI(["app", "/work"], ["TMPDIR=/tmp"], [
    new OpenFile(new File([])),                    // stdin
    ConsoleStdout.lineBuffered(console.log),       // stdout
    ConsoleStdout.lineBuffered(console.warn),      // stderr
    work,
    tmp,
], { debug: false });   // REQUIRED: omitting the options object turns per-syscall logging ON
```

After the run, a file the guest wrote is a `Uint8Array` in that map, so handing it to the user is a
`Blob` away. A worked example, including the traps, is in
[`Scripts/repro/2052/`](../../Scripts/repro/2052/README.md).

## Feeding a renderer

`Shape.mesh(linearDeflection:angularDeflection:)` gives a `Mesh` whose `vertices` and `normals` are
`[SIMD3<Float>]` and whose `indices` are `[UInt32]`: a triangle-list index buffer, ready for a
`BufferGeometry` or equivalent. Measured on wasm, on a bar with a hole through it, at a deflection
of 0.5: 130 vertices, 116 triangles, 348 indices, 130 normals, every coordinate finite and every
index in range.

Note that `SIMD3<Float>` here comes from a **WASI-only stand-in** for Apple's `simd`, whose shape is
still being decided in [#2759](https://github.com/SecondMouseAU/OCCTSwift/issues/2759). The vector
types themselves are Swift standard library types and are not affected; what could change is the
handful of `simd_*` free functions.

## What is absent on wasm

`Shape.isSelfIntersecting(hardTimeout:)`. Its contract is a hard wall-clock deadline enforced from a
second thread, and this target is single-threaded by construction, so no implementation can honour
it. Use `isSelfIntersecting(timeout:)`, whose bound is cooperative and documented as such. The
decision is tracked in [#2760](https://github.com/SecondMouseAU/OCCTSwift/issues/2760).

Everything else in the public API compiles for wasm.
