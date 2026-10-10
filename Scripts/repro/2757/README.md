---
nav_exclude: true
search_exclude: true
---

# #2757: setjmp lowering plus wasm exceptions emits an invalid `br_table`

`Scripts/build-occt-wasm.sh` already avoids the defect (`-UOCC_CONVERT_SIGNALS`, so no OCCT function
carries a lowered `setjmp`; see #2175). This directory is for the two things #2757 left open: a
reduction good enough for an LLVM report, and whether anything else needs the pair.

    Scripts/repro/2757/run.sh                      # the reduction, six controls, ~10 s, no OCCT
    Scripts/check-wasm-archive-no-setjmp.sh        # the regression guard, against Libraries/libOCCT-wasm.a

Measured 2026-10-07, macOS 27.0 arm64, Swift toolchain 6.4.0-RELEASE (clang `Apple clang version
21.0.0`, swiftlang/llvm-project `903b9faaae5c`), Swift wasm SDK 6.4.0-RELEASE, `node` v26.10.0, all
the toolchain values as pinned by [`Scripts/wasm-toolchain-versions.txt`](../../wasm-toolchain-versions.txt).

## What was done

1. **Compiled the real source both ways.** `BRepCheck_Analyzer.cxx` (`Libraries/occt-src`, headers
   from `Libraries/occt-install-macos/include/opencascade`), as one translation unit, with the
   build script's flags (`-std=c++17 -O2`, the WASI threading shim, `$WASM_CXX_EH_FLAGS`,
   `-mllvm -wasm-enable-sjlj`, `-DHAVE_RAPIDJSON`) and `-DOCC_CONVERT_SIGNALS` against
   `-UOCC_CONVERT_SIGNALS`. This is not the CMake command line (the build tree was not present and
   the 69-minute build was not run), so `-O2` stands in for the build's own level and the include
   path is the installed header tree. Objects: 143,576 bytes with the define, 49,100 without.
2. **Needed a validator that works on an object.** `wasmkit` 0.3.1 only reports the `br_table`
   refusal once it has resolved the module's imports, and an OCCT object has hundreds. V8 validates
   at `new WebAssembly.Module(bytes)`, so each object was linked with
   `wasm-ld --no-entry --allow-undefined --no-gc-sections --export-all` and handed to `node`.
   Result for the real source: with the define, `Compiling function #81:"BRepCheck_ParallelAnalyzer::operator()(int) const" failed: br_table: label arity inconsistent with previous arity 0`;
   without it, valid. That reproduces #2757's failure on the original function, on a second
   validator.
3. **Reduced it.** `cvise`/`creduce` are not installable here (no brew formula, no pip wheel for
   this Python), so a line-granularity delta-debugging loop (a small ddmin, not kept) ran against
   "compiles, links, V8 reports a `br_table` refusal", first from a hand-written shape of
   `operator()` (a `switch` in a `for`, `for` loops over an iterator, a `try` with a stack handler
   and `setjmp` in each), then by hand from the result. That first hand-written shape already
   reproduced, with three `setjmp`s; the loop cut it to one and then to the 12-statement file.

## The result: [`sjlj-br-table.cpp`](sjlj-br-table.cpp), 12 statements, no OCCT, no libc++ headers

```cpp
#include <setjmp.h>
jmp_buf& lab();
void a();
bool more();
void f() {
  while (more()) {
    while (more()) {
      try {
        if (setjmp(lab())) a();
      } catch (...) {
      }
    }
  }
}
```

    clang++ --target=wasm32-unknown-wasip1 --sysroot=<WASI.sdk> -O2 \
        -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false -mllvm -wasm-enable-sjlj -c sjlj-br-table.cpp
    wasm-ld --no-entry --allow-undefined --no-gc-sections --export-all -o t.wasm sjlj-br-table.o
    node -e 'new WebAssembly.Module(require("fs").readFileSync("t.wasm"))'
    # CompileError: WebAssembly.Module(): Compiling function #9:"f()" failed:
    #   br_table: label arity inconsistent with previous arity 0 @+729

Measured by `run.sh`, which asserts every line in both directions:

| Variation | Result |
|---|---|
| the file above, `-O0` / `-O1` / `-O2` / `-O3` / `-Os` / `-Oz` | all six refused with the `br_table` message |
| the legacy EH encoding (drop `-mllvm -wasm-use-legacy-eh=false`) | valid |
| no `setjmp` call in the function | valid |
| `lab()` declared `noexcept` | valid |
| `setjmp(buf)` on an `extern jmp_buf`, no call inside the `try` | valid |
| one loop level instead of two | valid |
| no `-mllvm -wasm-enable-sjlj` | compiles, leaves a plain undefined `setjmp` (a link error on wasip1) |

