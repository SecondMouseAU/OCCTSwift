# #2256: the bridge cannot be compiled for wasm as Objective-C++

`Sources/OCCTBridge/src` is 74 `.mm` files. SwiftPM dispatches on the extension, so every one of
them is handed to clang as Objective-C++, and the pinned swift.org clang **crashes in code
generation** compiling Objective-C++ for `wasm32-unknown-wasip1` with `-fwasm-exceptions`. That is
every bridge translation unit, so the bridge does not build for wasm at all, which is what blocks
#2174 and #2175.

Dropping the exception flags is not a way out. That build succeeds, and it is precisely the
configuration [`Scripts/repro/2171`](../2171/README.md) measured as a **silent failure**: every
outermost `catch (...)` stops firing and nothing anywhere says so.

`run.sh` builds and runs everything below. `transcript.txt` is a recorded run.

## The crash

`minimal.mm` is nine lines and contains no Objective-C. Compiled twice, differing only in the name
it is given:

| Input | Flags | Result |
|---|---|---|
| `.cpp` | `-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false` | OK |
| `.mm` | `-fwasm-exceptions` | **crash** |
| `.mm` | `-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false` | **crash** |
| `.mm` | `-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false -fno-objc-exceptions` | **crash** |
| `.mm` | none | OK, and this is #2171's silent-failure configuration |
| `.mm` | `-x c++ -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false` | OK |

    1.	<eof> parser at end of file
    2.	Code generation
    3.	Running pass 'Function Pass Manager' on module 'minimal.mm'.
    4.	Running pass 'WebAssembly Instruction Selection' on function '@probe'

Neither exception encoding matters, and `-fno-objc-exceptions` does not help, which together say
the crash is not about Objective-C exceptions.

## Why, in one line of IR

`-S -emit-llvm` on the same two files differs in exactly one interesting place:

    t.cpp:  define hidden i32 @probe(i32 %0) personality ptr @__gxx_wasm_personality_v0
    t.mm :  define hidden i32 @probe(i32 %0) personality ptr @__gnustep_objcxx_personality_v0

Clang gives any Objective-C++ translation unit the Objective-C++ personality function, for the
Objective-C runtime the target implies, whether or not a line of Objective-C is present. LLVM's
wasm exception lowering runs only on functions whose personality is the wasm C++ one, so it skips
this function and leaves the Itanium-shaped `invoke`/`landingpad` in place, and the WebAssembly
selector cannot select those. Hence a crash in instruction selection rather than a diagnostic.

No Objective-C runtime flag avoids it. `-fobjc-runtime=gcc` and `=objfw` swap one non-wasm
personality for another (`__gnu_objc_personality_v0`), and `=macosx` is rejected outright by the
backend: `Objective-C support is unimplemented for object file format`. Objective-C cannot target
this triple at all, which is the strongest argument that compiling these files as C++ costs nothing
that could otherwise have worked.

## Upstream

