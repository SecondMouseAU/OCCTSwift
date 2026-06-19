---
nav_exclude: true
search_exclude: true
---

# WebAssembly feasibility & plan

This doc captures the analysis of building OCCTSwift for WebAssembly so that the
**OCCTSwift Swift API can be reused inside a SwiftWasm app** (e.g. a browser app
driven by JavaScriptKit, or a server-side wasm runtime). Written June 2026 as a
forward plan; **not yet started** — deferred until the cookbook/docs work lands.

The goal is fixed. The *path* to reach it is deliberately left open — see
[Three paths](#three-paths-to-one-wasm-module). The path choice is the **output of
the decision spike** (Phase 0 below), not a premise of this plan.

## Goal

Compile the existing Swift public API (`Shape`, `Wire`, `Surface`, …) → the C bridge
→ OCCT, all the way down to a single wasm module that a SwiftWasm application can
call. The consumer is **Swift**, not JavaScript — that is the only thing that
justifies this work, because OCCT-in-the-browser already exists for JS consumers
(see [Prior art](#prior-art)).

## What's already in our favour

Two structural facts make this more tractable than the `platform-expansion.md`
(Linux/Windows/Android) review assumed:

1. **The bridge is already wasm-shaped.** Despite the `.mm` extension, the 17
   bridge files contain **zero Objective-C runtime** — no `NSString`, `NSObject`,
   `@try`, `@autoreleasepool`. It is pure C++ with a flat C-linkage surface
   (`double` / `int32_t` / `const char*` / `bool` / opaque `OCCT*Ref` pointers).
   The only ObjC touch is one `#import <Foundation/Foundation.h>` in the header,
   which is removable. A flat C ABI is exactly the recommended seam for
   Swift-on-wasm. *(Note: this supersedes the stale "57k-line .mm, audit for
   ObjC-isms" claim in `platform-expansion.md` — the bridge has since been split
   into per-area files and verified clean.)*

2. **OCCT is already configured headless.** `build-occt.sh` ships
   Visualization / OpenGL / GLES / FreeType / TBB / VTK / Draw all **OFF**; only
   FoundationClasses, ModelingData, ModelingAlgorithms, DataExchange + RapidJSON
   are ON. That is precisely the subset that ports to wasm (no GL context, no
   native threading).

3. **Threading is a non-issue for us.** The bridge serialises all OCCT access
   through one `std::recursive_mutex`; single-threaded wasm satisfies that
   trivially, and TBB is already off.

## The central obstacle: two incompatible wasm ABIs

This is the fact that dominates the whole effort.

- **Official Swift-on-wasm** (upstream in Swift 6.1+, SDKs shipped from swift.org
  in 6.2/6.3) targets **`wasm32-unknown-wasip1`**, built against **wasi-sdk /
  wasi-libc**.
- **OCCT's only supported wasm path** is **Emscripten**
  (`wasm32-unknown-emscripten`, its own JS-based libc).
- These two are **not ABI-compatible and cannot be statically linked** — different
  libc constants (e.g. `O_CREAT`), struct layouts, and import shapes. Emscripten
  declined to align with WASI (wontfix, emscripten#9479). So you cannot drop an
  Emscripten-built `libOCCT.a` next to wasi-built Swift and link them.

Everything below is about how to bridge that gap.

## What breaks in the Swift layer

The Swift API leans on Foundation harder than the bridge does: **~70 files**
`import Foundation`, ~128 `URL`, ~35 `Data`, 8 `FileManager` uses.

- `Data` / `URL` / `Date` / `JSONEncoder` work via **FoundationEssentials** on wasm.
- **`URLSession` is unavailable** on wasm (no sockets).
- **`FileManager` file I/O is sandboxed** — the STEP / STL / glTF read/write
  functions that take file paths need a **virtual filesystem** (Emscripten MEMFS,
  or WASI preopens). This is the single biggest API-surface task after linking.
- **4 GB single-heap ceiling** (wasm32; Swift does not target wasm64) caps model
  size, and the linked module will be large (occt-wasm is ~4.5 MB brotli for OCCT
  alone — Swift + Foundation adds more).

## Three paths to one wasm module

The goal requires Swift and OCCT in one module with a **shared ABI**. There are
three ways to get there. **We are not choosing between them yet** — Phase 0 picks
the winner with evidence.

| Path | Approach | Trade-off | Maturity (June 2026) |
|------|----------|-----------|----------------------|
| **A. Swift-on-Emscripten** | Compile Swift against emsdk libc so it matches an Emscripten-built OCCT. Reuse a prebuilt OCCT 8.0.0 wasm (e.g. `andymai/occt-wasm`). | Most direct *if* it works; reuses existing OCCT wasm builds. | **Experimental** — March 2026 Swift pitch + Embedded-Swift/emsdk PoC; no packaged toolchain. |
| **B. OCCT-on-wasi-sdk** | Port OCCT to build with wasi-sdk so it matches standard SwiftWasm. | Standard, well-supported Swift side; OCCT side is uncharted (OCCT assumes POSIX/threads). | OCCT headless core has no hard Emscripten dep, but no known wasi-sdk port exists. |
| **C. Two components** | Keep OCCT (Emscripten) and Swift (wasi) as separate wasm modules; bridge via the **Component Model / WIT** at a typed interface, not the C ABI. | Avoids ABI linking entirely; adds a serialization boundary across every call. | WASI 0.2 shipped; 0.3 landing 2026. Heaviest runtime model. |

## Plan

### Phase 0 — Decision spike (gates everything)

The one thing that can kill the whole idea is the ABI seam. Validate it cheaply
before porting 3,500 operations.

1. Stand up a SwiftWasm toolchain (swift.org Swift SDK for WebAssembly, current
   6.3.x line) and confirm a trivial `swift build --swift-sdk … wasm` runs.
2. Pick **3 representative bridge functions**: `OCCTShapeBox` (pure compute),
   one boolean (e.g. `OCCTShapeFuse`, exercises the allocator hard), and one
   STEP/STL export (exercises the virtual FS + string I/O).
3. Attempt each path far enough to **link and call those 3 functions** from Swift:
   - **A**: build/obtain OCCT-on-emscripten + Swift-on-emscripten, link, call.
   - **B**: cross-build just the bridge + minimal OCCT TKBRep subset with
     wasi-sdk, link against wasi Swift, call.
   - **C**: wrap the 3 functions as a WIT interface across two components.
4. **Deliverable:** a one-page decision memo recording which path linked and ran,
   binary size, and blockers hit. This selects the path for Phase 1.

> Stop here and reassess if no path links the 3 functions. That is the
> go/no-go gate.

### Phase 1 — Build pipeline

- Add a wasm target to `build-occt.sh` (or a sibling `build-occt-wasm.sh`) for the
  chosen toolchain. `xcframework` packaging is Apple-only, so wasm needs its own
  distribution path (a checked-in/release-asset `.a` + headers, or vendored
  sources, consumed via SwiftPM `linkerSettings`/unsafeFlags — there is no
  `binaryTarget` for wasm).
- Drop the `#import <Foundation/Foundation.h>` from the bridge header (or guard it)
  so the bridge compiles under the wasm toolchain.

### Phase 2 — Swift layer portability

- Conditionalise the Foundation surface: keep `Data`/`URL`/`Date`; route or stub
  `FileManager`/path-based I/O through a virtual FS abstraction.
- Replace any `URLSession`/socket use (audit confirms none in the kernel paths,
  but re-verify).
- `#if canImport` / `#if os(WASI)` guards where platform divergence is needed.

### Phase 3 — File I/O over a virtual FS

- The STEP/IGES/STL/glTF read+write bridge functions take file paths. Provide a
  MEMFS (Emscripten) or preopen (WASI) shim so a SwiftWasm app can hand bytes in
  and get bytes out without a real filesystem. This is the largest API-surface
  task.

### Phase 4 — Test + CI

- A wasm test path (wasmtime or a headless browser runner) for a **subset** of the
  per-domain suites. Full parity is unrealistic initially; target the modeling +
  IO domains first.
- A GitHub Actions matrix entry that builds the wasm slice and runs the subset.

### Phase 5 — Consumer validation

- A minimal SwiftWasm sample app (JavaScriptKit) that imports OCCTSwift, builds a
  box, fuses two shapes, and exports STEP — proving the goal end to end.

## Effort & risk

- **Phase 0 (spike):** ~1 week. **High information value, low cost.** Do this first.
- **Phases 1–5:** weeks-to-months and **highly path-dependent** — Path A's risk is
  toolchain immaturity, Path B's is an uncharted OCCT port, Path C's is per-call
  overhead and the component tooling. The spike retires the dominant risk before
  any of that is committed.

This is a **porting project, not a recompile**. The existing arm64 xcframework is
the wrong architecture/libc/libc++ and is unusable on wasm regardless of path.

## Prior art

- **`andymai/occt-wasm`** — actively maintained, tracks **OCCT 8.0.0** (the exact
  GA this repo pins), built with emsdk, ~4.5 MB brotli. The strongest candidate
  OCCT-side input for Path A. <https://github.com/andymai/occt-wasm>
- **opencascade.js** (donalffons) — older JS/Embind port, stale at OCCT 7.4.0p1.
  <https://github.com/donalffons/opencascade.js>
- **OCCT `samples/webgl`** — Open Cascade's in-tree Emscripten reference build.

## Key references

- Swift SDKs for WebAssembly — <https://www.swift.org/documentation/articles/wasm-getting-started.html>
- `swiftlang/swift` `docs/WebAssembly.md` — triples, wasi-sdk linking, no dynamic linking
- Swift for Wasm, December 2025 updates — <https://forums.swift.org/t/swift-for-wasm-december-2025-updates/83778>
- C++ interoperability status — <https://www.swift.org/documentation/cxx-interop/status/>
- Swift + Emscripten pitch — <https://forums.swift.org/t/using-swiftpm-with-emscripten/84783>
- Swift on Emscripten libc (experiment) — <https://forums.swift.org/t/emsdk-libc-instead-of-wasi/79361>
- wasi-sdk vs emscripten ABI — <https://github.com/WebAssembly/wasi-sdk/issues/222>, <https://github.com/emscripten-core/emscripten/issues/9479>
- Component Model — <https://component-model.bytecodealliance.org/>

## Relationship to other docs

- [`platform-expansion.md`](platform-expansion.md) — the Linux/Windows/Android
  review. Wasm is a separate axis (different ABI problem) and is tracked here.
- The bridge being pure-C++/C-linkage (verified clean) is a prerequisite that
  benefits any non-Apple port, wasm included.