So the trigger, as far as it was bounded: **a `setjmp` whose argument is a call that may throw, in a
`try`, in doubly nested loops**, under the standardised EH encoding. Disassembly of the reduction
(`llvm-objdump -d`, `-O2`):

```
 2c7: 02 7f   block   i32
 2c9: 1f 40 01 00 81 80 80 80 00 00   try_table (catch 1 0)
 2d3: 20 01   local.get 1
 2d5: 0e 03 03 02 01 01   br_table {3, 2, 1, 1}     # target depth 1 and 2 carry different label types
```

### What the reduction is NOT

* It is **not byte-identical** to the OCCT failure. The original had a multi-value `block
  [i32, exnref]` and `try_table (catch_ref 0 0)`; the reduction has `block i32` and `try_table
  (catch 1 0)`. Both fail the same validator rule (`br_table` targets with different label types)
  in a function that holds a `try_table` and a `br_table` from the setjmp dispatch, which is why it
  is offered as a reduction of the same defect. It was not shown that the two arrive there by the
  same pass; that is for the LLVM side to say.
* It needs **one** `setjmp`, not six. The six in `BRepCheck_ParallelAnalyzer` are incidental.
* It is **not a mechanism**. What is established is the table above. Which pass builds the
  `br_table` (the SjLj dispatch, the EH `try_table` rewrite, or the block-structure fixup) was not
  determined here and should not be read into this.
* The hand-written [`2175/probe-sjlj-eh.cxx`](../2175/probe-sjlj-eh.cxx) missed it because its
  `Label()` is inline and cannot throw, which is the `noexcept` row above.

## Upstream re-check (2026-10-11): it reproduces on upstream LLVM

Everything above is the swift-6.4.0 fork (clang 21). The same file was rebuilt against upstream
toolchains, with the same flags, and validated three ways (V8 in `node` v26.10.0, `wasm-tools`
1.258.3, wabt 1.0.42 `wasm-validate --enable-all`):

| Toolchain | `-O1` .. `-Oz` | `-O0` | Controls (legacy EH, no `setjmp`, `noexcept`, global buffer, one loop) |
|---|---|---|---|
| wasi-sdk 34: `clang version 23.1.0-wasi-sdk` (llvm-project `895aa2c896ad`), WASI sysroot from the same SDK | all five invalid, all three validators | clang crashes in `WebAssembly CFG Stackify`, `addNestedTryTable` | all valid |
| LLVM 23.1.3 release: `clang version 23.1.3` (llvm-project `0d261d1ca552`), sysroot from wasi-sdk 34 | all five invalid, all three validators | same crash | all valid |
| Compiler Explorer `wasm32clang` ("WebAssembly clang (trunk)"): `clang version 24.0.0git` (llvm-project `680b97545e81`, trunk build of 2026-10-06), no libc, so `setjmp` is declared by hand | all five invalid (the returned assembly assembled with the 23.1.3 `llvm-mc`, linked, then validated) | same crash (exit 139) | all valid |