[llvm/llvm-project#123659](https://github.com/llvm/llvm-project/issues/123659) (open since
January 2025) reports the neighbouring case: an Objective-C `@try`/`@catch` under
`-fwasm-exceptions`. [PR #169043](https://github.com/llvm/llvm-project/pull/169043), closed
unmerged, lists the same crash as one of two things it could not fix.

Neither covers what is measured here, and the difference matters to anyone who would otherwise
read those and think the bug needs Objective-C to trigger: **this file has no Objective-C in it at
all**, and an ordinary C++ `try`/`catch` is enough. The report that says so has not been filed; see
the pull request for #2256 for the draft and for who is filing it.

## The fix, and the option that was not taken

`-x c++` on the WASI compile, and nothing else. The alternative on the table was renaming all 74
files to `.cpp`, which is arguably the correct answer on its own merits, since they are not
Objective-C++ and never were. It was not taken now for three reasons: it is a 74-file rename across
a tree several in-flight branches are editing; it needs the umbrella header's
`#import <Foundation/Foundation.h>` resolved for every Apple target rather than only for WASI; and
it changes how the whole bridge is compiled on macOS and iOS, which is a large blast radius for a
change whose purpose is to unblock a wasm build. What would make it worth doing later is any of:
upstream fixing the crash (then `-x c++` is dead weight and the rename is the only remaining
reason to touch the files), the bridge acquiring a second non-Apple target, or the Foundation
import going away for its own reasons.

## Where `-x c++` lands, and what it does not touch

The question `-x c++` always raises is what it does to a `.c` file, since as a command-line option
it applies to every input that follows it. In a SwiftPM build it is not a command-line option in
that sense: SwiftPM emits an explicit `-x <lang>` per source file, and a language override in the
build settings **replaces** that dialect rather than being appended after it. Measured (case 11)
with two one-file probes rather than one mixed target, because a build that stops at the first error
cannot tell "the setting did not reach this file" from "this file was never compiled". One probe
holds a `.c` written so that compiling it as C++ is a syntax error, the other a `.mm` written the
same way, and each carries a neutral `.cpp` so SwiftPM classifies both targets as C++:

| How `-x c++` is supplied | Build system | Reaches the `.mm` | Reaches the `.c` |
|---|---|---|---|
| `cxxSettings: [.unsafeFlags([...])]` | `swiftbuild` (default) | yes | no |
| `cxxSettings: [.unsafeFlags([...])]` | `native` (deprecated) | yes | **yes** |
| toolset `cxxCompiler.extraCLIOptions` | `swiftbuild` (default) | yes | no |
| toolset `cxxCompiler.extraCLIOptions` | `native` (deprecated) | yes | no |

So on the build system the wasm cross-build actually uses, both routes are correctly scoped and
`Libraries/dummy.c` is untouched; on the deprecated one, only the toolset route is. `dummy.c` is in
the `OCCT` target rather than `OCCTBridge` and that target has no `cxxSettings` at all, so it is
two steps away from either. This is why the setting's home is the toolset
`Scripts/make-wasi-toolset.py` writes once #2048 (PR #2206) lands, and why `Package.swift` says so
at the site.

## Proving it against the failure it prevents, not against the crash

A fix that only stops the crash can ship #2171's silent failure by accident, so cases 7 to 10 ask
the harder question of a **real bridge translation unit**: `OCCTBridge_Curve3D_Curves.mm`, out of
`Sources/OCCTBridge/src`, unmodified.

`bridge-catch/driver.cpp` calls `OCCTCurve3DCreateLine(0,0,0, 0,0,0)`. A zero-length direction is
what OCCT's `gp_Dir` raises `Standard_ConstructionError` on, inside that function's own `try` block,
which is the shape `CLAUDE.md` names: every `gp_Dir` construction from caller doubles sits inside a
`try`. The driver calls it inside a `try` of its own, so a catch that does not fire is visible
rather than fatal, and it counts calls to `occtRecordCaughtException`, so what is measured is that
the catch **body ran**, not merely that a value came back.

`bridge-catch/fake-occt.cpp` is the slice of OCCT the link needs, because `libOCCT-wasm.a` does not
exist yet (#2174). It is OCCT's three allocator entry points, `Standard_Failure`'s constructor,
destructor and `what()` (which is also what emits its typeinfo, so the throw has one), and a
trapping stand-in for `Geom_Line`'s constructor, which the raising path never reaches. Nothing in it stands in for the
bridge. The raise is OCCT's own, from OCCT's own headers, and the catch is the bridge's own.

| Case | The bridge TU is compiled | Result |
|---|---|---|
| 7 | as Objective-C++, EH flags | crash, on whichever throwing function codegen reaches first |
| 8 | `-x c++`, EH flags | a wasm32 object |
| 9 | the same object, linked and run | `bridge returned null: 1`, `catch body ran: 1`, `escaped: 0` |
| 10 | `-x c++`, **no** EH flags | compiles clean, then `catch body ran: 0`, `escaped: 1` |

Case 10 is the one worth keeping. It is #2171's finding reproduced through a real bridge file: the
build is green, the compiler says nothing, and the bridge's error contract is gone.

The OCCT headers used are the xcframework's, since the wasm header tree arrives with #2174. They
are declarations; the objects are compiled for `wasm32-unknown-wasip1`.

## Running it

    Scripts/repro/2256/run.sh

`Libraries/` is gitignored, so a linked worktree usually has no headers of its own; point
`OCCT_HEADERS` at a checkout that has them and `WASI_SDK_PREFIX` at wasi-sdk if it is not in this
tree. Cases 7 to 10 skip loudly without them, and a skip is not a pass.