The failing function and message match the fork's: `Compiling function #9:"f()" failed: br_table:
label arity inconsistent with previous arity 0`; the `.s` from trunk shows the same
`try_table`-nested `br_table {4, 3, 2, 2}` shape. Two differences from the fork: upstream crashes at
`-O0` where the fork emitted an invalid module, and no upstream run needed the Swift SDK. The
`-O0` crash is in the same function (`addNestedTryTable`) as the open upstream report
[llvm/llvm-project#217723](https://github.com/llvm/llvm-project/issues/217723) (C++20 coroutines under
exnref EH: crash at `-O1`/`-O2`, the same `br_table` arity message at `-Oz`). That one has no
`setjmp`, so it is a neighbour, not a duplicate; nothing else matching `setjmp`/`sjlj` with exnref
was found, and no commit to `WebAssemblyLowerEmscriptenEHSjLj.cpp` or `WebAssemblyCFGStackify.cpp`
on `main` up to 2026-10-10 addresses it. `-wasm-use-legacy-eh` still defaults to `true` on `main`
(`WebAssemblyTargetMachine.cpp`), so only builds that opt in with `=false` can hit it.

The Compiler Explorer row proves the compiler's output (the assembly), not validity: the validity
check is the local assemble, link and validate step above. A report should attach the command line,
the `clang --version` line, and the validator message, and may link a Compiler Explorer compile
of the hand-declared `setjmp` variant for the assembly.

## Draft LLVM issue (NOT posted; the decision to file is the owner's)

Re-checked against upstream on 2026-10-11 (section above): still reproduces on 23.1.3 and on trunk,
and no duplicate was found. The toolchain line at the end of the draft is the fork's; replace it
with the upstream versions from the table when filing.

> **[WebAssembly] invalid `br_table` (label types differ) with `-wasm-enable-sjlj` and
> `-wasm-use-legacy-eh=false`**
>
> With wasm exceptions in the standardised encoding (`-fwasm-exceptions -mllvm
> -wasm-use-legacy-eh=false`) and the SjLj lowering (`-mllvm -wasm-enable-sjlj`), a function that
> calls `setjmp` on a buffer returned by a potentially-throwing call, inside a `try`, inside two
> nested loops, is compiled to a module that fails validation.
>
> ```cpp
> #include <setjmp.h>
> jmp_buf& lab();
> void a();
> bool more();
> void f() {
>   while (more()) {
>     while (more()) {
>       try {
>         if (setjmp(lab())) a();
>       } catch (...) {
>       }
>     }
>   }
> }
> ```
>
> ```
> clang++ --target=wasm32-unknown-wasip1 -O2 -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false \
>   -mllvm -wasm-enable-sjlj -c t.cpp
> wasm-ld --no-entry --allow-undefined --no-gc-sections --export-all t.o -o t.wasm
> ```
>
> V8 (node 26): `CompileError: WebAssembly.Module(): Compiling function #9:"f()" failed: br_table:
> label arity inconsistent with previous arity 0`. WasmKit 0.3.1, on the original, larger function:
> `expected the same copy types for all branches in br_table but got [i32, ref(exnRef)] and []`.
>
> The function contains `try_table (catch 1 0)` with a `br_table {3, 2, 1, 1}` whose depth-1 and
> depth-2 targets have different result types, which the specification forbids. Reproduces at
> `-O1` through `-Oz`; at `-O0` upstream clang crashes in `WebAssembly CFG Stackify`
> (`addNestedTryTable`) instead.
>
> The module is valid if any one of these changes: the legacy EH encoding is used, the `setjmp` is
> removed, `lab()` is `noexcept`, the buffer is a global with no call in the `try`, or the loops are
> not nested. Found compiling OpenCASCADE's `BRepCheck_ParallelAnalyzer::operator()(int) const`,
> which has six `setjmp`s of this shape; there the targets were `[i32, exnref]` against nothing.
>
> Toolchain: swift-6.4.0-RELEASE (clang 21.0.0, swiftlang/llvm-project 903b9faaae5c), wasm32-wasip1.

## Does anything else need the pair?

Searched `Libraries/occt-src/src` (OCCT `V8_0_1` plus the carried patches) and the repo's own
`Sources/` for `setjmp`, `longjmp`, `sigsetjmp`, `siglongjmp`, `_setjmp`, `<setjmp.h>` and
`<csetjmp>`:

* **OCCT: exactly one site**, `Standard_ErrorHandler.hxx`/`.cxx`, behind `#if defined(OCC_CONVERT_SIGNALS)`.
  It reaches 151 translation units through 311 `OCC_CATCH_SIGNALS` uses. `-UOCC_CONVERT_SIGNALS`
  removes all of them (`adm/cmake/occt_defs_flags.cmake:48` is the only place that defines it).
* **Bundled dependencies: none.** The wasm build sets `USE_FREETYPE`, `USE_FREEIMAGE`, `USE_TBB`
  and `USE_VTK` to OFF; the only third-party code is rapidjson, header-only, with no `setjmp`.
* **This repo's `Sources/`: none.** The only `setjmp` text in `Package.swift` is a
  comment saying why `.linkedLibrary("setjmp")` was removed (#2758); the link was measured with and
  without it and succeeds both ways.
* **Measured on the shipped kernel.** The pinned asset (`v4.0.0-kernel.4`, 5,488 members) has zero
  references to `__wasm_setjmp`, `__wasm_setjmp_test`, `__wasm_longjmp` or `__c_longjmp`.

So nothing needs the pair today. A future dependency that really uses `setjmp` on this target
would hit the defect only in a function shaped like the reduction (and not every such function
does), and it would link without complaint: the failure is at module validation, at run time.

## The regression guard

[`Scripts/check-wasm-archive-no-setjmp.sh`](../../check-wasm-archive-no-setjmp.sh) runs `llvm-nm -A`
over the archive and fails on any of the four symbols. It takes about 3 s on the 153 MB archive,
and `wasm.yml` runs it right after `Scripts/fetch-occt-wasm.sh`, as a step of the existing job (not
a new one), so it covers what the fetch just unpacked. Proved to fail: the pinned archive plus
`bad.o` (the reduction's object) added with `llvm-ar r` exits 1 and names the four symbols; the
unmodified pinned archive exits 0 with 5,488 members scanned.
